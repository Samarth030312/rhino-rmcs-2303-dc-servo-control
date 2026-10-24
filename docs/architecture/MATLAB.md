# MATLAB architecture

```
setup.m                                one command: path, checks, toolchain, the app (repository root)
matlab/
├── setup_path.m                       path set-up only (repository folders only)
├── apps/
│   └── rhino_servo_lab/rhino_servo_lab.m    mission control (this page)
├── functions/+servolab/
│   ├── doctor.m                       the checks behind setup
│   ├── +tools/                        Arduino toolchain on Windows, macOS, Linux:
│   │                                  manifest (pinned versions + SHA-256), paths, cli,
│   │                                  install, flash, gitRev, sha256File
│   ├── +io/                           SerialLink (protocol v1), arduinoPorts (fast, every OS),
│   │                                  identifyPorts (USB ids via arduino-cli)
│   ├── +motor/
│   │   ├── missions.m                 the app's missions M1-M10 and LAB
│   │   ├── hwExperiments.m            the course hardware experiments (presets = their runs)
│   │   ├── rigModel.m                 the rig identified from its own steps (MEASURED)
│   │   ├── identifiedSim.m            the Arduino's loop around that model
│   │   ├── stepMetrics.m              every number of the mission table, sim and rig alike
│   │   ├── runIndex.m                 every recorded rig run (metadata only)
│   │   ├── ExperimentRunner.m         plays an experiment on the rig, saves each run
│   │   ├── HardwareLink.m             $TEL link to the motor firmware
│   │   ├── pidInit.m, pidStep.m       THE controller law (the firmware matches it)
│   │   ├── fitIdentified.m            fit K, tau, dead time, ramp to open-loop runs
│   │   └── params.m, simulate.m, ...  physical model (bare motor, drive estimate)
│   ├── +ui/                           palette, motorRig + motorRigPose (3-D), recordFrames
│   └── +protocol/                     encode / parse / checksum / decodeTelemetry / flagNames
├── models/dc_motor/                   Simulink: identified model and physical model
├── scripts/                           course answers, session reports, rig campaign, rig-vs-model analysis
└── tests/                             matlab.unittest (CI on Windows, macOS, Ubuntu);
    └── e2e/                           the app against the firmware emulator (pty)
```

## rhino_servo_lab: mission control

A programmatic `uifigure` (no App Designer binary) in a dark telemetry theme. Its layout
follows the sibling [STEVAL-EDUKIT01 rotary pendulum](https://github.com/Samarth030312/steval-edukit)
lab app, re-implemented here (no code is shared).

| Area | Content |
|---|---|
| Top bar | mission · link chip (OFFLINE / RIG port) · state chip (SIMULATION, READY, RUNNING, STOPPED, FAULT) · firmware and drive id · ● REC · run clock · **ABORT** (also Esc and Space) |
| Left | MISSION buttons M1-M10 and LAB; one-line purpose; preset (the runs of the mission's course experiment, or "▶▶ all runs"); SPEED / POSITION and DRIVE SPEED / ENCODER COUNTS toggles; controller law, Kp, Ki, command limit, Ts, setpoint profile, run length; ANTI-WINDUP toggle (M6); the identified rig model (K, ramp, latency, tau) with IDENTIFY FROM SELECTED RUN and RESET |
| Centre | the rig in 3-D: motor, gearbox, drive, Uno, battery and cables; the output disc turns with the measured or simulated angle, a cyan ring shows speed out of 180 rpm, a white tick the speed setpoint, a dashed radius the position setpoint, a wedge the last 80 ms of motion; four live numbers (speed, angle, command, error); one status line |
| Right | two plots only: the controlled variable (setpoint dashed, simulation grey, rig cyan, replay violet, course model dotted amber) and the command u with its limits; a third, the static map, only in M2 |
| Bottom | port, CONNECT, FLASH FIRMWARE, DRIVE CHECK, RUN ON RIG, STOP, CLEAR FAULT, PLAY SIMULATION · the SIM / RIG / REF table · LIVE SETPOINT (SEND, ±10, ZERO) · RUNS (filter, OVERLAY RUN, NEXT MISSION, PLAY, speed, scrub) |

**Simulation.** `servolab.motor.identifiedSim` with `servolab.motor.rigModel` and the settings on
the left, rerun 0.25 s after the last change. REF is the course's first-order model (K 1,
tau 0.72 s, no delay, no quantisation) for the speed missions, the theory the handout uses.

**Rig.** RUN ON RIG builds a one-run experiment from the settings (or plays the whole course
experiment for "▶▶ all runs") and hands it to `ExperimentRunner`. A 0.1 s timer polls the link,
draws the run, poses the 3-D rig, scores the RIG LIVE column and watches for firmware errors.
A firmware stop (runaway, Modbus loss, host silence, latched fault) ends the run, turns the
state chip red, says why and what to check, and highlights CLEAR FAULT. Every finished run is
saved by `exportHardwareRun` (raw CSV read-only, metadata JSON, a PNG of the window).

**Safety.** ABORT, STOP, Esc and Space send STOP first and tidy up after, so they never wait
for a plot. The firmware stops the drive by itself if it hears nothing for 1 s. Closing the
window sends STOP. A 1 s port watcher notices the board being plugged in (offers to flash and
connect) or pulled out (ends the run).

**Flashing.** FLASH FIRMWARE calls `servolab.tools.flash('motor', port)`, which installs the
pinned toolchain first if needed (`servolab.tools.install`), compiles with the git revision
compiled in, uploads, and writes a log; the same code runs on Windows, macOS and Linux.

## Scripting the app

`app = rhino_servo_lab()` returns handles and functions:
`app.selectMission(k)`, `app.setPreset(i)`, `app.set(name, value)`, `app.sim()`,
`app.metricsTable()`, `app.overlay(runId)`, `app.play('sim' | 'replay')`,
`app.record(outDir)`, `app.connect(port)`, `app.runRig()`, `app.stop()`, `app.abort()`,
`app.clearFault()`, `app.diag()`, `app.liveSet(v)`, `app.state()`, `app.runs()`.
`matlab/tests/test_motor_app.m` and `matlab/tests/e2e/e2e_motor_mission_control.m` use them.
