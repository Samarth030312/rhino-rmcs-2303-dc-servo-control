# SIM-W4-SIM-20261009-135938-4

**Data class: SIMULATION.** MODEL output. Not measured. Plant parameters are ESTIMATED unless marked otherwise.

| Setting | Value |
|---|---|
| Plant | bare |
| Loop | position |
| Controller | P |
| Kp / Ki / Kd | 0.3 / 0 / 0 |
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
| Rise time 10-90 % | 0.088 s |
| Overshoot | 18.3 % |
| Settling (band 1.8) | 0.38 s |
| Steady-state error | 0.0339 (0.04 %) |
| Peak control | 12 |
| Time saturated | 2 % |
| IAE | 18.1 |
| Worst deviation after load | 5.91 |
| Final error under load | 4.68 |

NaN means "not applicable" or "did not happen in the window".
