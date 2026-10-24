# MOTOR-07-SIM-20261009-135938

**Data class: SIMULATION.** MODEL output. Not measured. Plant parameters are ESTIMATED unless marked otherwise.

| Setting | Value |
|---|---|
| Plant | rig |
| Loop | position |
| Controller | PI |
| Kp / Ki / Kd | 0.3 / 0.03 / 0 |
| Ts / latency | 0.15 s / 0.135 s |
| Setpoint | 90 deg (output shaft) at t = 0.2 s |
| Load step | 0 N*m at the output, t = 3 s |
| Output limit | +/-180 rpm command (output shaft) |
| Quantisation | 1 |
| Duration | 8 s |
| MATLAB | 26.1.0.3346908 (R2026a) Update 5 |
| Git | e5dcf90 (dirty: 1) |

## Metrics

| Metric | Value |
|---|---|
| Verdict | STEADY, OFFSET |
| Rise time 10-90 % | 0.529 s |
| Overshoot | 5.6 % |
| Settling (band 1.8) | NaN s |
| Steady-state error | -2.92 (-3.24 %) |
| Peak control | 27.8 |
| Time saturated | 0 % |
| IAE | 81.1 |
| Worst deviation after load | NaN |
| Final error under load | NaN |

NaN means "not applicable" or "did not happen in the window".
