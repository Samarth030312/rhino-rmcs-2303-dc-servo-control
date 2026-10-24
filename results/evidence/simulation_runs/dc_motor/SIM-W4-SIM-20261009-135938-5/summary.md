# SIM-W4-SIM-20261009-135938-5

**Data class: SIMULATION.** MODEL output. Not measured. Plant parameters are ESTIMATED unless marked otherwise.

| Setting | Value |
|---|---|
| Plant | bare |
| Loop | position |
| Controller | PID |
| Kp / Ki / Kd | 0.3 / 0.5 / 0.01 |
| Ts / latency | 0.01 s / 0 s |
| Setpoint | 90 deg (output shaft) at t = 0.2 s |
| Load step | 0.5 N*m at the output, t = 3 s |
| Output limit | +/-12 V (armature) |
| Quantisation | 1 |
| Duration | 5 s |
| MATLAB | 26.1.0.3346908 (R2026a) Update 5 |
| Git | e5dcf90 (dirty: 1) |

## Metrics

| Metric | Value |
|---|---|
| Verdict | SETTLED |
| Rise time 10-90 % | 0.111 s |
| Overshoot | 3.8 % |
| Settling (band 1.8) | 0.75 s |
| Steady-state error | -0.0453 (-0.05 %) |
| Peak control | 12 |
| Time saturated | 1 % |
| IAE | 12.6 |
| Worst deviation after load | 4.12 |
| Final error under load | 0.183 |

NaN means "not applicable" or "did not happen in the window".
