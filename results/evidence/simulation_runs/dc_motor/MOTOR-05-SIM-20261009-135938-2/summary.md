# MOTOR-05-SIM-20261009-135938-2

**Data class: SIMULATION.** MODEL output. Not measured. Plant parameters are ESTIMATED unless marked otherwise.

| Setting | Value |
|---|---|
| Plant | rig |
| Loop | position |
| Controller | P |
| Kp / Ki / Kd | 0.3 / 0 / 0 |
| Ts / latency | 0.15 s / 0.135 s |
| Setpoint | 90 deg (output shaft) at t = 0.2 s |
| Load step | 1 N*m at the output, t = 3 s |
| Output limit | +/-180 rpm command (output shaft) |
| Quantisation | 1 |
| Duration | 5 s |
| MATLAB | 26.1.0.3346908 (R2026a) Update 5 |
| Git | e5dcf90 (dirty: 1) |

## Metrics

| Metric | Value |
|---|---|
| Verdict | SETTLED |
| Rise time 10-90 % | 0.593 s |
| Overshoot | 0.0 % |
| Settling (band 1.8) | 1.26 s |
| Steady-state error | 0.0181 (0.02 %) |
| Peak control | 27 |
| Time saturated | 0 % |
| IAE | 65.5 |
| Worst deviation after load | 13.9 |
| Final error under load | 0.0247 |

NaN means "not applicable" or "did not happen in the window".
