# Data management and recording

Applies to every rig run of this repository (MOTOR-Rnnnn). The record must let another
engineer reconstruct what happened from it alone.

> **Raw data is evidence. It is never edited, never overwritten, never deleted, including when
> the run failed.** A failed run is a result.

## Classes of data

| Class | Produced by | Lives in |
|---|---|---|
| **RIG** | the real board and hardware | `data/raw/dc_motor/`, `data/metadata/dc_motor/` |
| **EMULATOR** | the firmware compiled for the PC against an emulated plant | a temporary folder (tests, CI); never `data/` |
| **SIMULATION** | MATLAB or Simulink | recomputed from the code; summary tables in `results/tables/` |

## Names

A rig run is `MOTOR-Rnnnn_<yyyymmdd-HHMMSS>_<mission>`, for example
`MOTOR-R0012_20261101-101500_M5`: the apparatus, a run number never reused, the local start
time, the mission. `data/RUN_REGISTER.csv` holds one line per run; the number comes from it.

## What is kept for a run

| File | Content |
|---|---|
| `data/raw/dc_motor/<run>.csv` | every telemetry frame of the run (columns: [data](../data/README.md)), written once, read-only |
| `data/metadata/dc_motor/<run>.json` | the settings sent, the firmware revision, MATLAB version, OS, port, link statistics, the firmware's events, the result |
| `data/metadata/dc_motor/<run>.png` | the app's window when the run ended |
| `results/evidence/logs/hw_session_<time>.log` | every line between the app and the board in that session, both directions |

Every run is saved: finished, stopped by the firmware (`STOPPED: <reason>`) or by the operator
(`ABORTED`). **SYNC DATA** in the app commits `data/` and `results/` and pushes them.

## Before, during and after a run

1. **Before.** A clean tree (`git status`), or accept that the firmware revision will say
   `-dirty`. The [session checklist](safety/EXPERIMENT_CHECKLIST.md); a photo of the wiring.
   The firmware flashed from the app (or `scripts/setup/upload`); CONNECT shows its `$HELLO`;
   DRIVE CHECK.
2. **During.** Note, at the time, anything seen, heard or smelt, any deviation from the
   procedure, and why a run was stopped. The app records everything else.
3. **After.** Commit the data (SYNC DATA) **before** analysing it, so the evidence is fixed
   before it is interpreted. Then compare with the simulation of the same settings (RUNS →
   OVERLAY RUN) and write up with `motor_session_report('YYYY-MM-DD', 'HH:MM')`.

## Rules

1. Never edit raw data. 2. Never delete a failed run. 3. Never reuse a run id.
4. Never record a value the run did not produce. 5. A disagreement with the model is a finding,
not something to tune away.
