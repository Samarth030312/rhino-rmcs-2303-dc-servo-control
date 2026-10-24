// Rhino DC servo lab: RMCS-2303 drive + RMCS-5032 motor, outer loop on an Arduino Uno
// Arduino Uno + Robokits RMCS-2303 drive (Modbus ASCII) + RMCS-5032 motor.
//
// The Arduino runs the experiment's P / I / PI / PID loop around the drive's
// digital speed mode (ED-M1) and streams telemetry to MATLAB with protocol v1
// (docs/architecture/SERIAL_PROTOCOL.md).
//
// PINS (docs/wiring/DC_MOTOR_WIRING.md)
//   D8  AltSoftSerial RX  <- drive TXD (drive pin 3)
//   D9  AltSoftSerial TX  -> drive RXD (drive pin 2)
//   D4  STOP pushbutton to GND (normally open) -> drive E-STOP
//   D13 on-board LED: on while the loop runs
//   GND -> drive GND (pin 1)
// The vendor example uses SoftwareSerial on D2/D3. SoftwareSerial blocks all
// interrupts for ~1 ms per byte, which corrupts commands arriving from MATLAB
// (including STOP). AltSoftSerial does not, at the cost of fixed pins D8/D9.
//
// Modbus framing verified against the vendor library RMCS2303drive v1.0
// (SRC-012): ':' id fc addrHi addrLo dataHi dataLo LRC CR LF, 9600 8N1.
// Position feedback = 2 registers starting at 20 (low word first).
//
// Commands (Serial Monitor, 115200, newline; checksum optional when typed):
//   $DIAG,1   register dump      $CFG,1,S,PI,0.3,2.5,0,10,100,180   $SET,1,20
//   $RUN,1    $STOP,1 (power off) $ESTOP,1 (power off, latched)      $HOME,1
//
// CFG loop letter (feedback used by the Arduino's loop):
//   S  speed, from the drive's speed register 24 (the drive counts encoder lines over a short
//      window of its own: coarse, ~4.6 output rpm steps on the lab rig, but no extra delay)
//   E  speed, from encoder counts (register 20) differenced over one sample period Ts:
//      resolution 60 / (5200 * Ts) output rpm (0.115 rpm at Ts = 0.1 s), delay ~Ts/2
//   P  position, output-shaft degrees from encoder counts (5200 per output rev)
//
// Loop timing (course MOTOR S3-6): every sample measures, with micros(), the control-law time
// and the whole sample (Modbus read + control + Modbus write + telemetry). $DIAG prints the
// statistics of the last run.
//
// STATUS: runs on the lab rig (2026-10-11, slave 7) and on the PC against an emulated
// RMCS-2303 (firmware/tests).

#include <AltSoftSerial.h>
#include <EEPROM.h>

#define FW_NAME "rhino_servo_lab"
#ifndef FW_REV
#define FW_REV "dev"
#endif

// ------------------------------------------------------------------ hardware
const uint8_t PIN_STOP_BTN = 4;
const uint8_t PIN_LED = 13;
const long HOST_BAUD = 115200;
const long DRIVE_BAUD = 9600;

const uint16_t LPR_RMCS5032 = 13;        // encoder lines per base-motor rev
const float GEAR = 100.0f;               // 1:100
const float CPR_OUT = 5200.0f;           // counts per output rev
const uint16_t BASE_RPM_MAX = 18000;     // never command above no-load speed
const uint8_t CANDIDATE_IDS[] = {11, 7, 1, 2, 3, 4, 5, 6};

// RMCS-2303 registers and control words (HARDWARE_REFERENCE section 2)
const uint16_t REG_ID = 0, REG_MODE = 2, REG_LPR = 10, REG_SPEED = 14,
               REG_POS_FB = 20, REG_SPD_FB = 24;
const uint16_t MODE_SPEED_CW = 0x0101, MODE_SPEED_CCW = 0x0109,
               MODE_STOP_HOLD = 0x0701, MODE_ESTOP = 0x0700, MODE_HOME = 0x0800;
// SAFETY (2026-10-11 incident): "stop and hold" (0x0701) runs the drive's position loop. With
// the encoder wired in reverse that loop has positive feedback and the motor runs away at full
// speed (it did, ~296 output revolutions, after a reboot sent 0x0701). Every stop therefore
// uses MODE_SAFE_STOP = 0x0700: motor power off, shaft free. Holding is never commanded.
const uint16_t MODE_SAFE_STOP = MODE_ESTOP;

// telemetry flags (protocol v1)
const uint8_t F_RUNNING = 1, F_SAT = 2, F_MB_TIMEOUT = 4, F_MB_LRC = 8,
              F_ESTOP = 16, F_CLAMP = 32, F_WATCHDOG = 64, F_OVERRUN = 128;

AltSoftSerial drive;

// ------------------------------------------------------------------ state
struct Config {
  char loop = 'S';          // 'S' speed, 'P' position
  char ctrl[4] = "PI";      // OL P I PI PID
  float Kp = 0.3f, Ki = 2.5f, Kd = 0.0f;
  float Tf = 0.01f;         // s
  float Ts = 0.10f;         // s
  float uMax = 180.0f;      // output rpm
} cfg;

float setpoint = 0;
bool running = false;
// Soft stop: STOP at the end of a run brings the motor to rest on the drive's own ramp before
// motor power goes off. Cutting power at 30-60 rpm (3000-6000 base rpm) jolted the gearbox
// ("zap") at the end of every closed-loop experiment. STOP,1,NOW, ESTOP, the STOP button, the
// watchdog and the runaway guard still cut power at once.
const uint32_t STOP_RAMP_MAX_MS = 4000;           // 180 rpm at the 53 rpm/s ramp: 3.4 s
bool stopping = false;
uint32_t tStopStart = 0, tStopSample = 0;
float stopLastAbs = 0;
// BRIDGE: the Uno becomes a transparent USB <-> drive link at the drive's 9600 baud, so the
// manufacturer's configuration software (Windows) reaches the drive without rewiring. Opening
// a port resets a CH340 Uno, so the mode is kept in EEPROM and survives resets until
// $ENDBRIDGE (sent at 9600) or the STOP button ends it. Motor power is switched off first; in
// BRIDGE the manufacturer's software is in charge and this firmware's guards are not active.
const int EE_BRIDGE = 0;
const uint8_t BRIDGE_MAGIC = 0xB7;
bool bridging = false;
uint8_t bridgeMatch = 0;
uint8_t slaveId = 0;
uint8_t flags = 0;
uint32_t seq = 0, tStart = 0, tLastSample = 0, tLastHost = 0;
int8_t lastDir = 0;               // +1 CW / forward, -1 CCW, 0 unknown
float lastCmd = 0;                // last speed command sent (output rpm)
uint8_t runawayCount = 0;         // consecutive samples that look like a runaway
long lastCounts = 0; bool haveCounts = false;   // speed estimated from counts (loops E and P)
uint32_t tLastCounts = 0;                        // millis() of lastCounts
struct LoopStats {                               // micros() statistics of the current/last run
  uint32_t n = 0, overruns = 0;
  uint32_t ctrlSum = 0, ctrlMax = 0;             // control law only (pidStep)
  uint32_t sampleSum = 0, sampleMax = 0;         // whole sample incl. Modbus and telemetry
} stats;
float lastSpeedAbs = 0;                          // |speed| at the previous sample
float piI = 0, piD = 0, piE = 0;  // controller state
bool piFirst = true;

// ================================================================== Modbus ASCII
static char hexDigit(uint8_t v) { return v < 10 ? '0' + v : 'A' + v - 10; }
static int8_t hexVal(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  return -1;
}

// Send id+pdu, receive the reply into rx (bytes after ':' decoded, LRC checked).
// Returns number of decoded bytes (excluding LRC), or -1 timeout, -2 bad LRC.
static int mbTransact(uint8_t id, const uint8_t *pdu, uint8_t n, uint8_t *rx, uint8_t rxMax) {
  while (drive.available()) drive.read();           // drop stale bytes
  uint8_t sum = id;
  for (uint8_t i = 0; i < n; i++) sum += pdu[i];
  uint8_t lrc = (uint8_t)(-sum);
  drive.write(':');
  drive.write(hexDigit(id >> 4)); drive.write(hexDigit(id & 15));
  for (uint8_t i = 0; i < n; i++) { drive.write(hexDigit(pdu[i] >> 4)); drive.write(hexDigit(pdu[i] & 15)); }
  drive.write(hexDigit(lrc >> 4)); drive.write(hexDigit(lrc & 15));
  drive.write('\r'); drive.write('\n');

  char line[48]; uint8_t len = 0; bool started = false;
  uint32_t t0 = millis();
  while (millis() - t0 < 150) {
    if (!drive.available()) continue;
    char c = drive.read();
    if (c == ':') { started = true; len = 0; continue; }
    if (!started) continue;
    if (c == '\r') continue;
    if (c == '\n') {
      if (len < 4 || (len & 1)) return -2;
      uint8_t nb = len / 2, s = 0;
      if (nb - 1 > rxMax) return -2;
      for (uint8_t i = 0; i < nb; i++) {
        int8_t h = hexVal(line[2 * i]), l = hexVal(line[2 * i + 1]);
        if (h < 0 || l < 0) return -2;
        uint8_t b = (h << 4) | l;
        s += b;
        if (i < nb - 1) rx[i] = b;
      }
      if (s != 0) return -2;
      if (rx[0] != id) return -3;                   // reply from another slave (e.g. a late answer)
      return nb - 1;
    }
    if (len < sizeof(line)) line[len++] = c; else return -2;
  }
  return -1;
}

static bool mbWrite(uint16_t reg, uint16_t val) {
  uint8_t pdu[5] = {6, (uint8_t)(reg >> 8), (uint8_t)reg, (uint8_t)(val >> 8), (uint8_t)val};
  uint8_t rx[8];
  int r = mbTransact(slaveId, pdu, 5, rx, sizeof(rx));
  if (r == -1) { flags |= F_MB_TIMEOUT; return false; }
  if (r < 0) { flags |= F_MB_LRC; return false; }
  return r == 6 && rx[1] == 6 && rx[4] == pdu[3] && rx[5] == pdu[4];   // echo
}

static bool mbRead(uint8_t id, uint16_t reg, uint8_t count, uint16_t *out) {
  uint8_t pdu[5] = {3, (uint8_t)(reg >> 8), (uint8_t)reg, 0, count};
  uint8_t rx[16];
  int r = mbTransact(id, pdu, 5, rx, sizeof(rx));
  if (r == -1) { flags |= F_MB_TIMEOUT; return false; }
  if (r < 0) { flags |= F_MB_LRC; return false; }
  if (r != 3 + 2 * count || rx[1] != 3 || rx[2] != 2 * count) return false;
  for (uint8_t i = 0; i < count; i++) out[i] = ((uint16_t)rx[3 + 2 * i] << 8) | rx[4 + 2 * i];
  return true;
}

static bool readPosition(long &counts) {
  uint16_t w[2];
  if (!mbRead(slaveId, REG_POS_FB, 2, w)) return false;
  counts = (long)(int32_t)(((uint32_t)w[1] << 16) | w[0]);   // low word first (vendor library); signed 32-bit
  return true;
}

static bool readSpeed(int &baseRpm) {
  uint16_t w;
  if (!mbRead(slaveId, REG_SPD_FB, 1, &w)) return false;
  baseRpm = (int16_t)w;                             // two's complement
  return true;
}

// Signed output-shaft rpm command -> direction (register 2) + magnitude (register 14).
static bool commandSpeed(float outRpm) {
  float base = fabs(outRpm) * GEAR;
  if (base > BASE_RPM_MAX) { base = BASE_RPM_MAX; flags |= F_CLAMP; }
  int8_t dir = outRpm >= 0 ? 1 : -1;
  bool ok = true;
  if (dir != lastDir) {
    ok = mbWrite(REG_MODE, dir > 0 ? MODE_SPEED_CW : MODE_SPEED_CCW);
    if (ok) lastDir = dir;
  }
  return mbWrite(REG_SPEED, (uint16_t)(base + 0.5f)) && ok;
}

static void findDrive();
static void startBridge();
void setup();

static void stopDrive(uint16_t word);

static void beginSoftStop() {
  running = false;
  digitalWrite(PIN_LED, LOW);
  if (!slaveId || !mbWrite(REG_SPEED, 0)) { stopDrive(MODE_SAFE_STOP); return; }   // keeps the direction word
  lastCmd = 0;
  stopping = true; tStopStart = tStopSample = millis(); stopLastAbs = 1e9;
}

// every 100 ms while stopping: power off once the drive reads rest, or at once if the motor
// speeds up, the drive does not answer, or the ramp takes longer than it can
static void softStopStep() {
  uint32_t now = millis();
  if (now - tStopSample < 100) return;
  tStopSample = now;
  int spd = 0;
  bool ok = readSpeed(spd);
  float a = ok ? fabs(spd / GEAR) : 1e9f;
  bool rest = ok && a < 1.0f;                        // the register reads in 4.6 rpm steps: 0 = rest
  bool bad = !ok || a > stopLastAbs + 5.0f || now - tStopStart > STOP_RAMP_MAX_MS;
  stopLastAbs = a;
  if (rest || bad) {
    stopDrive(MODE_SAFE_STOP);
    Serial.print(F("# soft stop: ")); Serial.print(now - tStopStart);
    Serial.println(rest ? F(" ms to rest, motor power off") : F(" ms, motor power cut early"));
  }
}
static void diag();

// ================================================================== host protocol
static uint8_t xorSum(const char *s) { uint8_t x = 0; while (*s) x ^= (uint8_t)*s++; return x; }

static void sendFrame(const char *body) {
  uint8_t cs = xorSum(body);
  Serial.write('$'); Serial.print(body); Serial.write('*');
  Serial.write(hexDigit(cs >> 4)); Serial.write(hexDigit(cs & 15)); Serial.write('\n');
}

static void ack(const char *type) {
  char b[24]; snprintf(b, sizeof(b), "ACK,1,%s", type); sendFrame(b);
}

static void err(const char *type, int code, const char *text) {
  char b[64]; snprintf(b, sizeof(b), "ERR,1,%s,%d,%s", type, code, text); sendFrame(b);
}

static void fmt(char *dst, float v, uint8_t dec) {
  if (isnan(v)) strcpy(dst, "nan"); else dtostrf(v, 1, dec, dst);
}

static void resetController() { piI = 0; piD = 0; piE = 0; piFirst = true; }

static void stopDrive(uint16_t word) {
  running = false; stopping = false;
  digitalWrite(PIN_LED, LOW);
  if (slaveId) mbWrite(REG_MODE, word);
  lastDir = 0;
}

static void handleLine(char *line) {
  // $TYPE,1,fields...*CS   (checksum optional for hand-typed commands)
  if (line[0] != '$') return;
  char *star = strrchr(line, '*');
  if (star) {
    *star = 0;
    uint8_t want = (hexVal(star[1]) << 4) | hexVal(star[2]);
    if (xorSum(line + 1) != want) { err("?", 1, "checksum"); return; }
  }
  char *tok[12]; uint8_t nt = 0;
  for (char *p = strtok(line + 1, ","); p && nt < 12; p = strtok(NULL, ",")) tok[nt++] = p;
  if (nt < 2 || strcmp(tok[1], "1") != 0) { err("?", 2, "version"); return; }
  const char *t = tok[0];
  tLastHost = millis();

  if (!strcmp(t, "PING")) { return; }
  if (!strcmp(t, "CFG")) {
    if (running) { err(t, 3, "stop first"); return; }
    if (nt != 10) { err(t, 4, "fields"); return; }
    if (!strchr("SEP", tok[2][0]) || tok[2][1]) { err(t, 4, "loop must be S E or P"); return; }
    cfg.loop = tok[2][0];
    strncpy(cfg.ctrl, tok[3], 3); cfg.ctrl[3] = 0;
    cfg.Kp = atof(tok[4]); cfg.Ki = atof(tok[5]); cfg.Kd = atof(tok[6]);
    cfg.Tf = atof(tok[7]) / 1000.0f; cfg.Ts = atof(tok[8]) / 1000.0f; cfg.uMax = atof(tok[9]);
    if (cfg.uMax > BASE_RPM_MAX / GEAR) cfg.uMax = BASE_RPM_MAX / GEAR;
    if (cfg.Ts < 0.05f) cfg.Ts = 0.05f;            // Modbus cannot go faster
    ack(t); return;
  }
  if (!strcmp(t, "SET")) { if (nt == 3) { setpoint = atof(tok[2]); ack(t); } else err(t, 4, "fields"); return; }
  if (!strcmp(t, "RUN")) {
    if (!slaveId) findDrive();                        // drive powered after the Uno: look again
    if (!slaveId) { err(t, 5, "no drive: check 12 V and wiring D8/D9/GND"); return; }
    if (flags & F_ESTOP) { err(t, 6, "estopped: power-cycle or HOME"); return; }
    stopping = false;                                  // a stop still ramping: the RUN sequence takes over
    resetController(); seq = 0; flags = 0; lastDir = 0; lastCmd = 0; runawayCount = 0; haveCounts = false; lastSpeedAbs = 0;
    stats = LoopStats();
    // The drive keeps LPR in RAM: after its own power cycle it reloads the saved value (334 on
    // the lab drive, seen 2026-10-11). Wrong LPR scales every speed by 334/13 = 25.7: enforce 13
    // before every run, not only at the Uno's boot.
    uint16_t lpr = 0;
    if (!mbRead(slaveId, REG_LPR, 1, &lpr)) { err(t, 9, "drive did not answer (modbus)"); return; }
    if (lpr != LPR_RMCS5032 && !mbWrite(REG_LPR, LPR_RMCS5032)) { err(t, 12, "could not set LPR 13"); return; }
    // HOME before every run, not only for position (the angle is measured from here). A speed
    // run started after the motor had come to rest under a 0 command and then STOP, without a
    // HOME in between, ran full speed in reverse at enable 12 times out of 12 on the lab drive
    // (2026-10-11, -23, -24); with a HOME first, 0 times. Cause inside the drive UNVERIFIED.
    // The HOME resets the drive's position count, and its speed estimate sees that as a jump:
    // enabling at once read -6000 base rpm for one sample and jerked the shaft ~50 counts
    // (2026-10-24). Let the estimate settle before the speed mode word enables the motor.
    bool ok = mbWrite(REG_MODE, MODE_HOME);
    if (ok) delay(150);
    ok = ok && commandSpeed(0);
    if (ok && cfg.loop == 'E') {                       // reference count for the first difference
      ok = readPosition(lastCounts); haveCounts = ok; tLastCounts = millis();
    }
    if (!ok) { stopDrive(MODE_SAFE_STOP); err(t, 9, "drive did not answer (modbus): check 12 V and wiring"); return; }
    running = true; tStart = tLastSample = millis();
    digitalWrite(PIN_LED, HIGH);
    ack(t); return;
  }
  if (!strcmp(t, "BRIDGE")) {
    if (running || stopping) { err(t, 3, "stop first"); return; }
    EEPROM.update(EE_BRIDGE, BRIDGE_MAGIC);
    ack(t); startBridge(); return;
  }
  if (!strcmp(t, "DIAG")) {
    if (running) { err(t, 3, "stop first"); return; }
    if (!slaveId) findDrive();
    diag(); ack(t); return;
  }
  if (!strcmp(t, "STOP"))  {
    bool now = nt >= 3 && !strcmp(tok[2], "NOW");
    if (running && !now) beginSoftStop(); else stopDrive(MODE_SAFE_STOP);
    ack(t); return;
  }
  if (!strcmp(t, "ESTOP")) { stopDrive(MODE_ESTOP); flags |= F_ESTOP; ack(t); return; }
  if (!strcmp(t, "HOME"))  {
    if (running) { err(t, 3, "stop first"); return; }
    if (stopping) stopDrive(MODE_SAFE_STOP);
    if (!mbWrite(REG_MODE, MODE_HOME)) { err(t, 9, "drive did not answer (modbus)"); return; }
    flags &= ~F_ESTOP; ack(t); return;
  }
  err(t, 7, "unknown");
}

static void pollHost() {
  static char buf[96]; static uint8_t n = 0;
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\r') continue;
    if (c == '\n') { buf[n] = 0; if (n) handleLine(buf); n = 0; }
    else if (n < sizeof(buf) - 1) buf[n++] = c;
    else n = 0;                                      // overlong line: drop
  }
}

// ================================================================== controller
// Identical to matlab/functions/+servolab/+motor/pidStep.m (clamping anti-windup).
static float pidStep(float e, bool &sat) {
  float Kp = cfg.Kp, Ki = cfg.Ki, Kd = cfg.Kd;
  if (!strcmp(cfg.ctrl, "P"))  { Ki = 0; Kd = 0; }
  if (!strcmp(cfg.ctrl, "I"))  { Kp = 0; Kd = 0; }
  if (!strcmp(cfg.ctrl, "PI")) { Kd = 0; }
  float d = piFirst ? 0 : (cfg.Tf * piD + Kd * (e - piE)) / (cfg.Tf + cfg.Ts);
  float iNew = piI + Ki * cfg.Ts * e;
  float uRaw = Kp * e + iNew + d;
  float u = constrain(uRaw, -cfg.uMax, cfg.uMax);
  sat = (u != uRaw);
  if (sat && Ki != 0 && ((uRaw > 0) == (e > 0))) {
    float pd = Kp * e + d;
    iNew = constrain(iNew, -cfg.uMax - pd, cfg.uMax - pd);
    if ((e > 0 && iNew < piI) || (e < 0 && iNew > piI)) iNew = piI;
    u = constrain(pd + iNew, -cfg.uMax, cfg.uMax);
  }
  piI = iNew; piD = d; piE = e; piFirst = false;
  return u;
}

static void controlSample() {
  uint32_t now = millis(), us0 = micros();
  float t = (now - tStart) / 1000.0f;
  long counts = 0; int spd = 0;
  float meas = NAN, posCounts = NAN, spdBase = NAN;
  bool ok;
  if (cfg.loop == 'S') {
    ok = readSpeed(spd);
    if (ok) { spdBase = spd; meas = spd / GEAR; }
  } else if (cfg.loop == 'E') {
    ok = readPosition(counts);
    uint32_t tc = millis();
    if (ok) {
      posCounts = counts;
      // actual time between the two reads, not the nominal Ts (Modbus timing jitters)
      if (haveCounts && tc != tLastCounts) meas = (counts - lastCounts) / CPR_OUT * 60000.0f / (tc - tLastCounts);
      lastCounts = counts; tLastCounts = tc; haveCounts = true;
    }
  } else {
    ok = readPosition(counts);
    if (ok) { posCounts = counts; meas = counts * 360.0f / CPR_OUT; }
  }
  if (!ok) {                       // no feedback: never act on stale data
    stopDrive(MODE_SAFE_STOP);
    err("RUN", 8, "modbus feedback lost - motor power off");
  }
  // Runaway guard (speed loop only): with encoder A/B reversed relative to the motor leads the
  // drive's own speed loop has positive feedback and runs the motor flat out the wrong way
  // (seen on the lab rig 2026-10-11: +20 rpm commanded, -166 rpm measured). Two bad samples
  // in a row (>= 0.2 s) -> E-STOP and tell the host.
  float speedNow = NAN;                               // output rpm actually turning
  if (ok && cfg.loop != 'P') speedNow = meas;
  if (ok && cfg.loop == 'P') {
    if (haveCounts) speedNow = (counts - lastCounts) / CPR_OUT * 60.0f / cfg.Ts;
    lastCounts = counts; haveCounts = true;
  }
  if (running && !isnan(speedNow)) {
    bool wrongWay = (lastCmd > 5 && speedNow < -10) || (lastCmd < -5 && speedNow > 10);
    bool tooFast = fabs(speedNow) > 2.0f * fabs(lastCmd) + 40.0f;
    // A commanded reversal or slow-down passes through these states while the drive ramps
    // (5000 base rpm/s = 50 output rpm/s on the lab drive), but then |speed| is falling.
    // A runaway holds or gains speed. Only count samples where |speed| is not falling.
    bool notSlowing = fabs(speedNow) >= lastSpeedAbs - 2.0f;
    lastSpeedAbs = fabs(speedNow);
    runawayCount = ((wrongWay || tooFast) && notSlowing) ? runawayCount + 1 : 0;
    // gross runaway (wrong way AND far above the command, e.g. -39 rpm asked, +166 measured on
    // the lab rig): no legitimate state looks like this, so stop on the first sample
    if (wrongWay && tooFast && notSlowing) runawayCount = 2;
    if (runawayCount >= 2) {
      stopDrive(MODE_ESTOP); flags |= F_ESTOP; runawayCount = 0;
      // (messages must fit err()'s 64-byte frame)
      err("RUN", 11, wrongWay ? "runaway: wrong way - swap encoder pins 10/11"
                              : "runaway: too fast - check encoder and LPR");
    }
  }
  float e = setpoint - meas, u = 0; bool sat = false;
  if (running) {
    if (!strcmp(cfg.ctrl, "OL")) {
      if (cfg.loop != 'P') u = setpoint;                  // speed loops S and E: command = setpoint
      else {                       // position: timed move at half speed
        float v = 0.5f * cfg.uMax, tOL = fabs(setpoint) / (6.0f * v);
        u = (t < tOL) ? (setpoint >= 0 ? v : -v) : 0;
      }
      u = constrain(u, -cfg.uMax, cfg.uMax);
    } else if (!isnan(e)) {
      uint32_t c0 = micros();
      u = pidStep(e, sat);
      uint32_t dc = micros() - c0;
      stats.ctrlSum += dc; if (dc > stats.ctrlMax) stats.ctrlMax = dc;
    }
    if (!commandSpeed(u)) { stopDrive(MODE_SAFE_STOP); err("RUN", 9, "modbus write failed - motor power off"); }
    lastCmd = u;
  }
  uint8_t f = flags | (running ? F_RUNNING : 0) | (sat ? F_SAT : 0);
  if (millis() - now > (uint32_t)(cfg.Ts * 1000)) f |= F_OVERRUN;

  // dtostrf has no length limit: 16 bytes hold any 32-bit count in degrees (+-1.5e8 with 3 decimals)
  char sp[16], me[16], er[16], uu[16], pc[16], sb[12];
  fmt(sp, setpoint, 2); fmt(me, meas, 3); fmt(er, e, 3); fmt(uu, u, 3);
  fmt(pc, posCounts, 0); fmt(sb, spdBase, 0);
  char body[144];
  snprintf(body, sizeof(body), "TEL,1,%lu,%lu,%c,%s,%s,%s,%s,%s,%s,%s,%X",
           (unsigned long)seq++, (unsigned long)(now - tStart), cfg.loop, cfg.ctrl,
           sp, me, er, uu, pc, sb, f);
  sendFrame(body);
  uint32_t ds = micros() - us0;
  stats.n++; stats.sampleSum += ds; if (ds > stats.sampleMax) stats.sampleMax = ds;
  if (f & F_OVERRUN) stats.overruns++;
}

// ================================================================== setup / loop
static void findDrive() {
  // A drive that has only just been powered can answer late. Each candidate must answer
  // twice in a row, from its own id, before it is accepted; a late reply to one id can
  // then never be mistaken for another id.
  slaveId = 0;
  for (uint8_t pass = 0; pass < 2 && !slaveId; pass++) {
    for (uint8_t i = 0; i < sizeof(CANDIDATE_IDS); i++) {
      uint16_t v;
      uint8_t id = CANDIDATE_IDS[i];
      if (mbRead(id, REG_ID, 1, &v)) {
        delay(30);
        if (mbRead(id, REG_ID, 1, &v)) { slaveId = id; break; }
      }
    }
    if (!slaveId) delay(300);
  }
  flags = 0;
  if (!slaveId) { Serial.println(F("# no RMCS-2303 answered on ids 11,7,1..6 (send $DIAG,1 or $RUN,1 to retry)")); return; }
  Serial.print(F("# RMCS-2303 found, slave id ")); Serial.println(slaveId);
  // LPR must be 13 for the RMCS-5032, or every rpm value is wrong by 334/13.
  uint16_t lpr = 0;
  if (mbRead(slaveId, REG_LPR, 1, &lpr) && lpr != LPR_RMCS5032) {
    Serial.print(F("# drive LPR was ")); Serial.print(lpr); Serial.println(F(", setting 13 (not saved to EEPROM)"));
    mbWrite(REG_LPR, LPR_RMCS5032);
  }
  mbWrite(REG_MODE, MODE_SAFE_STOP);
}

// Register dump for MOTOR-01, as '#' lines (human-readable, never parsed as data).
static void diag() {
  if (!slaveId) { Serial.println(F("# DIAG: no RMCS-2303 answered on ids 11,7,1..6")); return; }
  static const uint8_t regs[] = {0, 2, 4, 6, 8, 10, 12, 14, 24};
  static const char *const names[] = {"id/save", "mode", "P gain", "I gain", "VFF gain", "LPR", "accel", "speed cmd", "speed fb"};
  Serial.print(F("# DIAG slave ")); Serial.println(slaveId);
  for (uint8_t i = 0; i < sizeof(regs); i++) {
    uint16_t v;
    Serial.print(F("# reg ")); Serial.print(regs[i]); Serial.print(F(" ")); Serial.print(names[i]); Serial.print(F(" = "));
    if (mbRead(slaveId, regs[i], 1, &v)) { Serial.print(v); Serial.print(F(" (0x")); Serial.print(v, HEX); Serial.println(F(")")); }
    else Serial.println(F("no reply"));
  }
  long c;
  Serial.print(F("# position counts = "));
  if (readPosition(c)) Serial.println(c); else Serial.println(F("no reply"));
  if (stats.n) {
    Serial.print(F("# last run: ")); Serial.print(stats.n); Serial.print(F(" samples, Ts "));
    Serial.print((unsigned long)(cfg.Ts * 1000)); Serial.print(F(" ms, overruns ")); Serial.println(stats.overruns);
    Serial.print(F("# loop time control law us: mean ")); Serial.print(stats.ctrlSum / stats.n);
    Serial.print(F(" max ")); Serial.println(stats.ctrlMax);
    Serial.print(F("# loop time whole sample us: mean ")); Serial.print(stats.sampleSum / stats.n);
    Serial.print(F(" max ")); Serial.println(stats.sampleMax);
  }
  flags &= ~(F_MB_TIMEOUT | F_MB_LRC);
}

static void startBridge() {
  running = false; stopping = false;
  digitalWrite(PIN_LED, LOW);
  if (slaveId) mbWrite(REG_MODE, MODE_SAFE_STOP);   // motor power off before handing over
  Serial.println(F("# BRIDGE active: USB <-> drive at 9600 baud 8N1 for the manufacturer's software. Leave: $ENDBRIDGE at 9600, or the STOP button."));
  Serial.flush(); Serial.end(); Serial.begin(DRIVE_BAUD);
  bridging = true; bridgeMatch = 0;
}

static void endBridge() {
  EEPROM.update(EE_BRIDGE, 0);
  Serial.flush(); Serial.end();
  bridging = false;
  setup();                                          // start over as the controller (says HELLO)
}

static void bridgeStep() {
  static const char key[] = "$ENDBRIDGE";
  while (Serial.available()) {
    char c = Serial.read();
    drive.write(c);                                  // Modbus ASCII frames start with ':', never '$'
    if (c == key[bridgeMatch]) { if (key[++bridgeMatch] == 0) { endBridge(); return; } }
    else bridgeMatch = (c == '$') ? 1 : 0;
  }
  while (drive.available()) Serial.write((char)drive.read());
  if (digitalRead(PIN_STOP_BTN) == LOW) endBridge();
}

void setup() {
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_STOP_BTN, INPUT_PULLUP);
  Serial.begin(HOST_BAUD);
  drive.begin(DRIVE_BAUD);
  delay(1500);                                     // drive boot (it may have been powered with the Uno)
  findDrive();
  if (EEPROM.read(EE_BRIDGE) == BRIDGE_MAGIC) { startBridge(); return; }
  char b[48]; snprintf(b, sizeof(b), "HELLO,1,%s,%s,%u", FW_NAME, FW_REV, slaveId); sendFrame(b);
}

void loop() {
  if (bridging) { bridgeStep(); return; }
  pollHost();
  if (digitalRead(PIN_STOP_BTN) == LOW && !(flags & F_ESTOP)) {
    stopDrive(MODE_ESTOP); flags |= F_ESTOP;
    Serial.println(F("# STOP button: drive E-STOP"));
  }
  if (stopping) softStopStep();
  if (!running) return;
  uint32_t now = millis();
  if (now - tLastHost > 1000) {                      // host watchdog
    stopDrive(MODE_SAFE_STOP); flags |= F_WATCHDOG;
    err("RUN", 10, "host silent >1 s - motor power off");
    return;
  }
  if (now - tLastSample >= (uint32_t)(cfg.Ts * 1000)) {
    tLastSample += (uint32_t)(cfg.Ts * 1000);
    if (now - tLastSample > (uint32_t)(cfg.Ts * 1000)) tLastSample = now;   // fell behind
    controlSample();
  }
}
