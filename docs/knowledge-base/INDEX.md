# Rhino DC Servo Lab: engineering knowledge base

## Purpose

This directory contains the engineering knowledge required to understand,
implement, simulate, test, and reproduce the experiments of this repository.

## Authority order

1. Manufacturer documentation for the actual hardware.
2. The experiment guidelines (for the ENR312 course: the handouts, see `../course/`).
3. Verified measurements from the physical apparatus.
4. Official software and library documentation.
5. Academic control-system references.
6. Explicitly labelled engineering estimates and assumptions.

Never present an estimate as a measured value.

## Reading order

1. `../hardware/HARDWARE_REFERENCE.md`
2. `ENGINEERING_DECISIONS.md`
3. `OPEN_ITEMS.md`
4. `CONTROL_THEORY.md`
5. `SOFTWARE_TOOLCHAIN.md`
6. `SIMULATION_POLICY.md`
7. `../architecture/SERIAL_PROTOCOL.md`
8. `SOURCE_REGISTER.csv`

## Evidence rules

- Record the software version used for every simulation.
- Record initial conditions, parameters, sample times, and controller gains.
- Preserve raw experimental data.
- Label synthetic data as synthetic.
- Never substitute simulated results for physical measurements.
- Preserve screenshots, recordings, and generated figures for reproducibility.
- Record limitations and failed tests, not just successful runs.

## Knowledge status

Every important technical claim must be classified as one of:

| Status | Meaning |
|---|---|
| VERIFIED_FROM_MANUAL | Stated in a registered source; page cited |
| MEASURED | Measured on this lab's apparatus; run ID cited |
| TESTED | Behaviour confirmed by a run or automated test; ID cited |
| ESTIMATED | Derived or typical value; derivation stated |
| ASSUMED | Taken as true without evidence, for a stated reason |
| UNVERIFIED | Unknown; tracked in `OPEN_ITEMS.md` |

## Scope

This repository: speed and position control of the RMCS-5032 motor through the RMCS-2303 drive from an Arduino Uno: hardware, firmware, MATLAB models and app, Simulink, measurements. The ENR312 course material is guidance in `../course/`.
