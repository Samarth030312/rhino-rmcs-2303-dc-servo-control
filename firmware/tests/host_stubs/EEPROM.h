// EEPROM for the PC build of the sketch (tests only).
#pragma once
#include <cstdint>
struct HostEEPROM {
  uint8_t mem[1024] = {0};
  uint8_t read(int a) const { return mem[a]; }
  void write(int a, uint8_t v) { mem[a] = v; }
  void update(int a, uint8_t v) { mem[a] = v; }
};
inline HostEEPROM EEPROM;
