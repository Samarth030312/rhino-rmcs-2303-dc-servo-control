# Data Management

Applies to all ENR312 experiments in this repository: TEMP-xx, LEVEL-xx, MOTOR-xx, PNEU-xx.
(Rewritten 2026-10-09 for ENR312; an earlier version inherited from another project is in git
history, commit e5dcf90.)

> **Raw data is evidence. It is never edited, never overwritten, never deleted — including
> when the run failed.** A failed run is a result.

## 1. Three data classes — never mixed

| Class | Meaning | Location | Marking |
|---|---|---|---|
| **HARDWARE** | Measured on the physical rig | `data/raw/<subsystem>/` (read-only) | metadata `data_class: HARDWARE` |
| **SIMULATION** | Produced by a model (MATLAB, Simulink, FluidSIM) | `results/evidence/simulation_runs/`, `results/evidence/screen_recordings/` | `run_config.json` `data_class: SIMULATION`; figure titles say SIMULATION |
| **SYNTHETIC** | Generated only to exercise a pipeline (tests) | test temporary folders | never written into `data/` or `results/` |

Subsystem folder names: `temperature`, `water_level`, `dc_motor`, `pneumatic`.

## 2. Directory contract

```
data/
  raw/<subsystem>/<run_id>.csv           IMMUTABLE hardware telemetry (apps write it read-only)
  metadata/<subsystem>/<run_id>.json     sidecar written by the app at export
  metadata/TEMPLATE.yaml                 fields to add by hand (operator, wiring photo, ...)
  processed/<subsystem>/                 derived data; must name its raw source
results/
  evidence/simulation_runs/<subsystem>/<run_id>/   trace.csv, run_config.json, summary.md, figure.png, simulation.mp4
  evidence/screen_recordings/<subsystem>/<run_id>/ screen.mp4 + README.md (FluidSIM, hardware videos)
  evidence/VIDEO_INDEX.md                generated list of every recording
  figures/<subsystem>/, tables/          generated comparison figures and metric tables
```

## 3. Run IDs

`<EXPERIMENT>-<SIM|HW|FS>-<yyyyMMdd-HHmmss>[-n]`, e.g. `TEMP-06-SIM-20261009-150420`,
`MOTOR-05-HW-20261012-101500`, `PNEU-01-FS-001` (FluidSIM). Allocated by
`servolab.newRunId`, which never reuses an ID.

## 4. Metadata

Apps write the sidecar automatically: configuration sent, firmware revision (from `$HELLO`),
invalid-line and sequence-gap counts, event log. Add by hand from `data/metadata/TEMPLATE.yaml`:
operator, wiring-photo file, supply reading, anomalies, outcome.

`FW_REV` is the git short hash baked in by `scripts/setup/upload`, with `-dirty` if the tree
had uncommitted changes. Data from a dirty tree is not reproducible; recording that honestly is
more useful than hiding it.

## 5. Units and conventions

| Quantity | Unit | Convention |
|---|---|---|
| Temperature | °C | error = setpoint − reading |
| Level | % of the calibrated full height (and cm) | error = setpoint − level |
| Motor speed | output-shaft rpm (base rpm only in raw drive fields) | |
| Motor position | output-shaft degrees; counts (5200 / rev) in raw data | sign UNVERIFIED until MOTOR-02 |
| Time | s from RUN (`t_ms` in telemetry) | Arduino `millis()`, not an independent clock |
| Control signal | 0..255 (temperature, level) or output rpm (motor) | |

## 6. Processing rules

1. Read from `data/raw/`; never write there.
2. Every processed file names its source raw file and the script revision.
3. Every figure states its data class (MEASURED / SIMULATION).
4. Analysis checks the CSV header and refuses to guess columns.

## 7. Failed runs

Keep them. Set `execution_status: FAILED` with the reason, diagnose, repeat under a new run ID.
