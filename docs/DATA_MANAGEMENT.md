# Data management

Applies to every run of this repository (MOTOR-Rnnnn).

> **Raw data is evidence. It is never edited, never overwritten, never deleted, including when
> the run failed.** A failed run is a result.

## Classes of data

| Class | Produced by | Lives in |
|---|---|---|
| **RIG** | the real board and hardware | `data/raw/dc_motor/`, `data/metadata/dc_motor/` |
| **EMULATOR** | the firmware compiled for the PC against an emulated plant | a temporary folder (tests, CI); never `data/` |
| **SIMULATION** | MATLAB or Simulink | `results/` |

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
