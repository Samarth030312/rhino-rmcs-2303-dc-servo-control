# Experiment Recording Protocol

Applies to every physical run of TEMP-xx, LEVEL-xx, MOTOR-xx and every FluidSIM run (PNEU-xx).
(Rewritten 2026-10-09 for ENR312; the inherited version is in git history, commit e5dcf90.)

> **The repository must let another engineer reconstruct what happened from the record
> alone.** If it is not written down at the time, it did not happen.

## 1. Before the run

1. Clean tree: `git status --porcelain` empty, or accept that FW_REV will say `-dirty`.
2. Wiring checked against `docs/wiring/<SUBSYSTEM>_WIRING.md`; pre-power checklist
   (`docs/safety/EXPERIMENT_CHECKLIST.md` for the motor) ticked; wiring photographed.
3. Firmware uploaded with `scripts/setup/upload <motor|temperature|level> <port>`; `$HELLO`
   seen in the app status line.
4. Start a screen or phone recording if the run needs video
   (`scripts/recording/record_screen.sh <subsystem> <run_id>` for the screen).

## 2. During the run

Record contemporaneously in `<subsystem>/experiments/<run_id>.md`: start/stop wall-clock time,
starting state (room temperature, tank level, motor marker angle), anything seen, heard or smelt,
any deviation from the procedure, and why a run was stopped.

## 3. Immediately after

1. In the app: **Export** (hardware mode). This writes `data/raw/<subsystem>/<run_id>.csv`
   (read-only) and `data/metadata/<subsystem>/<run_id>.json`.
2. Add the hand-written fields from `data/metadata/TEMPLATE.yaml` into the sidecar.
3. Commit raw data + metadata **before** analysis, so evidence is fixed before it is interpreted.

## 4. Analysis and status

Only after the run: compare with the simulation prediction (the app overlays it live), fill
VALIDATION and CONCLUSION in the experiment plan. A run that happened but failed its criteria is
`HW-RUN`, not `VALIDATED` — a legitimate and useful state.

## 5. Rules

1. Never edit raw data. 2. Never delete a failed run. 3. Never reuse a run ID.
4. Never record a value the run did not produce. 5. Disagreement with the model is a finding,
not something to tune away.
