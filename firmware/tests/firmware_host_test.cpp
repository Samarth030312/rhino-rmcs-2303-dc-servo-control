// Runs the real motor firmware (motor_controller.ino) on the PC against an emulated
// RMCS-2303 that speaks Modbus ASCII, drives it like MATLAB would, and checks the result.
//
//   scripts/validation/build_firmware.sh        (builds and runs this)
//
// The emulated drive follows the register map in docs/knowledge-base/HARDWARE_REFERENCE.md
// and the framing of the vendor library: it is a test double, not a model of the real
// drive's dynamics (speed follows the command with a 50 ms first-order lag).
// Writes the firmware's serial output to the file given as argv[1] so the MATLAB test
// test_firmware_transcript.m can parse every line with servolab.protocol.parse.

#include "Arduino.h"
#include "AltSoftSerial.h"
#include <map>
#include <vector>

#include <chrono>
#include <thread>
#include <fcntl.h>
#include <unistd.h>
#include <termios.h>
double g_now_ms = 0;
static long g_calls = 0;
static bool g_realtime = false;                 // --pty mode: real wall-clock time
static double wallMs() {
  using namespace std::chrono;
  static auto t0 = steady_clock::now();
  return duration<double, std::milli>(steady_clock::now() - t0).count();
}
uint32_t millis() {
  if (g_realtime) { g_now_ms = wallMs(); return (uint32_t)g_now_ms; }
  if (++g_calls % 50 == 0) g_now_ms += 1; return (uint32_t)g_now_ms;
}
uint32_t micros() { millis(); return (uint32_t)(g_now_ms * 1000.0); }
void delay(unsigned long ms) {
  if (g_realtime) { std::this_thread::sleep_for(std::chrono::milliseconds(ms)); g_now_ms = wallMs(); return; }
  g_now_ms += ms;
}
void delayMicroseconds(unsigned int) {}
static int g_pin[20];
void pinMode(uint8_t p, uint8_t m) { if (m == INPUT_PULLUP) g_pin[p] = HIGH; }
void digitalWrite(uint8_t p, uint8_t v) { g_pin[p] = v; }
int digitalRead(uint8_t p) { return g_pin[p]; }
void analogWrite(uint8_t, int) {}
unsigned long pulseIn(uint8_t, uint8_t, unsigned long) { return 0; }
char *dtostrf(double v, signed char w, unsigned char p, char *b) { sprintf(b, "%*.*f", w, p, v); return b; }
HostSerial Serial;
std::deque<char> g_driveTx;

// ------------------------------------------------------------------ emulated RMCS-2303
struct Drive {
  uint8_t id = 7; bool powered = true;   // the lab's drive answers as 7
  std::map<int, uint16_t> reg = {{0, 0x0BFF}, {2, 0}, {4, 32}, {6, 16}, {8, 32}, {10, 334}, {12, 20000}, {14, 0}};
  double speed = 0, pos = 0, ramp = 0;      // base rpm, counts, ramped setpoint
  bool encoderReversed = false;              // wiring fault: drive sees -speed and runs away
  bool coarseSpeed = false;                  // speed register in 461.5 base-rpm steps (4.6 output rpm), as on the lab drive
  double speedAtOff = 0;                     // base rpm when motor power was last switched off (0x0700)
  std::string line; int frames = 0, writes = 0;
  std::string injectAfterNextFrame;          // a late reply from another slave, delivered right after a request
  std::vector<uint16_t> modeHistory;
  void step(double dt_ms) {
    uint16_t m = reg[2]; double target = 0;
    if ((m >> 8) == 1 && (m & 1)) target = (m & 8) ? -(double)reg[14] : reg[14];
    if (encoderReversed && target != 0) target = (target > 0 ? -1 : 1) * 16600.0;   // flat out, wrong way
    if (encoderReversed && m == 0x0701) target = -16600.0;   // "hold position" with reversed encoder runs away (2026-10-11)
    // the lab drive's acceleration register (5000) as a ramp limit in base rpm/s, then a 50 ms lag
    double maxStep = 5000.0 * dt_ms / 1000.0;
    if (target > ramp + maxStep) ramp += maxStep; else if (target < ramp - maxStep) ramp -= maxStep; else ramp = target;
    speed += (ramp - speed) * std::min(1.0, dt_ms / 50.0);
    pos += speed / 60.0 * 52.0 * dt_ms / 1000.0;     // 52 counts per base rev
    if (m == 0x0700 || (m >> 8) == 2) { speed = 0; ramp = 0; }   // power off / position mode (ideal)
    if (m == 0x0701 && !encoderReversed) { speed = 0; ramp = 0; }   // hold works only with correct polarity
  }
  static uint8_t hx(char a, char b) { auto v = [](char c) { return c <= '9' ? c - '0' : c - 'A' + 10; }; return v(a) << 4 | v(b); }
  void reply(const std::vector<uint8_t> &b) {
    uint8_t s = 0; std::string o = ":"; char t[3];
    for (auto x : b) { s += x; snprintf(t, 3, "%02X", x); o += t; }
    snprintf(t, 3, "%02X", (uint8_t)(-s)); o += t; o += "\r\n";
    for (char c : o) g_driveTx.push_back(c);
  }
  void rx(char c) {
    if (c == ':') { line.clear(); return; }
    if (c == '\r') return;
    if (c != '\n') { line += c; return; }
    if (!injectAfterNextFrame.empty()) { for (char d : injectAfterNextFrame) g_driveTx.push_back(d); injectAfterNextFrame.clear(); }
    if (!powered) return;
    std::vector<uint8_t> b; uint8_t s = 0;
    for (size_t i = 0; i + 1 < line.size(); i += 2) { b.push_back(hx(line[i], line[i + 1])); s += b.back(); }
    if (s != 0 || b.size() < 7 || b[0] != id) return;             // bad LRC / not for us: silence
    frames++;
    int a = b[2] << 8 | b[3]; uint16_t d = b[4] << 8 | b[5];
    if (b[1] == 6) {
      reg[a] = d; writes++;
      if (a == 2) { modeHistory.push_back(d); if (d == 0x0800) pos = 0; if (d == 0x0700) speedAtOff = speed; }
      reply({b[0], 6, b[2], b[3], b[4], b[5]});
    } else if (b[1] == 3) {
      std::vector<uint8_t> r = {b[0], 3, (uint8_t)(2 * d)};
      for (int k = 0; k < d; k++) {
        uint16_t v = reg[a + k];
        if (a + k == 24) v = (uint16_t)(int16_t)(coarseSpeed ? std::trunc(speed / 461.5) * 461.5 : lround(speed));
        if (a + k == 20) v = (uint32_t)(int32_t)lround(pos) & 0xFFFF;
        if (a + k == 21) v = ((uint32_t)(int32_t)lround(pos)) >> 16;
        r.push_back(v >> 8); r.push_back(v & 0xFF);
      }
      reply(r);
    }
  }
} emu;
void driveEmuRx(char c) { emu.rx(c); }

#include "../motor_controller/motor_controller.ino"

// ------------------------------------------------------------------ host-side script
static void send(const std::string &body) {           // like servolab.protocol.encode
  uint8_t x = 0; for (char c : body) x ^= (uint8_t)c;
  char t[4]; snprintf(t, sizeof t, "%02X", x);
  for (char c : "$" + body + "*" + t + "\n") Serial.in.push_back(c);
}
static void runFor(double ms, bool ping) {
  double end = g_now_ms + ms, nextPing = g_now_ms;
  while (g_now_ms < end) {
    if (ping && g_now_ms >= nextPing) { send("PING,1"); nextPing += 250; }
    double t0 = g_now_ms; loop(); if (g_now_ms == t0) g_now_ms += 1;
    emu.step(g_now_ms - t0);
  }
}
static int fails = 0;
#define CHECK(cond, msg) do { if (cond) printf("  ok    %s\n", msg); else { printf("  FAIL  %s\n", msg); fails++; } } while (0)
static double lastTelField(int idx) {                  // field idx (0-based after version) of the last $TEL
  size_t p = Serial.out.rfind("$TEL,1,"); if (p == std::string::npos) return NAN;
  std::string l = Serial.out.substr(p + 7, Serial.out.find('*', p) - p - 7);
  for (int i = 0; i < idx; i++) l = l.substr(l.find(',') + 1);
  return atof(l.c_str());
}

// --pty: run the firmware in real time on a pseudo-terminal so MATLAB can connect to it
// (end-to-end test of rhino_servo_lab <-> real firmware code <-> emulated drive).
static int runPty() {
  g_realtime = true;
  int m = posix_openpt(O_RDWR | O_NOCTTY);
  if (m < 0 || grantpt(m) || unlockpt(m)) { perror("pty"); return 2; }
  fcntl(m, F_SETFL, O_NONBLOCK);
  // a new pty slave is a terminal (echo, line editing): the board would read its own output.
  // Make it raw like a USB serial port, and keep a slave fd open so the settings persist.
  int sl = open(ptsname(m), O_RDWR | O_NOCTTY);
  struct termios tio; tcgetattr(sl, &tio); cfmakeraw(&tio); tcsetattr(sl, TCSANOW, &tio);
  printf("PTY %s\n", ptsname(m)); fflush(stdout);
  setup();
  double lastHello = wallMs(), last = wallMs(); bool heard = false;
  for (;;) {
    char b[256]; ssize_t n = read(m, b, sizeof b);
    for (ssize_t i = 0; i < n; i++) Serial.in.push_back(b[i]);
    if (n > 0) heard = true;
    // a real Uno resets when the port opens and says HELLO; a pty cannot reset, so repeat
    // HELLO until the host has spoken
    if (!heard && wallMs() - lastHello > 1000) { setup(); lastHello = wallMs(); }
    loop();
    double now = wallMs(); emu.step(now - last); last = now;
    if (!Serial.out.empty()) { ssize_t w = write(m, Serial.out.data(), Serial.out.size()); if (w > 0) Serial.out.erase(0, w); }
    std::this_thread::sleep_for(std::chrono::microseconds(200));
  }
}

int main(int argc, char **argv) {
  if (argc > 1 && std::string(argv[1]) == "--pty") return runPty();
  printf("firmware host test (emulated RMCS-2303, slave 7, LPR 334 at power-up)\n");
  // the 2026-10-11 incident: reversed encoder + Uno reboot. Boot must not make the motor run.
  emu.encoderReversed = true;
  setup(); runFor(1000, false);
  CHECK(fabs(emu.speed) < 1, "reboot with reversed encoder: motor stays still (no hold command)");
  emu.encoderReversed = false; Serial.out.clear(); emu.reg[10] = 334;
  setup();
  CHECK(Serial.out.find("$HELLO,1,rhino_servo_lab,") != std::string::npos, "HELLO sent");
  CHECK(Serial.out.find("rhino_servo_lab,dev,7*") != std::string::npos, "drive found at slave id 7");
  CHECK(emu.reg[10] == 13, "LPR corrected from 334 to 13");
  CHECK(emu.reg[2] == 0x0700, "drive left with motor power OFF after boot (never hold)");

  send("DIAG,1"); runFor(50, false);
  CHECK(Serial.out.find("# reg 10 LPR = 13") != std::string::npos, "DIAG dumps registers");

  send("CFG,1,S,PI,0.3,2.5,0,10,100,180"); send("SET,1,50"); send("RUN,1");
  runFor(5000, true);
  double meas = lastTelField(5), u = lastTelField(7);
  printf("        speed loop after 5 s: measured %.2f rpm, command %.2f rpm\n", meas, u);
  CHECK(fabs(meas - 50) < 1.0, "speed PI reaches 50 rpm (emulated drive)");
  CHECK(emu.reg[2] == 0x0101, "drive in digital speed mode, CW");

  {
    // OI-M12: the lab drive ran away in reverse when a speed run started from rest after
    // STOP without a HOME; every RUN, any loop, must write HOME before the speed mode word
    auto h = std::find(emu.modeHistory.begin(), emu.modeHistory.end(), 0x0800);
    auto s = std::find(emu.modeHistory.begin(), emu.modeHistory.end(), 0x0101);
    CHECK(h != emu.modeHistory.end() && h < s, "speed run starts with SET HOME, before the speed mode word");
  }
  send("SET,1,-30"); runFor(4000, true);
  CHECK(emu.reg[2] == 0x0109, "negative command switches drive to CCW");
  CHECK(fabs(lastTelField(5) + 30) < 1.0, "speed PI reaches -30 rpm");

  // soft stop: at -30 rpm the motor is brought to rest on the drive's ramp before power goes off.
  // The lab drive's speed register reads 0 below 4.6 rpm (2026-10-25, MOTOR-R0114), so rest is
  // also judged from the encoder position.
  emu.coarseSpeed = true;
  send("STOP,1"); runFor(100, false);
  CHECK(emu.reg[2] == 0x0109 && emu.reg[14] == 0, "STOP while turning: speed 0 commanded, motor power still on (soft stop)");
  runFor(2000, false);
  printf("        soft stop from -30 rpm: motor power off at %.2f rpm\n", emu.speedAtOff / 100.0);
  CHECK(emu.reg[2] == 0x0700 && fabs(emu.speedAtOff) < 100, "soft stop: power off only at rest (< 1 rpm by the encoder), never hold");
  emu.coarseSpeed = false;
  CHECK(Serial.out.find("ms to rest, motor power off") != std::string::npos, "soft stop reports its time to rest");
  // STOP,1,NOW (the app's ABORT) cuts power at once
  send("CFG,1,S,PI,0.3,2.5,0,10,100,180"); send("SET,1,50"); send("RUN,1"); runFor(3000, true);
  send("STOP,1,NOW"); runFor(50, false);
  CHECK(emu.reg[2] == 0x0700, "STOP,1,NOW while turning: motor power off at once");

  // speed from encoder counts (loop E): same PI, feedback = counts differenced over Ts
  send("CFG,1,E,PI,0.3,2.5,0,10,100,180"); send("SET,1,40"); send("RUN,1");
  runFor(5000, true);
  printf("        encoder-speed loop after 5 s: measured %.3f rpm, counts %.0f\n", lastTelField(5), lastTelField(8));
  CHECK(fabs(lastTelField(5) - 40) < 0.5, "speed PI on encoder counts (loop E) reaches 40 rpm");
  CHECK(lastTelField(8) > 1000, "loop E logs the position counts");
  send("STOP,1"); runFor(100, false);
  // open loop with encoder-count speed (static map, identification step): u must equal the setpoint
  send("CFG,1,E,OL,0,0,0,10,100,180"); send("SET,1,20"); send("RUN,1"); runFor(3000, true);
  printf("        open loop, loop E: u = %.2f, measured %.3f rpm\n", lastTelField(7), lastTelField(5));
  CHECK(fabs(lastTelField(7) - 20) < 1e-6 && fabs(lastTelField(5) - 20) < 0.5, "open loop with encoder speed commands the setpoint (20 rpm)");
  send("STOP,1"); runFor(100, false);
  send("CFG,1,E,PI,0.3,2.5,0,10,100,180"); send("SET,1,40"); send("RUN,1"); runFor(500, true);
  send("STOP,1"); runFor(100, false);
  send("DIAG,1"); runFor(50, false);
  CHECK(Serial.out.find("# loop time control law us: mean") != std::string::npos &&
        Serial.out.find("# loop time whole sample us: mean") != std::string::npos, "DIAG reports loop time (micros) of the last run");
  send("CFG,1,X,PI,0.3,2.5,0,10,100,180"); runFor(20, false);
  CHECK(Serial.out.find("loop must be S E or P") != std::string::npos, "CFG with an unknown loop letter is refused");

  send("CFG,1,P,P,0.3,0,0,10,150,180"); send("SET,1,90"); send("RUN,1");
  runFor(6000, true);
  printf("        position loop after 6 s: %.2f deg\n", lastTelField(5));
  CHECK(fabs(lastTelField(5) - 90) < 1.0, "position P reaches 90 deg");
  CHECK(std::find(emu.modeHistory.begin(), emu.modeHistory.end(), 0x0800) != emu.modeHistory.end(), "position run starts with SET HOME");

  runFor(1500, false);                                   // MATLAB goes silent
  CHECK(emu.reg[2] == 0x0700, "host watchdog cuts motor power after 1 s");
  CHECK(Serial.out.find("host silent") != std::string::npos, "watchdog reported to host");

  send("CFG,1,S,P,0.5,0,0,10,100,180"); send("SET,1,40"); send("RUN,1"); runFor(500, true);
  send("ESTOP,1"); runFor(50, false);
  CHECK(emu.reg[2] == 0x0700, "ESTOP -> drive power off (0x0700)");
  send("RUN,1"); runFor(50, false);
  CHECK(Serial.out.find("estopped") != std::string::npos, "RUN refused after ESTOP until HOME");

  send("HOME,1"); runFor(50, false);
  send("RUN,1"); runFor(300, true);
  g_pin[4] = LOW; runFor(50, true);                       // STOP push-button pressed
  CHECK(emu.reg[2] == 0x0700, "D4 STOP button -> drive E-STOP");
  g_pin[4] = HIGH;

  emu.powered = false;                                 // drive loses 12 V mid-run
  size_t mark = Serial.out.size();
  send("HOME,1"); runFor(500, false); send("RUN,1"); runFor(1000, true);
  std::string tail = Serial.out.substr(mark);
  CHECK(tail.find("ERR,1,HOME,9") != std::string::npos, "HOME with a dead drive is refused (no false ACK)");
  CHECK(tail.find("ERR,1,RUN,") != std::string::npos && tail.find("ACK,1,RUN") == std::string::npos,
        "RUN with a dead drive is refused (no false ACK)");
  emu.powered = true;                                    // power back: a new run works again
  send("HOME,1"); runFor(300, false);
  send("CFG,1,S,PI,0.3,2.5,0,10,100,180"); send("SET,1,20"); send("RUN,1"); runFor(3000, true);
  CHECK(fabs(lastTelField(5) - 20) < 1.0, "after power returns, a new run works (20 rpm)");
  emu.powered = false; runFor(600, true);                 // drive dies mid-run
  CHECK(Serial.out.find("modbus feedback lost") != std::string::npos, "drive lost mid-run: run stopped and reported");

  // late reply: a reply from slave 7 arrives while the firmware is asking slave 1
  {
    std::string mark = Serial.out;
    emu.powered = true; g_driveTx.clear();
    std::string late = ":070302000BE9\r\n";                 // a valid reply from id 7 (reg 0 = 0x000B)
    uint8_t ok = 0;
    // feed it as the answer to a query for id 1: the firmware must reject it (wrong id)
    uint8_t pdu[5] = {3, 0, 0, 0, 1}; uint8_t rx[16];
    emu.injectAfterNextFrame = late;
    emu.id = 99;                                             // the real drive stays silent
    int r = mbTransact(1, pdu, 5, rx, sizeof(rx));
    emu.id = 7;
    ok = (r == -3);
    CHECK(ok, "a reply from slave 7 is not accepted as slave 1");
  }
  // the drive power-cycles (LPR back to its saved 334): RUN must restore 13 before moving
  {
    emu.powered = true; emu.id = 7; emu.reg[10] = 334;
    send("HOME,1"); runFor(200, false);
    send("CFG,1,S,OL,0,0,0,10,100,180"); send("SET,1,20"); send("RUN,1"); runFor(300, true);
    CHECK(emu.reg[10] == 13, "RUN restores LPR 13 after a drive power cycle");
    send("STOP,1"); runFor(200, false);
  }
  // a commanded reversal must NOT trip the runaway guard (drive ramps through 'wrong way')
  {
    emu.powered = true; emu.id = 7;
    send("HOME,1"); runFor(200, false);
    send("CFG,1,S,OL,0,0,0,10,100,180"); send("SET,1,60"); send("RUN,1");
    size_t m0 = Serial.out.size(); runFor(3000, true);
    send("SET,1,-60"); runFor(4000, true);
    std::string tl = Serial.out.substr(m0);
    CHECK(tl.find("runaway") == std::string::npos, "commanded reversal +60 -> -60 rpm does not trip the runaway guard");
    CHECK(fabs(lastTelField(5) + 60) < 2.0, "reversal completes: -60 rpm");
    send("STOP,1"); runFor(200, false);
  }
  // encoder A/B reversed: the drive runs away; the firmware must E-STOP within a few samples
  {
    emu.powered = true; emu.id = 7; emu.encoderReversed = true;
    send("HOME,1"); runFor(200, false);
    send("CFG,1,S,OL,0,0,0,10,100,180"); send("SET,1,20"); send("RUN,1");
    size_t mark = Serial.out.size(); runFor(1500, true);
    std::string tail = Serial.out.substr(mark);
    CHECK(tail.find("runaway: wrong way - swap encoder pins 10/11") != std::string::npos, "runaway (encoder reversed) is detected and reported");
    CHECK(emu.reg[2] == 0x0700, "runaway -> drive E-STOP");
    // same fault in a position experiment
    send("HOME,1"); runFor(200, false);
    send("CFG,1,P,P,0.3,0,0,10,150,180"); send("SET,1,90"); send("RUN,1");
    mark = Serial.out.size(); runFor(1500, true);
    tail = Serial.out.substr(mark);
    CHECK(tail.find("runaway") != std::string::npos && emu.reg[2] == 0x0700, "runaway in the position loop is detected too -> E-STOP");
    emu.encoderReversed = false;
  }
  // the protocol transcript ends here: in BRIDGE the USB port carries raw Modbus, not protocol v1
  const std::string transcript = Serial.out;
  // BRIDGE: the manufacturer's software talks to the drive through the Uno
  {
    emu.powered = true; emu.id = 7; emu.reg[2] = 0x0101;
    send("HOME,1"); runFor(200, false);
    send("BRIDGE,1"); runFor(50, false);
    CHECK(Serial.out.find("ACK,1,BRIDGE") != std::string::npos && Serial.baud == 9600, "BRIDGE: ACK, then the USB port runs at the drive's 9600 baud");
    CHECK(emu.reg[2] == 0x0700, "BRIDGE: motor power off before handing over");
    size_t mark = Serial.out.size();
    for (char c : std::string(":0703000A0001EB\r\n")) Serial.in.push_back(c);   // read LPR (register 10)
    runFor(200, false);
    CHECK(Serial.out.substr(mark).find(":070302000DE7") != std::string::npos, "BRIDGE: a Modbus frame from the PC reaches the drive and its reply comes back (LPR 13)");
    emu.reg[2] = 0x0101;                                                      // the software had started the motor
    mark = Serial.out.size(); setup();                                       // the port opens: the Uno resets
    CHECK(Serial.baud == 9600 && Serial.out.size() == mark, "BRIDGE survives a reset (EEPROM), silent and at 9600 at once");
    CHECK(emu.reg[2] == 0x0700, "BRIDGE after a reset: motor power off, slave id from EEPROM");
    for (char c : std::string(":0703000A0001EB\r\n")) Serial.in.push_back(c);   // the software's first frame
    runFor(200, false);
    CHECK(Serial.out.substr(mark).find(":070302000DE7") != std::string::npos, "BRIDGE after a reset: the first frame is answered");
    for (char c : std::string("$ENDBRIDGE\n")) Serial.in.push_back(c);
    mark = Serial.out.size(); runFor(2000, false);
    CHECK(Serial.baud == 115200 && Serial.out.find("$HELLO,1,rhino_servo_lab,", mark) != std::string::npos && EEPROM.read(0) == 0,
          "$ENDBRIDGE: back to the controller at 115200, HELLO, EEPROM cleared");
  }
  printf("  %d Modbus frames answered, %d register writes\n", emu.frames, emu.writes);
  if (argc > 1) { FILE *f = fopen(argv[1], "w"); fputs(transcript.c_str(), f); fclose(f); printf("  transcript -> %s\n", argv[1]); }
  printf(fails ? "firmware host test: %d FAILED\n" : "firmware host test: all passed\n", fails);
  return fails != 0;
}
