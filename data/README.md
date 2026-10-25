# Data

Everything in here was measured on the real rig: an RMCS-2303 drive, an RMCS-5032 motor, an
Arduino Uno and a Pro-Range 11.1 V 3S2P battery. Nothing in `raw/` is simulated, and nothing
in it is ever edited (the app writes each file once and marks it read-only). Simulations go to
`results/evidence/simulation_runs/`, emulator runs to a temporary folder.

**193 runs** from 2026-10-11, -23, -24 and -25: 184 finished, 9 stopped by the firmware (most
of them the reverse runaway at start, before the fix; on 2026-10-25 a watchdog stop and a false
runaway stop, both fixed the same day; see `result` in the register).

## Layout

```
RUN_REGISTER.csv                       one line per run: the index
raw/dc_motor/MOTOR-Rnnnn_<date-time>_<mission>.csv     the samples, read-only
metadata/dc_motor/<run>.json           settings sent, firmware, OS, link statistics, events, result
metadata/dc_motor/<run>.png            the app's window when the run ended
```

A run id reads `MOTOR-R0076_20261024-233102_M5`: apparatus, run number (never reused), local
start time, mission. Ids from the first session (`MOTOR-02-HW-20261011-125838`) still resolve:
`servolab.data.resolve('MOTOR-02-HW-20261011-125838')`, and `legacy_id` in the register.

## Columns of a raw file

The firmware sends one `$TEL` frame per control sample (Ts = 0.1 s speed, 0.15 s position).

| Column | Unit | Meaning |
|---|---|---|
| `seq` | — | sample number from RUN (0 = first) |
| `t_ms` | ms | time since RUN, the Uno's clock |
| `loop` | — | `S` speed from the drive's register, `E` speed from encoder counts, `P` position |
| `ctrl` | — | `OL`, `P`, `I`, `PI`, `PID` |
| `setpoint` | rpm or deg | at the output shaft |
| `meas` | rpm or deg | what the controller read this sample |
| `err` | rpm or deg | setpoint − meas |
| `u` | rpm | command sent to the drive, output shaft, after the limit |
| `pos_counts` | counts | encoder position (5200 per output revolution); NaN in loop `S` |
| `spd_base_rpm` | rpm | the drive's speed register at the motor shaft (÷ 100 for the output); NaN in `E` / `P` |
| `flags` | bits | 1 running, 2 saturated, 4 Modbus timeout, 8 bad checksum, 16 E-stop, 32 clamped to the motor's speed, 64 watchdog, 128 sample overrun |
| `t_s` | s | `t_ms / 1000` |

## The register

`RUN_REGISTER.csv`: `run_id, apparatus, run_no, created, rig, mission, experiment,
run_in_series, controller, settings, result, rows, firmware, port, os, legacy_id, raw_file,
meta_file`. `result` is `FINISHED`, `STOPPED: <firmware's reason>` or `ABORTED: …`.

## Using it

```matlab
setup
R = servolab.data.register();                          % every run
I = servolab.motor.runIndex();                         % the same, with parsed settings
r = servolab.motor.loadHardwareRun('MOTOR-R0076_20261024-233102_M5');
plot(r.T.t_s, r.T.meas, r.T.t_s, r.T.setpoint)         % r.cfg: the settings, ready to simulate
```

In the app, RUNS lists them; select one and **OVERLAY RUN** draws it over the simulation of its
own settings. Reports built from this folder: [results](../results/README.md).
