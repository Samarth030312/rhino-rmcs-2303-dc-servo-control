# Experiments

Every experiment the app offers, by mission, generated from the code that defines them (`matlab/scripts/motor_experiment_catalog.m`). Each rig experiment is one or more runs; a run fixes the loop, the controller and its gains, the feedback path and the command limit, then plays a setpoint profile (time in s, setpoint in output rpm or output degrees, held between rows). In the app, choose the mission and the preset; RUN ON RIG plays it on the hardware, and every preset simulates on any plant and opens in [Simulink](SIMULINK.md).

**Predicted** is the identified rig model (`servolab.motor.rigModel`) running the run's own settings: rise time 10-90 %, overshoot, steady-state error (last 20 % of the step). **Measured** links to the rig's answer in the latest session report; every recorded run is in `data/` ([data](../data/README.md)).

| Mission | Question | Experiments |
|---|---|---|
| [M1 · Open loop](#m1--open-loop) | The drive closes its own speed loop; the Arduino only writes the command. | 3 |
| [M2 · Static map](#m2--static-map) | Hold each command for 3 s and read the steady speed: dead zone, gain and saturation of the actuator. | 1 |
| [M3 · Speed P](#m3--speed-p) | P alone leaves an error e = r / (1 + K Kp). | 1 |
| [M4 · Speed I](#m4--speed-i) | I alone removes the error. | 2 |
| [M5 · Speed PI](#m5--speed-pi) | PI designed for zeta 0.7 at wn 2 rad/s. | 3 |
| [M6 · Windup](#m6--windup) | The command is limited to 50 rpm and 80 rpm is asked. | 1 |
| [M7 · Position P](#m7--position-p) | The drive turns speed into angle (an integrator), so P alone reaches the target. | 3 |
| [M8 · Position I](#m8--position-i) | I alone on position: two integrators in the loop. | 1 |
| [M9 · Position PI](#m9--position-pi) | PI on position removes a load offset, at the price of overshoot and a slow tail. | 1 |
| [M10 · Armature](#m10--armature) | The bare motor driven by a voltage, from the datasheet: speed and current, PID, a load torque, more inertia. | 6 |
| [LAB · Free](#lab--free) | Any loop, any controller, any setpoint. | 6 |

## M1 · Open loop

The drive closes its own speed loop; the Arduino only writes the command. A 0 -> 60 rpm step shows the gain K and the drive's acceleration ramp.

### Open-loop step 0 -> 60 rpm: drive register and encoder

Identify K and tau; compare the drive register (~10 ms window) with encoder counts over Ts.

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | speed | open loop | drive register | - | `[0 0;1 60;7 0]` | 10 | 0.80 | 0.0 | 0.00 |
| 2 | speed | open loop | encoder speed | - | `[0 0;1 60;7 0]` | 10 | 0.90 | 0.0 | 0.00 |

Measured: [latest session report](../results/reports/dc_motor/2026-10-25/REPORT.md#open-loop-step-0---60-rpm).

### Open-loop speed steps, 20 to 120 rpm

Identify the drive + motor: ramp rate, settling, steady speed at 20...120 rpm.

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | speed | open loop | drive register | - | `[0 20;3 40;6 80;9 120;12 80;15 40;18 0]` | 20 | 0.20 | 0.0 | 1.54 |

### Open-loop reversal, +30 to -30 rpm

Positive command must give positive speed; reversal time through zero.

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | speed | open loop | drive register | - | `[0 30;5 -30;10 0]` | 12 | 0.40 | 7.7 | -2.30 |

## M2 · Static map

Hold each command for 3 s and read the steady speed: dead zone, gain and saturation of the actuator.

### Static map: steady speed against command, both directions

Steady speed at commands 1...150 rpm, both directions, encoder feedback: dead zone and saturation.

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | speed | open loop | encoder speed | - | `[0 0;2 1;5 2;8 3;11 5;14 8;17 12;20 20;23 40;26 60;29 90;32 120;35 150;38 0]` | 41 | 0.10 | 3.8 | 0.00 |
| 2 | speed | open loop | encoder speed | - | `[0 0;2 -1;5 -2;8 -3;11 -5;14 -8;17 -12;20 -20;23 -40;26 -60;29 -90;32 -120;35 -150;38 0]` | 41 | 0.10 | 3.8 | 0.00 |

Measured: [latest session report](../results/reports/dc_motor/2026-10-25/REPORT.md#static-map-steady-speed-against-command).

## M3 · Speed P

P alone leaves an error e = r / (1 + K Kp). Raise Kp: the error shrinks, then the slow loop rings.

### Speed P gain sweep (Kp 0.2 / 0.5 / 0.8)

P alone leaves e_ss = r/(1+Kp); measure it for three gains.

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | speed | P, Kp 0.2 | drive register | - | `[0 60]` | 8 | - | 0.0 | 50.77 |
| 2 | speed | P, Kp 0.5 | drive register | - | `[0 60]` | 8 | - | 0.0 | 39.91 |
| 3 | speed | P, Kp 0.8 | drive register | - | `[0 60]` | 8 | - | 0.0 | 32.31 |

## M4 · Speed I

I alone removes the error. More Ki, less damping: zeta = 1 / (2 sqrt(tau K Ki)).

### Speed I only, Ki sweep 0.5 / 1 / 2 / 4

Theory: zeta = 1 / (2 sqrt(tau K Ki)); with tau 0.72 s: 0.83 / 0.59 / 0.42 / 0.29. More Ki -> less damping.

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | speed | I, Ki 0.5 | encoder speed | - | `[0 30]` | 10 | 4.10 | 0.0 | 0.27 |
| 2 | speed | I, Ki 1 | encoder speed | - | `[0 30]` | 10 | 1.90 | 0.0 | 0.00 |
| 3 | speed | I, Ki 2 | encoder speed | - | `[0 30]` | 10 | 0.60 | 0.0 | 0.00 |
| 4 | speed | I, Ki 4 | encoder speed | - | `[0 30]` | 10 | 0.50 | 55.0 | 0.00 |

Measured: [latest session report](../results/reports/dc_motor/2026-10-25/REPORT.md#speed-i-only-damping-against-ki).

### Speed I only (Ki 1.0)

Integral action removes the error, more slowly than PI.

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | speed | I, Ki 1 | drive register | - | `[0 60;8 30]` | 16 | 1.70 | 0.0 | 0.00 |

## M5 · Speed PI

PI designed for zeta 0.7 at wn 2 rad/s. Compare theory, the identified model and the rig.

### Speed PI designed for zeta 0.7 on a first-order model (Kp 1.0, Ki 2.9)

Designed on a first-order model (K 1, tau 0.72 s, wn 2 rad/s): 4.6 % overshoot on paper. The prediction below adds the Modbus delay and the drive ramp.

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | speed | PI, Kp 1 Ki 2.9 | encoder speed | - | `[0 30;8 40;16 30]` | 22 | 0.50 | 25.8 | 0.07 |

Measured: [latest session report](../results/reports/dc_motor/2026-10-25/REPORT.md#speed-pi-designed-for-zeta-07-kp-10-ki-29).

### Speed PI step to 60 rpm (Kp 0.3, Ki 1.5)

PI: fast reaction and zero steady-state error.

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | speed | PI, Kp 0.3 Ki 1.5 | drive register | - | `[0 60]` | 10 | 0.80 | 0.0 | 0.01 |

### Speed PI tracking setpoint changes (Kp 0.3, Ki 1.5)

Closed-loop speed control following setpoint changes.

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | speed | PI, Kp 0.3 Ki 1.5 | drive register | - | `[0 50;5 100;10 30;15 0]` | 20 | 0.60 | 1.5 | 0.16 |

## M6 · Windup

The command is limited to 50 rpm and 80 rpm is asked. Without anti-windup the integral keeps growing and the drop to 30 rpm comes late.

### Saturation and windup: speed PI with the command limited to 50 rpm

Setpoint 80 rpm cannot be reached: the command saturates at 50. With clamping anti-windup the speed follows the drop to 30 within about 0.5 s; with a plain integrator it does not within 6 s.

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | speed | PI, Kp 0.3 Ki 1.5 | encoder speed | 50 rpm | `[0 80;6 30]` | 12 | - | 0.0 | 30.00 |

Measured: [latest session report](../results/reports/dc_motor/2026-10-25/REPORT.md#saturation-and-windup-command-limited-to-50-rpm-80-asked-then-30).

## M7 · Position P

The drive turns speed into angle (an integrator), so P alone reaches the target. How close, for small moves?

### Position P final error on 10 deg moves (Kp 0.1 / 0.3 / 1.0)

Small moves: near the target the command is only a few rpm. Does the motor stop short?

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | position | P, Kp 0.1 | encoder angle | - | `[0 10]` | 8 | 3.30 | 0.0 | 0.08 |
| 2 | position | P, Kp 0.3 | encoder angle | - | `[0 10]` | 6 | 0.60 | 0.4 | -0.00 |
| 3 | position | P, Kp 1 | encoder angle | - | `[0 10]` | 6 | 0.15 | 84.8 | -0.00 |

Measured: [latest session report](../results/reports/dc_motor/2026-10-25/REPORT.md#position-p-final-error-of-10-deg-moves).

### Position P gain sweep, 90 deg (Kp 0.2 / 0.3 / 0.5)

Rise time and overshoot versus Kp for a 90 deg step.

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | position | P, Kp 0.2 | encoder angle | - | `[0 90]` | 7 | 1.35 | 0.0 | 0.00 |
| 2 | position | P, Kp 0.3 | encoder angle | - | `[0 90]` | 7 | 0.75 | 0.0 | 0.00 |
| 3 | position | P, Kp 0.5 | encoder angle | - | `[0 90]` | 7 | 0.45 | 33.8 | 0.00 |

### Position P moves: 90, -90, 360 deg (Kp 0.3)

Closed-loop position control; zero steady-state error expected (plant integrates).

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | position | P, Kp 0.3 | encoder angle | - | `[0 90;6 -90;12 360;20 0]` | 26 | 0.75 | 0.0 | 0.00 |

## M8 · Position I

I alone on position: two integrators in the loop. It oscillates around the target.

### Position I only (Ki 0.1)

Two integrators in the loop: the angle oscillates around the target.

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | position | I, Ki 0.1 | encoder angle | - | `[0 45]` | 12 | 1.20 | 150.3 | -30.66 |

## M9 · Position PI

PI on position removes a load offset, at the price of overshoot and a slow tail.

### Position PI (Kp 0.3, Ki 0.03)

PI on position: the integrator adds overshoot and a slow tail; without a load there is no offset for it to remove.

| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%) | e_ss |
|---:|---|---|---|---:|---|---:|---:|---:|---:|
| 1 | position | PI, Kp 0.3 Ki 0.03 | encoder angle | - | `[0 90]` | 12 | 0.60 | 7.0 | -2.56 |

## M10 · Armature

The bare motor driven by a voltage, from the datasheet: speed and current, PID, a load torque, more inertia. Simulation; on the rig the drive closes this loop.

| Preset | Plant | Loop | Controller | Profile | s | Load | Predicted rise (s) | overshoot (%) | e_ss |
|---|---|---|---|---|---:|---|---:|---:|---:|
| open loop: voltage step (speed and current) | bare motor | speed | open loop | `[0 0;0.1 90]` | 1 | - | 0.10 | 0.0 | 0.00 |
| speed PID | bare motor | speed | PID, Kp 0.05 Ki 1 Kd 0.0002 | `[0 0;0.1 100]` | 1.5 | - | 0.13 | 0.4 | 0.01 |
| speed PI, load torque step at 1 s | bare motor | speed | PI, Kp 0.05 Ki 1 | `[0 0;0.1 100]` | 2 | 1 N·m at 1 s | 0.12 | 0.4 | 0.00 |
| speed PI, inertia x1.5 | bare motor | speed | PI, Kp 0.05 Ki 1 | `[0 0;0.1 100]` | 1.5 | inertia ×1.5 | 0.12 | 1.5 | 0.01 |
| position PID | bare motor | position | PID, Kp 0.3 Ki 0.5 Kd 0.01 | `[0 0;0.1 90]` | 2 | - | 0.11 | 4.2 | -0.33 |
| position PID, load torque step at 1.5 s | bare motor | position | PID, Kp 0.3 Ki 0.5 Kd 0.01 | `[0 0;0.1 90]` | 3 | 1 N·m at 1.5 s | 0.11 | 4.2 | 1.24 |

## LAB · Free

Any loop, any controller, any setpoint. On the rig the setpoint changes live while it runs.

| Preset | Plant | Loop | Controller | Profile | s | Load | Predicted rise (s) | overshoot (%) | e_ss |
|---|---|---|---|---|---:|---|---:|---:|---:|
| speed PI, 60 rpm | rig, identified | speed | PI, Kp 0.3 Ki 1.5 | `[0 60]` | 10 | - | 0.80 | 0.0 | 0.01 |
| speed P, Kp 0.5 | rig, identified | speed | P, Kp 0.5 | `[0 60]` | 8 | - | - | 0.0 | 39.91 |
| speed open loop, 40 rpm | rig, identified | speed | open loop | `[0 40]` | 8 | - | 0.60 | 3.8 | -1.54 |
| position P, 90 deg | rig, identified | position | P, Kp 0.3 | `[0 90]` | 8 | - | 0.75 | 0.0 | 0.00 |
| position PI, 90 deg | rig, identified | position | PI, Kp 0.3 Ki 0.03 | `[0 90]` | 12 | - | 0.60 | 7.0 | -2.56 |
| position P, 1 N*m load at 3 s (drive physics) | rig, drive physics | position | P, Kp 0.3 | `[0 90]` | 8 | 1 N·m at 3 s | 0.60 | 0.0 | 0.00 |

