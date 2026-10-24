# Software toolchain

## What the code needs

| Code | Needs |
|---|---|
| everything in `matlab/`, the app `rhino_servo_lab`, all tests except the Simulink ones | **MATLAB R2023b or newer**, no toolboxes |
| `matlab/models/dc_motor/*`, test_simulink_crosscheck, test_motor_identified (Simulink parts) | Simulink (those tests are *skipped*, not failed, without it) |
| `firmware/tests` (the firmware on the PC, the emulator) | a C++17 compiler (g++ or clang++) |
| recordings of the app as MP4 | MATLAB's `VideoWriter` (Windows, macOS); on Linux, ffmpeg |

CI runs the latest MATLAB on Windows, macOS and Ubuntu and R2023b on Ubuntu, for every change.
The development machine: Ubuntu 22.04, MATLAB R2026a with Simulink.

## Arduino toolchain (pinned, per user, every OS)

`setup fix` installs it the same way on Windows, macOS and Linux (`matlab/functions/+servolab/+tools/`):

| Item | Version | Where it comes from |
|---|---|---|
| Arduino CLI | 1.5.1, SHA-256 checked per platform | downloads.arduino.cc; hashes from the release's `1.5.1-checksums.txt`, pinned in `servolab.tools.manifest` |
| AVR core | arduino:avr 1.8.8 (avr-gcc 7.3.0, avrdude 8.0.0) | Arduino package index |
| Libraries | AltSoftSerial 1.4 (EEPROM: part of the core) | Arduino library index |

| OS | Tool folder (`servolab.tools.paths`, override with `SERVOLAB_TOOLS`) |
|---|---|
| Windows | `%LOCALAPPDATA%\arduino-lab-tools` (`C:\arduino-lab-tools` if that path is not plain ASCII: the AVR compiler fails on such paths) |
| macOS | `~/Library/Application Support/arduino-lab-tools` (Apple silicon needs Rosetta 2: avr-gcc and avrdude are x86_64 builds) |
| Linux | `~/.local/share/arduino-lab-tools` |

The folder is shared by the Arduino lab repositories of this family, so one download serves
all of them. The CLI gets its folders through `ARDUINO_DIRECTORIES_*` environment variables for
each call: no configuration file with machine paths exists, and an Arduino IDE on the same
computer (`~/.arduino15`, `Documents\Arduino`) is never touched. Shell helpers
(`scripts/setup/acli`, `upload`, `arduino-ide`) read the same folders from `scripts/setup/env.sh`.

## Commands

```matlab
setup                                   % path and checks
setup fix                               % also install the Arduino toolchain
servolab.tools.flash('motor', 'COM5')       % compile and upload (or '' to compile only)
cd matlab/tests; results = runtests     % every test
```

```bash
bash scripts/validation/host_tests.sh   # the firmware against its emulated plant, on the PC
python3 scripts/validation/check_repo.py
```
