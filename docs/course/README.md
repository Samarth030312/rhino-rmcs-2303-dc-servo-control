# ENR312 course guide (Ahmedabad University)

For students of the ENR312 Control Systems Laboratory, whose DC-motor apparatus this is. The
rest of the repository is general; this page only maps the MOTOR handout to the experiment that
answers each question. Run it, read the numbers, and write the answer in your own words.

## Which experiment answers which question

| Handout | Mission · experiment in the app | What it gives you |
|---|---|---|
| §1 task 1, the motor | (none) | [hardware reference](../hardware/HARDWARE_REFERENCE.md) §1 and your motor's label |
| §1 task 2, the driver | DRIVE CHECK | the drive's registers; [hardware reference](../hardware/HARDWARE_REFERENCE.md) §2 |
| §1 task 3, speed and position from the Arduino | M1, M7 | the firmware in `firmware/motor_controller` |
| §1 task 4, P, I and PI | M3, M4, M5 (speed) · M7, M8, M9 (position) | each controller, simulated and on the rig |
| S3-1 resolution | (none) | [first principles §3](../FIRST_PRINCIPLES.md#3-the-sampled-outer-loop): encoder lines, gear ratio, Ts |
| S3-2 speed from counts | M1 · Open-loop step 0 → 60 rpm, runs 1 and 2 | the same step read from the drive register and from the encoder |
| S3-3 static map | M2 · Static map | dead zone, slope and saturation, both directions |
| S3-4 K and τ | M1 · Open-loop step 0 → 60 rpm | the step's shape; whether a first-order model fits it |
| S3-5 position P final error | M7 · Position P final error on 10 deg moves | the final error for three gains, in encoder counts |
| S3-6 loop time | DRIVE CHECK after a run | the firmware's own timing of its loop |
| S3-7 Simulink model against measurements | OPEN IN SIMULINK, plant *identified*; RUNS → OVERLAY RUN | [Simulink](../SIMULINK.md) |
| S3-8 more inertia | M10 (inertia factor); the *drive physics* plant | why the bare motor and the rig answer differently |
| S3-9 I only, damping | M4 · Speed I only, Ki sweep | four gains: theory (REF), model (SIM), rig |
| S3-10 PI for ζ 0.7 | M5 · Speed PI designed for zeta 0.7 | design on paper first; then SIM; then the rig |
| S3-11 why P stops short | M7 · Position P final error on 10 deg moves | what the drive does near zero speed |
| S3-12 windup | M6 · Saturation and windup | ANTI-WINDUP on and off in simulation; the rig clamps |
| Assignment 3 (Simulink) | M10, and any mission on the *identified* plant | [Simulink](../SIMULINK.md): the three models and why |

## Your data

Every rig run is saved by itself, finished or stopped:
`data/raw/dc_motor/MOTOR-Rnnnn_<date-time>_<mission>.csv` (read-only), its settings in
`data/metadata/`, and one line in `data/RUN_REGISTER.csv`. Cite the run id (`R0123`) for every
hardware number in your report. RUNS in the app lists the runs; OVERLAY RUN draws any of them
over the simulation of its own settings. After the session,
`motor_session_report('YYYY-MM-DD', 'HH:MM')` turns your runs into figures and tables
([data](../../data/README.md)).

## How to learn from it

1. Before each run, write down what you expect: the textbook's number (REF) and the model's
   (SIM). Then run the rig.
2. Where they differ, find out why: the drive's ramp, the Modbus delay, the 100 ms sampling,
   the quantised feedback. [First principles](../FIRST_PRINCIPLES.md) covers each one.
3. Change one thing at a time, in simulation first.

Before the rig: the [session checklist](../safety/EXPERIMENT_CHECKLIST.md). Your numbers may
differ from the earlier [results](../RESULTS.md) (battery charge, another day); say how and why.
