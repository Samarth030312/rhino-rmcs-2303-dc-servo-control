# Simulation policy

## 1. A simulation is a prediction, not a measurement

- Simulations are recomputed from the code, never stored in `data/raw/`; an exported simulation
  (`servolab.motor.exportRun`) is labelled SIMULATION (`data_class` in its metadata).
- Agreement with the textbook is not validation. Only a rig run, overlaid on the simulation of
  its own settings (RUNS → OVERLAY RUN), validates the model.

## 2. Parameters carry their status

All plant parameters come from `servolab.motor.params` and carry a status (VERIFIED_FROM_MANUAL,
MEASURED, TESTED, ESTIMATED, ASSUMED, UNVERIFIED; see [INDEX](INDEX.md)) and a source. A
MEASURED value names the session it came from. When a measurement replaces an estimate, change
the number **and** the status.

## 3. Simulate the controller that will run

The simulation reproduces the firmware's loop, not an idealised continuous one: its sample
time, its command latency, its quantised measurement, its output limit and its control law
(`servolab.motor.pidStep`, line for line the firmware's `pidStep`). If the firmware changes any
of these, the simulation changes with it, in the same commit.

## 4. Two implementations must agree

Each plant has two implementations, MATLAB (`servolab.motor.simulatePlant`) and Simulink
(`servo_identified`, `servo_drive_physics`, `servo_armature`). `test_simulink_crosscheck` runs
every preset in both and requires agreement to 1e-8; they agree to about 1e-10
([Simulink](../SIMULINK.md#verification)). If they disagree, one of them is wrong: fix it, do
not loosen the tolerance.

## 5. What the simulation does not represent

the drive's internals beyond its measured ramp, gain and latency (the drive-physics plant's
speed loop is an estimate); the motor's temperature; the battery's voltage on the day, unless
it is set in the app. A report repeats these next to any simulated result it uses.
