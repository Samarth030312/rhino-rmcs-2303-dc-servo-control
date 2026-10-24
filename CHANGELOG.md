# Changelog

## 1.0.0 (2026-10-25): first public release

The DC-servo apparatus of an Arduino control lab, released on its own. It brings:

- **Firmware** for the Arduino Uno: outer P / I / PI / PID loops on speed (drive register or
  encoder counts) and position around the RMCS-2303's own speed loop, Modbus ASCII to the
  drive, protocol v1 to the PC, watchdog, runaway guard, HOME at every RUN (fixes a full-speed
  reverse start found on the rig), a soft stop at the end of a run, and a BRIDGE mode for the
  manufacturer's configuration software.
- **The `rhino_servo_lab` app**: missions M1–M10 and LAB, a 3-D rig with the real dimensions,
  the physics of the motor from its datasheet (with the battery), a model identified from the
  rig, the SIM / RIG / REF table, recording, replay, overlay of any run, OPEN IN SIMULINK.
- **Two Simulink models** generated from code, matching the MATLAB models exactly.
- **112 rig runs** (2026-10-11 to 10-24) with their logs, three session reports and an analysis
  of the model against every run.
- **Set-up** on Windows, macOS and Linux in one line, with the project's own pinned,
  hash-checked Arduino toolchain; CI runs the installer, the firmware build, every test and the
  app against the emulated drive on all three systems.
