# The sequence: everything, in order

Each step says what to do, what you should see, and where to read more. Steps 1–5 need only
MATLAB; 6–10 need the rig.

## Without hardware

**1. Set up.** In MATLAB:

```matlab
gitclone("https://github.com/Samarth030312/rhino-rmcs-2303-dc-servo-control.git", Depth=1);
cd rhino-rmcs-2303-dc-servo-control
setup open
```

You see: a list of checks (all OK, or a WARN with its fix), then the app on **M5 · Speed PI**
with a simulation already drawn. Problems: [troubleshooting](TROUBLESHOOTING.md).

**2. The physics of the bare motor (M10).** Pick **M10 · Armature** (the plant menu switches to *MOTOR · armature voltage*). Step the
voltage, watch speed and current; add a load torque under DISTURBANCE; change the battery
charge in the physics panel and see the free speed follow. Read: [first principles §1](FIRST_PRINCIPLES.md#1-the-bare-motor-mission-m10).

**3. The rig as a model (M1, M2).** Plant menu on *RIG · identified from its runs*. M1: an open-loop step is a straight
ramp, not an exponential. M2: commanded against measured speed, a straight line through zero.
Read: [first principles §2](FIRST_PRINCIPLES.md#2-through-the-drive-a-speed-source-with-a-ramp).

**4. Closing the loop in simulation (M3–M9).** For each mission, play the presets, then change
one gain at a time. Before each change, write down what you expect; the SIM / REF columns of
the table tell you whether the textbook (REF) and the sampled, delayed loop (SIM) agree.

**5. Simulink.** **OPEN IN SIMULINK** on any mission opens the model of the chosen plant with the
same settings; run it and compare with the app. Read: [Simulink](SIMULINK.md).

## With the rig

**6. Build and wire** ([replicate](REPLICATE.md)), then the [checklist](safety/EXPERIMENT_CHECKLIST.md).

**7. Flash and connect.** Plug in the Uno: the app offers **Flash + connect**. **DRIVE CHECK**:
the drive's id, LPR 13, and the loop time.

**8. M1 on the rig.** One open-loop run. Positive command, positive speed; the coloured line
(rig) lies on the grey one (simulation of the same settings). If not, stop here: the direction,
the LPR, or the battery.

**9. M2 → M9 on the rig.** Each mission's hardware experiments ([catalogue](EXPERIMENTS.md)), presets one after the other
(the "▶▶ all runs" preset plays a whole series). Every run is saved as
`data/raw/dc_motor/MOTOR-Rnnnn_<date-time>_<mission>.csv` and listed in
`data/RUN_REGISTER.csv`. A whole campaign from a script:

```matlab
motor_rig_campaign('COM5')          % or '/dev/ttyUSB0', '/dev/cu.usbserial-…'; M1-M9, about 6 min of motion
```

**10. Analyse.**

```matlab
motor_session_report('2026-10-24', '23:00')                 % one session: each experiment, rig vs model
motor_rig_analysis({'2026-10-23', '2026-10-24'}, '2026-10-24')   % accuracy, repeatability, refit, Simulink
```

Both write to `results/reports/dc_motor/<day>/`. **SYNC DATA** in the app commits and pushes the
new runs (if you have write access to your fork).
