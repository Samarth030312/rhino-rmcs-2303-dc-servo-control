# Experiment recording protocol

Applies to every rig run of this repository (MOTOR-Rnnnn).

> **The repository must let another engineer reconstruct what happened from the record alone.**

## 1. Before the run

1. A clean tree (`git status`), or accept that the firmware revision will say `-dirty`.
2. Wiring checked against [wiring](hardware/WIRING.md); the [checklist](safety/EXPERIMENT_CHECKLIST.md) ticked; a photo of the rig.
3. The firmware flashed from the app (or `motor` with `scripts/setup/upload`); CONNECT shows its `$HELLO`; DRIVE CHECK.

## 2. During the run

Note, at the time: anything seen, heard or smelt; any deviation from the procedure; why a run was
stopped. The app records everything else.

## 3. After

1. The run is saved by itself when it ends: raw CSV, metadata, register line ([data management](DATA_MANAGEMENT.md)).
2. Commit the data **before** analysing it (SYNC DATA), so the evidence is fixed before it is interpreted.
3. Compare with the simulation of the same settings (RUNS → OVERLAY RUN); write up: motor_session_report('<date>').

## 4. Rules

1. Never edit raw data. 2. Never delete a failed run. 3. Never reuse a run id.
4. Never record a value the run did not produce. 5. A disagreement with the model is a finding,
not something to tune away.
