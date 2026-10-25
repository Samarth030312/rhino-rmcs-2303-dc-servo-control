# Session checklist: DC servo rig (RMCS-2303 + RMCS-5032)

For every session on the rig. The first-time items are for a new or re-wired rig.

## Before (each computer)

1. In MATLAB, from the repository: `setup`. Every FAIL comes with its fix. `setup fix` once per
   computer installs the Arduino toolchain (about 60 MB).
2. `setup open`, and one mission in simulation: the app works before the rig is involved.

## Unpowered (first time, and after any re-wiring)

- [ ] Battery to drive pin 16 (+) and pin 17 (GND), polarity checked with a multimeter. The
      battery (11.1 V nominal, 12.6 V full) is switched or unpluggable within reach.
- [ ] Motor cable by drive **pin number**, not by the manual's row alignment: Green → 8,
      Blue → 9, Yellow → 10, White → 11, thin Black → 14, thin Red → 15
      ([wiring](../hardware/WIRING.md); the datasheet's colours differ). Photograph it.
- [ ] Encoder supplied by the drive's +5 V (pin 9), not by the Uno and not by the battery.
- [ ] Uno ↔ drive: GND ↔ pin 1, D9 → pin 2 (RXD), D8 ← pin 3 (TXD). Nothing else; no battery
      wire on any Uno pin. STOP button between D4 and GND.
- [ ] Motor clamped; output shaft and disc free to turn both ways; nothing that can be thrown.

## Powered

- [ ] Battery charged: above 10.5 V; set the app's battery charge to match.
- [ ] Uno on USB: **Flash + connect** on a new board, else **CONNECT**. The top bar shows the
      firmware and drive id 7.
- [ ] **DRIVE CHECK**: LPR 13 (otherwise speeds are 25.7× wrong), acceleration 5000.
- [ ] First run M1, open loop: a positive command gives a positive speed, and the rig trace lies
      on the simulation's.
- [ ] Stopping tested once: **STOP** ramps the motor to rest, then switches motor power off;
      **ABORT** (or Esc, Space) and the **D4 button** switch it off at once.

## During

- Every run is saved and numbered in `data/RUN_REGISTER.csv`, stopped and aborted runs
  included. Cite run ids, not screenshots.
- A red **FAULT** chip: read the message, fix the cause ([troubleshooting](../TROUBLESHOOTING.md)),
  CLEAR FAULT.
- Abort at once on: an unexpected direction, a speed far from the command, a growing
  oscillation, a hot drive or motor, smell or noise.

## After

1. **SYNC DATA** in the app (or `git add data results; git commit; git push`) if this computer
   can push to your fork; otherwise copy `data/`.
2. `motor_session_report('YYYY-MM-DD', 'HH:MM')` writes the session's report
   (`results/reports/dc_motor/<day>/`).
3. Battery off and unplugged.
