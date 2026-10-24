# MOTOR-04-SIM-20261009-135937

**Data class: SIMULATION.** MODEL output. Not measured. Plant parameters are ESTIMATED unless marked otherwise.

| Setting | Value |
|---|---|
| Plant | rig |
| Loop | position |
| Controller | OL |
| Kp / Ki / Kd | 0 / 0 / 0 |
| Ts / latency | 0.15 s / 0.135 s |
| Setpoint | 90 deg (output shaft) at t = 0.2 s |
| Load step | 0 N*m at the output, t = 3 s |
| Output limit | +/-180 rpm command (output shaft) |
| Quantisation | 1 |
| Duration | 5 s |
| MATLAB | 26.1.0.3346908 (R2026a) Update 5 |
| Git | e5dcf90 (dirty: 1) |

## Metrics

| Metric | Value |
|---|---|
| Verdict | STEADY, OFFSET |
| Rise time 10-90 % | NaN s |
| Overshoot | 0.0 % |
| Settling (band 1.8) | NaN s |
| Steady-state error | 63 (70.00 %) |
| Peak control | 90 |
| Time saturated | 0 % |
| IAE | 313 |
| Worst deviation after load | NaN |
| Final error under load | NaN |

NaN means "not applicable" or "did not happen in the window".
