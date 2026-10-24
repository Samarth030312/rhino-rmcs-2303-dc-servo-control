# SIM-W4-SIM-20261009-135938-2

**Data class: SIMULATION.** MODEL output. Not measured. Plant parameters are ESTIMATED unless marked otherwise.

| Setting | Value |
|---|---|
| Plant | bare |
| Loop | speed |
| Controller | P |
| Kp / Ki / Kd | 0.2 / 0 / 0 |
| Ts / latency | 0.01 s / 0 s |
| Setpoint | 100 rpm (output shaft) at t = 0.2 s |
| Load step | 0.5 N*m at the output, t = 3 s |
| Output limit | +/-12 V (armature) |
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
| Settling (band 2) | NaN s |
| Steady-state error | 25 (25.00 %) |
| Peak control | 12 |
| Time saturated | 0 % |
| IAE | 131 |
| Worst deviation after load | 31.4 |
| Final error under load | 30.3 |

NaN means "not applicable" or "did not happen in the window".
