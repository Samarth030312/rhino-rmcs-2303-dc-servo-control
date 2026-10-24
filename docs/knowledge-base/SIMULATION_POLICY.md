# Simulation Policy

## 1. A simulation is a prediction, not a measurement

- Every simulated figure title says **SIMULATION** and "not measured".
- Every exported run has `data_class: SIMULATION` in `run_config.json`.
- Simulation output lives under `results/`. It never goes into `data/raw/`.
- A simulation that "matches the course's expected behaviour" is not validation of the
  hardware. Only MOTOR-08 (overlay of measured and simulated runs) is.

## 2. Parameters carry their status

- All plant parameters come from one place: `matlab/functions/+servolab/+motor/params.m`.
- Each has `status` ∈ {VERIFIED_FROM_MANUAL, MEASURED, TESTED, ESTIMATED, ASSUMED, UNVERIFIED}
  and a source ID. A test fails if any parameter claims MEASURED before a measurement exists.
- When the app user moves a physics slider, the exported status becomes
  `USER_OVERRIDE (ESTIMATED)`.
- When MOTOR-02 measures a value: change the number **and** the status, and write the run ID
  in the `source` field.

## 3. Simulate the controller that will run

The simulation reproduces the firmware loop, not an idealised continuous one: sample time,
command latency, encoder/rpm quantisation, output clipping and the exact anti-windup law
(`pidStep.m`). If the firmware changes any of these, the simulation must change with it.

## 4. Reproducibility

Each exported run records: run ID, MATLAB version, git revision and dirty flag, the full
configuration, every parameter with its status, the metrics, and (if recorded) the video
file name, size and capture method. The configuration alone must reproduce the run:

```matlab
meta = jsondecode(fileread('run_config.json'));   % then rebuild c from meta.config
```

## 5. Two implementations must agree

The bare-motor model exists in MATLAB (`simulate.m`) and Simulink (`servo_armature.slx`).
`test_simulink_crosscheck` requires agreement to 10⁻⁶ relative; measured agreement on
2026-10-09 was < 10⁻¹⁰. If they disagree, one of them is wrong; do not loosen the tolerance.

## 6. What the simulations do not represent

Listed in the app's "Model limits" panel and in each experiment's LIMITATIONS: undocumented
drive internals, Modbus timing not measured, no stiction/dead band/backlash, ideal current loop,
direction sign unverified. Reports must repeat these next to any simulated result.

## 7. Recordings

See `docs/architecture/VIDEO_AND_EVIDENCE.md`. A run is "recorded" only if the video file
exists and opens; the recorder writes its size into `run_config.json`.
