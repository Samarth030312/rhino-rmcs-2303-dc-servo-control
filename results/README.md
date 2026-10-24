# Results

Built from `data/` by scripts in `matlab/scripts/`; rerun a script and its output is rewritten.

```
reports/dc_motor/<date>/REPORT.md        one rig session: every course experiment, rig against model
                                         (motor_session_report)
reports/dc_motor/2026-10-24/ANALYSIS.md  all runs of 2026-10-23 and 24: model accuracy, repeatability,
                                         refit, the runaway record, physics, Simulink (motor_rig_analysis)
                         analysis_runs.csv, analysis_run_starts.csv   the numbers behind it, one row per run / start
figures/app_mission_control.png          the app with a rig run over its simulation
figures/dc_motor/                        earlier comparison figures (2026-10-11 session, simulation sweeps)
tables/dc_motor_simulation_metrics.csv   every simulation preset scored (motor_formal_runs)
evidence/logs/                           hw_session_*.log: every frame between the app and the board, per
                                         session; flash_*.log: every firmware build and upload;
                                         campaign_*.log/csv: scripted rig campaigns
evidence/simulation_runs/dc_motor/       one folder per recorded simulation preset (config, data, figures)
```

| Session | Report | What happened |
|---|---|---|
| 2026-10-11 | [findings](../docs/experiments/HW-SESSION-20261011-1314_FINDINGS.md) | first runs; the encoder wired in reverse ran the motor away; fixed; 20 runs |
| 2026-10-23 | [report](reports/dc_motor/2026-10-23/REPORT.md) | every course experiment on the rig, 39 runs |
| 2026-10-24 | [report](reports/dc_motor/2026-10-24/REPORT.md), [analysis](reports/dc_motor/2026-10-24/ANALYSIS.md) | the campaign M1–M9 again, the reverse runaway found and fixed, latency measured, 51 runs |
