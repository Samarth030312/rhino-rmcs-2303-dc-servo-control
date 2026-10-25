# Changelog

## 1.0.1 (2026-10-25): verified on the rig

Release acceptance on the lab rig with the final firmware `886b32c`: every course experiment of
M1-M9, 27 of 27 runs finished, no fault ([report](results/reports/dc_motor/2026-10-25/REPORT.md),
[analysis](results/reports/dc_motor/2026-10-25/ANALYSIS.md)). Found on the rig that day and fixed:

- **Soft stop** powered the motor off at up to ~7 rpm: the drive's speed register reads 0 below
  4.6 rpm. Rest now also needs the encoder still. 79 soft stops that day, none early.
- **Host watchdog** stopped one run: the app blocked for 1.1 s after RUN. The app now prepares
  and redraws before RUN; the watchdog is 2 s (stalls measured up to 0.93 s with Simulink open).
- **Runaway guard** stopped a correct run at a commanded -150 -> 0 rpm; it now allows for the
  drive's ramp.
- **BRIDGE** after a reset comes back silent at 9600 at once: verified on the drive, the first
  answer 1.0 s after the port opens. Registers read through the bridge equal DRIVE CHECK's.
- **Simulink build** no longer breaks when the workspace holds a variable named like a model
  parameter (`R`, `J`, ...).
- Upload and IDE helpers name this repository's sketch only.

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
