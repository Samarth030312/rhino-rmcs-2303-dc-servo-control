// Test stub: AltSoftSerial wired to an emulated RMCS-2303 (see firmware_host_test.cpp).
#pragma once
#include "Arduino.h"
void driveEmuRx(char c);                 // bytes the sketch sends to the drive
extern std::deque<char> g_driveTx;       // bytes the drive sends back
class AltSoftSerial {
 public:
  void begin(long) {}
  int available() { return (int)g_driveTx.size(); }
  int read() { if (g_driveTx.empty()) return -1; char c = g_driveTx.front(); g_driveTx.pop_front(); return (uint8_t)c; }
  size_t write(char c) { driveEmuRx(c); return 1; }
};
