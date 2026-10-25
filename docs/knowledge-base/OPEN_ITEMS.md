# Open Items and Conflicts

An item closes only with evidence (a measurement, an inspection photo, or a document
quote). Record how it was closed.

## Conflicts between sources (DC motor)

| ID | Conflict | Effect | Resolution path | Status |
|---|---|---|---|---|
| C-M1 | The lab handout (SRC-001 week 5) lists a generic DC motor, 6/9 V battery, diode and MOSFET. The lab hardware is an RMCS-2303 servo drive + RMCS-5032 12 V motor. | Firmware and control architecture differ from the course text. | Follow the actual hardware; reproduce the course's generic set-up in simulation ("Bare DC motor" plant). ED-M1. | DECIDED (pending approval) |
| C-M2 | RMCS-5032 title "200RPM" vs table "180RPM". | Max output speed. | Table value 180 is consistent with 18000/100. Confirm in MOTOR-02. | OPEN |
| C-M3 | Encoder A/B colours: drive manual p.5 (generic motor) red=ENC_B; RMCS-5032 sheet red=EncA. | Wiring per the drive manual crossed A/B: runaway on 2026-10-11 (incident report). | **Resolved: follow the RMCS-5032 sheet — red→pin 11, orange→pin 10.** Confirm on the rig after re-wiring. | RESOLVED (doc); re-wire + confirm PENDING |
| C-M4 | Drive pin 11 labelled "Hall V" (p.4) vs "Hall U" (p.5); p.5 tables placed side by side look like a pin mapping but are not. | Wiring error risk. | Wire by function and board silkscreen; photograph. | OPEN |
| C-M5 | Motor max current 7.5 A vs drive 3 A peak. | Stall torque 60 kgf·cm is not reachable; max ≈ 17 kgf·cm (ESTIMATED). | Note in report; model current limit. | NOTED |
| C-M6 | Drive accepts 10–30 V; motor is 12 V. | Over-speed if a 24 V supply is used and a high speed is commanded. | Use 12 V or clamp commanded base speed ≤ 18000 rpm. | NOT APPLICABLE with the 3S battery (12.6 V max) |
| C-M7 | Drive current: manual "peak 3 A per phase" (SRC-002 p.4) vs the Robokits product page, "5A" in its title on 2026-10-25 (SRC-018; an earlier version of the page said "10 A") | Torque limit in the model (1.7 N·m at 3 A, 2.9 N·m at 5 A); fuse rating | Model uses 3 A; fuse the supply at 5 A regardless; a stall test with a current meter would settle it | OPEN |

## Unresolved facts (DC motor)

| ID | Fact needed | Why it matters | How to resolve | Status |
|---|---|---|---|---|
| OI-M1 | Lab power-supply voltage and current rating | C-M6; safety | Owner 2026-10-25: Pro-Range INR18650 Li-ion 3S2P, 11.1 V nominal (12.6 V full), 4400 mAh, 2C = 8.8 A, built-in BMS ([HARDWARE_REFERENCE §4](../hardware/HARDWARE_REFERENCE.md)). Still no power switch: keep the connector reachable | RESOLVED (switch: recommendation stands) |
| OI-M2 | Drive slave ID on the actual unit | Every Modbus frame | **Slave id 7** found by the firmware's scan (session log hw_session_20261011-120813.log). Jumper state still to photograph | **CLOSED 2026-10-11** |
| OI-M3 | UART framing | Communication | Vendor library RMCS2303drive v1.0 (SRC-012): 9600 baud, SoftwareSerial (8N1 only) | **CLOSED 2026-10-09** |
| OI-M4 | Register addressing on the wire | Every Modbus frame | Vendor library: documented numbers go on the wire as-is (2, 14, 24); FC 06 write / FC 03 read; LRC = two's complement; **position feedback = 2 registers from 20, low word first** (manual says 20/22) | **CLOSED 2026-10-09** |
| OI-M5 | Units of the acceleration register (12) | Speed ramp model | Step test in MOTOR-02 | **RESOLVED 2026-10-21**: register 5000 → fitted ramp 53.4 output rpm/s (= 5340 base rpm/s) on 4 open-loop runs: units are base rpm per second (fit: docs/FIRST_PRINCIPLES.md, section 2) |
| OI-M6 | Signedness of speed feedback (register 24) | Reverse speed reading | Run reverse in MOTOR-02 | OPEN |
| OI-M7 | Whether PPG / PIG / VFFG act in speed mode | ED-M1 option A | Vary gains in Mode 1 on hardware | OPEN |
| OI-M8 | Real Modbus cycle time on the Uno | Outer-loop Ts (ED-M1) | Timestamp a loop of reads in MOTOR-02 | **CLOSED 2026-10-23**: the firmware's micros() loop timer (DRIVE CHECK) reads 74.4–74.6 ms per 100 ms sample, max 74.7 ms, 0 overruns (`results/evidence/logs/hw_check_20261023-1*.log`) |
| OI-M9 | R, K_t, J, b of the base motor | All simulation results | MOTOR-02 identification (multimeter for R; speed step for τ) | OPEN — currently ESTIMATED |
| OI-M10 | Current LPR setting stored in the drive's EEPROM | rpm scaling ×25.7 if wrong | READ_PARAMETER at start of MOTOR-01 | OPEN |
| OI-M11 | Drive UART logic level vs Uno 5 V | Possible damage to drive RX | Measure TXD idle voltage; vendor confirms direct Uno wiring (p.29) | OPEN |
| OI-M12 | Full-speed reverse start at RUN: a speed run started from rest (previous run ended at 0 rpm, then STOP, no HOME) ran backwards at full voltage at enable, **12 of 12** times over 2026-10-11, -23 and -24; never when a HOME came first. (The slow STOP acknowledgements seen with it were the app saving the run, not the drive.) | Safety (the runaway guard caught every case within 0.2 s) | **Fixed in firmware e60d046 / f87b283**: HOME at every RUN, 150 ms settle before enable. On the rig 2026-10-24: **0 of 21** at-risk starts ran away; a 1-2 deg jerk at enable remains ([analysis](../../results/reports/dc_motor/2026-10-24/ANALYSIS.md)) | CLOSED 2026-10-24; cause inside the drive UNVERIFIED |
| OI-M13 | "Zap" at the end of an experiment (operator, 2026-10-25). The logs show most closed-loop experiments end with the motor still turning (9-60 rpm), and STOP cut motor power (0x0700) at that speed | Gearbox jolt, wear; alarming for students | Firmware soft stop: speed 0 on the drive's ramp, power off at rest (at most 4 s); ABORT is `STOP,1,NOW`. On the rig 2026-10-25: the drive's speed register reads 0 below 4.6 rpm, so the first version cut power at up to ~7 rpm (R0114); rest now also needs the encoder still (< 1 rpm, `1159183`). 81 runs that day, 79 soft stops, none cut early; from 60 rpm 1.2 s to rest (53 rpm/s ramp: 1.1 s). Logs `hw_session_20261025-*.log` | CLOSED 2026-10-25 |
| OI-M14 | Run stopped by the host watchdog (R0129): the app blocked for 1.1 s just after RUN (it simulated the run and redrew the window after sending RUN). Steady-state stalls up to 0.93 s with Simulink open, measured against the emulated rig | A 1 s watchdog trips on an ordinary laptop | The app does its set-up and full redraw before RUN; axes interactions are set at start-up; host watchdog 2 s (`886b32c`). Full campaign after: 27 of 27, longest stall 0.60 s | CLOSED 2026-10-25 |
| OI-M15 | False runaway stop (R0134): at the end of the static map the command steps -150 -> 0 rpm; the drive answers after ~0.15 s, so speed read 150.0, 148.4, 147.4 rpm, "too fast" for a 0 command | A correct run stopped as a runaway | "Too fast" is now judged against the command as the drive can follow it (falling at 50 rpm/s), `0305ac9`; a host test with 0.15 s drive dead time reproduces and guards it. Real runaways (reversed encoder, OI-M12) still trip at once | CLOSED 2026-10-25 |
| OI-M16 | Live plot showed a run only after as many frames as the previous run had (M8 after M7, 2026-10-25) | Display only: saved data complete (all runs since checked) | The run's start offset was taken before the link reset its table; removed. e2e: a longer run after a shorter one is drawn whole | CLOSED 2026-10-25 |
| OI-M17 | False first encoder-speed sample: 10-46 rpm with the motor at rest in 34 of 72 encoder-speed runs (R0200: 38 % "overshoot"). The drive zeroes its position count some time after HOME; the firmware took its reference count before | Wrong metrics for encoder-speed runs; a position loop could briefly see a stale angle | Firmware `8ea43d3`: wait (≤ 0.5 s) for the count to read near zero after HOME; first sample = 0, as in the models. Host test with a drive that resets 0.3 s late: old 46 rpm, new 0. Older runs corrected on reading (`loadHardwareRun`) | FIX READY; rig test pending (flash, run M1, M4, M7) |

## Environment

| ID | Item | Status |
|---|---|---|
| OI-E1 | Simulink installed (R2026a) and used by the models and their tests | CLOSED 2026-10-21 |
| OI-E2 | Arduino CLI / IDE | CLOSED 2026-10-09: CLI 1.5.1 (isolated) + IDE 2.3.10 |
| OI-E3 | OBS not installed; ffmpeg 6.x present | OPEN |
| OI-E4 | Windows and macOS: installer, toolchain, firmware build and MATLAB tests run in CI (`.github/workflows/ci.yml`); no rig session from those systems yet. A colleague's Windows PC showed no COM port on 2026-10-23 (CH340 driver suspected, not confirmed) | OPEN |
| OI-E5 | Manuals and course handouts are copyrighted ("may not be reproduced"); cited, kept locally, git-ignored | DECIDED |
