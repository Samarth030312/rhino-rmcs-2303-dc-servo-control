# First principles: the motor, the drive, the loop

From the datasheet to the controller, every step with its numbers. Code:
`servolab.motor.physics` (the bare motor), `servolab.motor.identifiedSim` (the rig),
`servolab.motor.pidStep` (the controller, identical to the firmware's). Status of each
number: [hardware reference](hardware/HARDWARE_REFERENCE.md), `servolab.motor.params`.

## 1. The bare motor (mission M10)

A permanent-magnet DC motor, armature resistance R, inductance L, back-EMF and torque
constant Ke = Kt (SI units), rotor inertia J, viscous friction b, gear ratio N:

```
L di/dt = V − R i − Ke ω            (armature, ω at the motor shaft)
J dω/dt = Kt i − b ω − T_load/(N η)  (rotor)

ω(s)/V(s) = Kt / ((J s + b)(L s + R) + Kt Ke)
```

The datasheet gives no R, Kt or b directly. Three of its numbers give them:

| Datasheet (RMCS-5032) | | Derived | |
|---|---|---|---|
| rated voltage V_nom | 12 V | R = V_nom / I_stall | **1.60 Ω** |
| no-load speed (output) | 180 rpm → ω_nl = 1885 rad/s at the motor | Ke = Kt = (V_nom − I_nl R) / ω_nl | **5.69 mV·s/rad** |
| no-load current I_nl | 0.8 A | b = Kt I_nl / ω_nl | **2.41 µN·m·s** |
| "load current up to" I_stall | 7.5 A (taken as stall: ESTIMATED) | τe = L / R (L = 0.5 mH, ESTIMATED) | **0.31 ms** |
| gear ratio N | 100 | τm = J R / (Kt Ke + R b) (J = 1·10⁻⁶ kg·m², ESTIMATED) | **44 ms** |

τe ≪ τm, so the motor is close to first order:
ω_out/V ≈ 15.0 rpm/V / (0.044 s + 1). **Free speed at the battery's 11.1 V: 166.5 rpm.**
The rig's full-voltage runaways measured 165.9–175.3 rpm, median 166.8
([analysis](../results/reports/dc_motor/2026-10-24/ANALYSIS.md), section 2).

Torque available at the output: Kt · I · N · η. The current is limited first by the
**drive** (3 A per phase, manual) before the motor's stall (11.1 V / 1.6 Ω = 6.9 A) and the
battery (2C × 4.4 Ah = 8.8 A): **1.7 N·m**, well below the datasheet's 5.9 N·m stall torque.

Battery: a 3S Li-ion pack runs from 12.6 V (full) through 11.1 V (nominal) to about 9 V; free
speed follows from 189 to 135 rpm. The physics panel's **battery charge** field sets the
voltage from a typical Li-ion curve (ESTIMATED: the pack's own curve is not published).

## 2. Through the drive: a speed source with a ramp

The RMCS-2303 closes its own speed loop on the encoder. Seen from its Modbus speed register,
the motor is no longer V → ω: it is **command → speed**. On the rig (open-loop steps,
2026-10-11, refitted 2026-10-24):

- gain **1.000** (1.002): the drive delivers the commanded speed;
- the speed rises along a **ramp of 53.4 rpm/s** (53.9), the drive's acceleration register
  (5000 base rpm/s ≈ 50 output rpm/s): a 0 → 60 rpm step takes 1.1 s at constant slope;
- nothing slower than the 100 ms sampling can see: the fitted lag τ and dead time θ are zero.

So the identified plant is **K = 1, a rate limit, and the measurement and command timing**.
A first-order K/(τs + 1) fitted to the same step (τ ≈ 0.72 s, the textbook model of this rig) has the
same final value but the wrong shape: an exponential where the rig is a straight line.

## 3. The sampled outer loop

The Arduino reads the speed (or angle), computes the PID law and writes the command, every
Ts = 0.1 s (0.15 s for position). Measured on the rig with the firmware's own clock:
the command lands **70.5 ms** (drive register), **74.8 ms** (encoder) or **78 ms** (position)
after the sample is taken; the position loop behaves as if it were **0.11 s** (section 6).
The law, in both the firmware and MATLAB:

```
d  = (Tf·d⁻ + Kd (e − e⁻)) / (Tf + Ts)          derivative, filtered
I  = I⁻ + Ki·Ts·e                               backward Euler
u  = clamp(Kp e + I + d, ±uMax)
if clamped and pushing further: I is held        clamping anti-windup
```

Measurement resolution: the drive's speed register counts encoder lines in a ~10 ms window,
so it moves in steps of **4.6 rpm** at the output. Encoder counts over Ts give
360/5200 = **0.069°** per count and 60/(5200 Ts) = **0.115 rpm** at Ts = 0.1 s.

## 4. Speed control

With the drive as a unit-gain speed source, the outer plant is G ≈ 1 (plus ramp and delay):

- **P:** u = Kp e, y = u at steady state, so e_ss = r / (1 + Kp). At r = 60 rpm:
  Kp 0.2 → 50 rpm, 0.5 → 40 rpm, 0.8 → 33.3 rpm. The rig: 49.98, 40.29, 33.40 rpm.
- **I:** y/r = Ki / (s + Ki) for a pure unit gain: first order, no overshoot, any Ki. With the
  first-order plant (τ = 0.72 s): ζ = 1 / (2√(τ K Ki)), so ζ falls as Ki rises
  (0.83, 0.59, 0.42, 0.29 for Ki 0.5, 1, 2, 4). The rig overshoots 1.5, 2.7, 3.5 and 64 %:
  little until the **delay** (not τ) runs out of phase at Ki 4.
- **PI designed for ζ 0.7, ωn 2 rad/s** on K/(τs + 1): Kp = (2ζωnτ − 1)/K = 1.0,
  Ki = ωn²τ/K = 2.9, predicted overshoot 4.6 %. The rig: **31 %** and a ±6 rpm limit cycle.
  The design assumed a lag the rig does not have and ignored the delay it does have; Kp = 1.0
  around a unit-gain plant with ~0.12 s of effective delay leaves little phase margin. The
  identified model, which has the delay, predicts 26 % and the same cycle.

## 5. Saturation and windup (M6)

Limit the command to 50 rpm and ask for 80: the integrator keeps growing while the output is
pinned. With clamping (the firmware's), the integral is held while the output is saturated
and pushing further, so when the setpoint drops to 30 rpm the loop leaves the limit at once:
**0.5 s** to within 5 % on the rig. The same model with a plain integrator needs to unwind
what it accumulated and does not get back in the remaining 6 s.

## 6. Position control

The drive turns a speed command into motion; the angle is its integral:
dθ/dt = 6 · u (θ in degrees, u in rpm). With P control and an effective loop delay T:

```
L(s) = 6 Kp e^(−sT) / s      crossover ωc = 6 Kp,  phase margin PM = 90° − ωc T (in degrees)
```

- **Final error:** the plant integrates, so P alone reaches the target: within 0.06–0.4° of
  10° moves on the rig (a few encoder counts), with no dead zone to stop short in.
- **Stability:** with T ≈ 0.11 s + Ts/2 = 0.185 s, PM = 90° − 6 · Kp · 0.185 · 57.3°:
  Kp 0.3 → 71°, Kp 1.0 → 26°, and PM = 0 at Kp ≈ 1.4. On the rig Kp 1.0 overshoots
  73 ± 10 % and rings for seconds; Kp 0.3 overshoots 1–3 %.
- **I alone** puts a second integrator in the loop: it oscillates around the target (M8).

The Kp 1.0 runs sit so close to the edge that their oscillation measures T: the model's
position latency was refitted from them (0.135 s on paper → 0.11 s), which halved the
model's error on every position run ([analysis](../results/reports/dc_motor/2026-10-24/ANALYSIS.md), section 3).

## 7. Why the rig is the model you should trust

The bare-motor physics (section 1) is right about free speed, torque and current, and it is
the right model for M10. It is the wrong model for M1–M9: the drive's loop sits in between.
The identified model (sections 2–3) has four numbers, all measured on the rig, and predicts
runs it was never fitted to within a median 5.5 % of the setpoint. When your rig differs
(another battery, a load on the shaft), identify it from one of its own open-loop runs.
