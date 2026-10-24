# Live session checklist (DC servo rig)

## Before the session (each computer)

1. `git pull` (or the install line again), then in MATLAB from the repository: `setup`. Every
   FAIL comes with its fix.
2. `setup fix` once per computer: installs the Arduino toolchain (about 60 MB).
3. `setup open`, PLAY SIMULATION on one mission.

## At the bench

| Step | |
|---|---|
| Safety | battery unplugged while wiring; shaft and disc free to turn both ways; connector within reach |
| Battery | charged (12.6 V full; below ~10.5 V, recharge); set the app's battery charge |
| Wiring | [wiring](../hardware/WIRING.md), by pin number on the drive |
| Plug in the Uno | **Flash + connect** the first time on a board, else **Connect** |
| Check | DRIVE CHECK: slave id, LPR 13, loop time about 75 ms |
| First run | M1, open loop: positive command, positive speed |
| Stop | ABORT (also Esc or Space): motor power off at once; STOP: ramp to rest, then off |

## During

- Every run is saved and numbered (`data/RUN_REGISTER.csv`), stopped and aborted runs included.
- A red FAULT chip: read the message, fix the cause, CLEAR FAULT.
- RUNS → pick a run → OVERLAY RUN compares it with the simulation of its own settings.

## After

1. **SYNC DATA** (or `git add data results && git commit && git push`) if this computer has
   write access to the repository; otherwise copy `data/` from the computer.
2. `motor_session_report('YYYY-MM-DD')` for the session's report.
