# MOTOR-07-SIM-20261009-135008

**Data class: SIMULATION.** MODEL output. Not measured. Plant parameters are ESTIMATED unless marked otherwise.

| Setting | Value |
|---|---|
| Plant | rig |
| Loop | speed |
| Controller | PI |
| Kp / Ki / Kd | 0.3 / 2.5 / 0 |
| Ts / latency | 0.1 s / 0.07 s |
| Setpoint | 100 rpm (output shaft) at t = 0.2 s |
| Load step | 0 N*m at the output, t = 3 s |
| Output limit | +/-180 rpm command (output shaft) |
| Quantisation | 1 |
| Duration | 5 s |
| MATLAB | 26.1.0.3346908 (R2026a) Update 5 |
| Git | e5dcf90 (dirty: 1) |

## Metrics

| Metric | Value |
|---|---|
| Verdict | SETTLED |
| Rise time 10-90 % | 0.387 s |
| Overshoot | 2.0 % |
| Settling (band 2) | 1.09 s |
| Steady-state error | 0.00219 (0.00 %) |
| Peak control | 102 |
| Time saturated | 0 % |
| IAE | 35.4 |
| Worst deviation after load | NaN |
| Final error under load | NaN |

NaN means "not applicable" or "did not happen in the window".
