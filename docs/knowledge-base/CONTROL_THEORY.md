# Control Theory — DC motor

The equations the simulation implements and the experiments test. Each section names the
code that implements it and the test that checks it. Temperature-control theory is not
written yet.

Notation: subscript _m = base motor (before the gearbox), _out = output shaft.
N = 100 gear ratio. e = r − y (setpoint minus measurement).

---

## 1. Armature-controlled DC motor (bare motor, course week 4)

$$L\frac{di}{dt} = V - R\,i - K_e\,\omega_m \qquad J\frac{d\omega_m}{dt} = K_t\,i - b\,\omega_m - \frac{T_{L,out}}{N\,\eta}$$

$$\omega_{out} = \omega_m / N \qquad \theta_{out} = \theta_m / N$$

In SI units K_t = K_e. Parameter values and their status: HARDWARE_REFERENCE §1.5 (all ESTIMATED).

Transfer function voltage → base speed:

$$\frac{\Omega_m(s)}{V(s)} = \frac{K_t}{(Ls + R)(Js + b) + K_t K_e}$$

Steady-state gain K_ss = K_t / (R b + K_t K_e) = 157 rad/s per V (base) = **15.0 output rpm per V**.
Time constants with the estimates: τ_e = L/R ≈ 0.31 ms, τ_m ≈ R J / (K_t K_e) ≈ 49 ms.

Load sensitivity (open loop): Δω_m = −T_L,m · R / (R b + K_t K_e). For 0.5 N·m at the output
(0.005 N·m at the motor) that is −221 rad/s base = **−21 output rpm**. Simulation: −21.1 rpm.

- Code: `servolab.motor.simulate` (exact ZOH discretisation, `expm`), Simulink `servo_armature.slx`.
- Tests: `testBareMotorMatchesOde45`, `testBareOpenLoopReachesSetpoint`, `test_simulink_crosscheck`
  (Simulink vs MATLAB agree to < 10⁻¹⁰ relative).

## 2. The lab rig: RMCS-2303 in speed mode (Mode 1)

The drive closes a speed loop on the encoder. Its internals are undocumented, so the model is
a **structural estimate**: acceleration ramp (register 12) → PI speed loop of bandwidth
ω_c ≈ 40 rad/s → ideal current loop clipped at ±3 A and at the supply headroom
(±V_s − K_e ω)/R → the mechanics of §1.

Seen from the Arduino, the drive + motor is approximately

$$\omega_{out}(s) \approx \frac{1}{\tau_d s + 1}\,u(s), \quad \tau_d \approx 1/\omega_c$$

plus the ramp (a rate limit, nonlinear) and the Modbus delay. MOTOR-02 identifies τ_d, the
ramp rate and the delay from a speed step.

Load: the drive's own integral action rejects a constant load until the current limit
(1.7 N·m at the output, ESTIMATED). So the outer loop barely sees moderate loads.

## 3. Sampling, delay and quantisation

| Quantity | Value | Source |
|---|---|---|
| Outer-loop sample time, speed | 0.10 s | ESTIMATED from 9600-baud Modbus traffic (ED-M1) |
| Outer-loop sample time, position | 0.15 s | ESTIMATED |
| Command latency after the sample | 0.07 / 0.11 s | MEASURED 2026-10-25: firmware sample-to-command 70.5 / 74.8 ms (speed, drive / encoder) and 78 ms (position); position fitted to the Kp 1.0 oscillation (0.11 s; the extra ~30 ms is inside the drive, UNVERIFIED). Was 0.135 s, a paper estimate |
| Position resolution | 360/5200 = 0.0692° | VERIFIED_FROM_MANUAL |
| Speed resolution (drive register) | 1 base rpm = 0.01 output rpm | VERIFIED_FROM_MANUAL (register units) |
| Speed from counts at Ts (bare motor) | 360/5200/Ts/6 rpm per count → 1.15 rpm at 10 ms | Derived |

The controller is discrete; ZOH holds its output for Ts.

## 4. Discrete P / I / PI / PID (what the Arduino runs)

$$u_k = K_p e_k + I_k + D_k$$
$$I_k = I_{k-1} + K_i T_s e_k \quad\text{(backward Euler)}$$
$$D_k = \frac{T_f D_{k-1} + K_d (e_k - e_{k-1})}{T_f + T_s}\quad\text{(filtered, backward Euler)}$$

Output clipped to ±u_max. **Anti-windup by clamping**: when saturated and the error pushes
further into saturation, the integrator advances only until the output reaches the limit.
This is the same law as Simulink's Discrete PID Controller with backward-Euler integrator,
backward-Euler filter, N = 1/T_f and clamping.

- Code: `servolab.motor.pidStep`. Tests: `testPidMatchesHandCalculation`, `testPidAntiWindup`.
- A test caught a real bug here on 2026-10-09: the first version held the integrator at its
  previous value whenever one step would overshoot the limit, so pure-I control with a large
  error never moved. Fixed to integrate up to the limit.

## 5. What each controller does — predictions to test

### Speed loop around the drive (rig)

Plant ≈ unity gain with lag. With P only, `u = Kp e`, steady state `y = u`, so

$$e_{ss} = \frac{r}{1 + K_p}$$

Sampled with an effective one-step lag, `y_{k+1} ≈ K_p (r − y_k)`: pole at −K_p, so the loop
**oscillates as K_p → 1 and is unstable beyond**. P alone therefore cannot get below ~50 %
error. Simulation: K_p = 0.2/0.5/0.8 gives 83.3/66.7/55.6 % (theory exactly), K_p = 1.2 oscillates.
Test: `testRigSpeedPSteadyStateError`, `testRigSpeedPOscillatesAboveUnity`.
Figure: `results/figures/dc_motor/rig_speed_P_steady_state_error.png`.

I only, `u_k = u_{k−1} + K_i T_s e_k`: zero steady-state error; discrete pole condition
K_i T_s < 1 for stability (with a pure one-step lag), well damped near K_i T_s ≈ 0.25.

PI: P term speeds the first response, I removes the remainder.

### Speed loop on the bare motor

Loop gain K = K_p · K_ss: e_ss = r / (1 + K_p K_ss); a load adds an error that only integral
action removes. Test: `testBareSpeedPSteadyStateError`.

### Position loop around the drive (rig)

The drive turns a speed command into angle, so the plant is an integrator (6 deg/s per rpm):

$$\theta_{k+1} = \theta_k + 6 T_s u_k \;\Rightarrow\; \text{P: pole at } 1 - 6 T_s K_p$$

- P alone gives **zero steady-state error to a step** (type-1 loop). Stable while
  6 T_s K_p < 2 (K_p < 2.2 rpm/deg at 0.15 s); latency and the ramp lower that in practice.
- I alone puts two integrators in the loop: oscillation. Simulation agrees (OSCILLATING).
- PI on position adds overshoot and a slow tail; it buys little on the rig because the drive's
  own speed loop already rejects constant load.

### Position loop on the bare motor

P alone leaves a position offset under constant load (the motor needs steady voltage to hold
torque, which needs a steady error); I removes it; D damps the overshoot.

## 6. Metrics (`servolab.motor.metrics`)

Rise time 10–90 %, overshoot, settling time in a band of max(2 % of step, feedback
resolution), steady-state error (mean over the last 10 % of the step window), peak control,
fraction of time saturated, IAE, worst deviation and final error after a load step, and a
verdict: SETTLED / STEADY, OFFSET / NOT SETTLED / OSCILLATING / DIVERGED.

## 7. Model validation plan (simulation vs hardware, MOTOR-08)

1. MOTOR-02 open-loop speed steps (drive only) at 30, 90, 150 rpm → fit τ_d, ramp rate, delay.
2. Replace ESTIMATED values in `params.m`, set their status to MEASURED with the run ID.
3. Re-run the same presets on hardware and in simulation; overlay; report rise, overshoot,
   e_ss differences. Disagreement is a finding, not something to tune away.

## References

SRC-002, SRC-003, SRC-006 (CTMS motor speed/position modelling), SRC-010 (Simulink PID block).
