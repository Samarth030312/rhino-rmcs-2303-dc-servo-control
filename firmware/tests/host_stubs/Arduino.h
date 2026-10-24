// Minimal Arduino API for running sketches on the PC (tests only).
#pragma once
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <string>
#include <deque>
typedef uint8_t byte;
#define HIGH 1
#define LOW 0
#define INPUT 0
#define OUTPUT 1
#define INPUT_PULLUP 2
#define HEX 16
#define DEC 10
#define F(x) (x)
#define constrain(x, lo, hi) ((x) < (lo) ? (lo) : ((x) > (hi) ? (hi) : (x)))
using std::isnan; using std::fabs; using std::lround;
template <class A, class B> auto min(A a, B b) -> decltype(a + b) { return a < b ? a : b; }
template <class A, class B> auto max(A a, B b) -> decltype(a + b) { return a > b ? a : b; }

extern double g_now_ms;                 // virtual clock
uint32_t millis();
uint32_t micros();
void delay(unsigned long ms);
void delayMicroseconds(unsigned int);
void pinMode(uint8_t, uint8_t);
void digitalWrite(uint8_t, uint8_t);
int digitalRead(uint8_t);
void analogWrite(uint8_t, int);
unsigned long pulseIn(uint8_t, uint8_t, unsigned long);
char *dtostrf(double v, signed char width, unsigned char prec, char *buf);

class HostSerial {
 public:
  std::deque<char> in; std::string out;
  long baud = 0;
  void begin(long b) { baud = b; }
  void end() { baud = 0; }
  void flush() {}
  int available() { return (int)in.size(); }
  int read() { if (in.empty()) return -1; char c = in.front(); in.pop_front(); return (uint8_t)c; }
  size_t write(char c) { out += c; return 1; }
  size_t print(const char *s) { out += s; return strlen(s); }
  size_t print(char c) { out += c; return 1; }
  size_t print(long v, int base = DEC) { char b[24]; snprintf(b, sizeof b, base == HEX ? "%lX" : "%ld", v); out += b; return 1; }
  size_t print(unsigned long v, int base = DEC) { char b[24]; snprintf(b, sizeof b, base == HEX ? "%lX" : "%lu", v); out += b; return 1; }
  size_t print(int v, int base = DEC) { return print((long)v, base); }
  size_t print(unsigned int v, int base = DEC) { return print((unsigned long)v, base); }
  size_t print(uint8_t v, int base = DEC) { return print((unsigned long)v, base); }
  template <class T> size_t println(T v) { size_t n = print(v); out += "\n"; return n; }
  template <class T> size_t println(T v, int base) { size_t n = print(v, base); out += "\n"; return n; }
  size_t println() { out += "\n"; return 1; }
};
extern HostSerial Serial;
