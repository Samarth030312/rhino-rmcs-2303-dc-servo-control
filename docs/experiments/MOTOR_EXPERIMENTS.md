# DC-motor experiments MOTOR-01 … MOTOR-08

**Hardware experiment library** (run from `rhino_servo_lab` → mission → RUN ON RIG; definitions in
`matlab/functions/+servolab/+motor/hwExperiments.m`): MOTOR-02 speed steps open loop (20…120 rpm) ·
MOTOR-02 direction and reversal · MOTOR-03 speed tracking PI · MOTOR-05 speed P sweep (Kp 0.2/0.5/0.8) ·
MOTOR-06 speed I only · MOTOR-07 speed PI step · MOTOR-04 position moves P (90, −90, 360°) ·
MOTOR-05 position P sweep · MOTOR-06 position I only · MOTOR-07 position PI. Limits for the
11.2 V battery: |speed| ≤ 120 rpm, moves ≤ 1 rev. Each run is saved as raw data automatically.

Project IDs, not official course numbers. Each follows HYPOTHESIS → PROCEDURE → MEASUREMENTS →
VALIDATION → CONCLUSION (`../EXPERIMENT_TEMPLATE.md`). Status values: PLANNED, SIM-DONE,
HW-RUN, VALIDATED, FAILED.

Safety gate for every hardware step: `docs/safety/EXPERIMENT_CHECKLIST.md` completed and the
operator's approval recorded. Motor output shaft free or with a guarded load. Supply switch
within reach.

---

## MOTOR-01 — Verify the motor and drive configuration    `HW-RUN (register dump 2026-10-11)`

**Result (hw_session_20261011-122159.log, genuine Uno R3 SN 4423831393835191C0B1):**
slave id 7 · LPR 13 (correct, already saved in the drive) · P/I/VFF gains 32/30/25 (not factory
16/32 defaults: set by a previous user) · acceleration 5000 (factory 20000) · mode after boot
0x0201 (position mode, holding) · speed and position 0. Supply: 11.2 V battery (reported).
Still open: label photos, jumper state, supply measurement.

**Hypothesis.** The lab motor is an RMCS-5032 and the drive an RMCS-2303 as documented; the
drive's stored parameters are factory defaults (LPR 334, ID 11 or jumper-set).

**Procedure.** (unpowered) photograph labels, jumpers, wiring; read supply label (OI-M1).
(powered, motor disconnected or free) read all registers 0–24 with the vendor GUI or the
Arduino `READ_PARAMETER`; record them; set LPR = 13 and save only after review.

**Measurements.** Label text; jumper state; register dump; supply V/I rating; drive TXD idle
voltage (OI-M11).

**Acceptance.** Every row of HARDWARE_REFERENCE §1–2 that can be checked physically is either
confirmed or recorded as a conflict. OI-M1, M2, M10, M11 closed.

## MOTOR-02 — Encoder feedback and plant identification    `PLANNED`

**Hypothesis.** In Mode 1, a speed step produces a ramp at the acceleration-register rate and
settles with τ_d ≈ 25 ms (ESTIMATED); counts per output revolution = 5200.

**Procedure.** 1) Mark the shaft; command +1 output revolution in Mode 2; expect 5200 ± 2 counts.
2) Direction: command forward; check sign of counts (C-M3). 3) Speed steps 0 → 30, 90, 150
output rpm, logged at the fastest Modbus rate; repeat in reverse (OI-M6). 4) Time 200 Modbus
read/write cycles (OI-M8). 5) Measure R with a multimeter across the motor terminals (motor
disconnected from the drive), several shaft positions.

**Measurements.** counts/rev, sign, speed vs time, cycle time distribution, R.

**Validation.** Fit ramp rate, τ_d and delay; update `params.m` (status MEASURED, run IDs);
re-run `matlab/tests`.

**Acceptance.** counts/rev within ±0.1 %; cycle-time mean and 99th percentile recorded;
fitted model reproduces measured steps within 10 % RMS.

## MOTOR-03 — Speed control, Arduino outer loop    `SIM-DONE`

**Hypothesis.** With the drive in Mode 1, open-loop speed commands track well (drive closes its
own loop); an outer loop is needed only to correct scaling errors and load.

**Simulation.** Preset "Rig - speed - open loop (drive only)": SETTLED, 0 % error (because the
model is exact — on hardware this will not hold).

**Acceptance (hardware).** Logged setpoint, measurement, error, command at every sample; zero
missing sequence numbers; Stop and E-STOP both verified to halt the motor within 0.5 s.

## MOTOR-04 — Position control    `SIM-DONE`

**Hypothesis.** Open-loop timed moves miss the target (the acceleration ramp alone loses 70 % of
a 90° move in simulation); closed-loop P reaches it.

**Acceptance (hardware).** 90° step with P: final error ≤ 2 counts (0.14°), overshoot recorded.

## MOTOR-05 — P control    `SIM-DONE`

**Hypothesis.** Speed: e_ss = r/(1+K_p); oscillation as K_p → 1. Position: zero step error;
overshoot grows with K_p; unstable near 6 T_s K_p ≈ 2 (lower with latency).

**Simulation results** (`results/tables/dc_motor_simulation_metrics.csv`):
speed K_p 0.5 → 66.7 % error (theory 66.7 %); K_p 1.2 → OSCILLATING.
Position K_p 0.3 → SETTLED, 0 % overshoot; K_p 1.5 → OSCILLATING.

**Acceptance (hardware).** Measured e_ss for K_p ∈ {0.2, 0.5, 0.8} within 5 percentage points of
r/(1+K_p) — or a documented reason why not (e.g. dead band).

## MOTOR-06 — I control    `SIM-DONE`

**Hypothesis.** Speed: I alone removes the error, slower than PI. Position: I alone oscillates.

## MOTOR-07 — PI control    `SIM-DONE`

**Hypothesis.** Speed: zero error, faster than I alone, small overshoot. Position: PI adds
overshoot and a slow tail with little benefit, because the drive already rejects load.

## MOTOR-08 — Simulation vs hardware    `PLANNED`

Overlay each hardware run on the simulation prediction for the same settings (the app does this
live). Report rise time, overshoot, e_ss differences and explain each. Required by course week 11.

---

## ED-M1 option A (drive-internal gains) — exploratory, hardware only

Vary PPG (P) and PIG (I) in Mode 2 for a 90° step; log position feedback. No simulation claim
is made for this option.
