# MOTOR-05-SIM-20261009-135938

**Data class: SIMULATION.** MODEL output. Not measured. Plant parameters are ESTIMATED unless marked otherwise.

| Setting | Value |
|---|---|
| Plant | rig |
| Loop | position |
| Controller | P |
| Kp / Ki / Kd | 1.5 / 0 / 0 |
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
| Verdict | OSCILLATING |
| Rise time 10-90 % | 0.239 s |
| Overshoot | 442.5 % |
| Settling (band 1.8) | NaN s |
| Steady-state error | -75.9 (-84.36 %) |
| Peak control | 180 |
| Time saturated | 57 % |
| IAE | 849 |
| Worst deviation after load | NaN |
| Final error under load | NaN |

NaN means "not applicable" or "did not happen in the window".
