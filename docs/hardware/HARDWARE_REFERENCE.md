# Hardware Reference

Every value carries a status from `INDEX.md` and a source ID from `SOURCE_REGISTER.csv`.
Page numbers refer to the printed page numbers in the source document.

---

## 1. Motor — Rhino RMCS-5032 planetary geared quad-encoder DC servo motor

Source: **SRC-003** (`RMCS-5032_V1.pdf`, single page, LibreOffice export dated 2022-04-11).
The PDF is a scanned image; values were read off the rendered page.

### 1.1 Output-shaft (after gearbox) specifications

| Quantity | Value | Status | Notes |
|---|---|---|---|
| Motor type | Planetary geared DC motor | VERIFIED_FROM_MANUAL | |
| Operating voltage | 12 V DC | VERIFIED_FROM_MANUAL | |
| No-load speed at output shaft | **180 rpm** | VERIFIED_FROM_MANUAL | Title says "200RPM" — conflict **C-M2**; 18000/100 = 180 agrees with the table |
| Stall torque | 60 kgf·cm (5.88 N·m) | VERIFIED_FROM_MANUAL | Not reachable through the RMCS-2303's 3 A limit — **C-M5** |
| Rated torque | 15 kgf·cm (1.47 N·m) | VERIFIED_FROM_MANUAL | |
| Gear ratio | 1 : 100 | VERIFIED_FROM_MANUAL | |
| Counts per revolution at output shaft | **5200** | VERIFIED_FROM_MANUAL | = 52 × 100; 1 count = 0.0692° |
| Mass | 300 g | VERIFIED_FROM_MANUAL | |
| Output shaft | Ø6 mm, 12 mm long, M3 tapped | VERIFIED_FROM_MANUAL | Mechanical drawing |
| Gearbox Ø / motor can Ø | 32 mm / 30 mm | VERIFIED_FROM_MANUAL | Mechanical drawing |

### 1.2 Base-motor (before gearbox) specifications

| Quantity | Value | Status |
|---|---|---|
| Nominal voltage | 12 V | VERIFIED_FROM_MANUAL |
| No-load speed | 18000 rpm (1885 rad/s) | VERIFIED_FROM_MANUAL |
| Rated torque | 151 gf·cm (0.0148 N·m) | VERIFIED_FROM_MANUAL |
| No-load current | 0.8 A | VERIFIED_FROM_MANUAL |
| Load current | "up to 7.5 A (Max)" | VERIFIED_FROM_MANUAL — meaning (stall vs. peak) UNVERIFIED |

Rated torque check: 151 gf·cm × 100 = 15.1 kgf·cm, matching the output rating, so the
datasheet itself implies a gearbox efficiency close to 1. The model therefore uses
η = 1 (ASSUMED, consistent with the datasheet, physically optimistic).

### 1.3 Encoder

| Quantity | Value | Status |
|---|---|---|
| Type | Quadrature, 13-pole Hall | VERIFIED_FROM_MANUAL |
| Lines per base-motor revolution | **13** | VERIFIED_FROM_MANUAL |
| Counts per base-motor revolution | 13 × 4 = 52 | VERIFIED_FROM_MANUAL |
| Counts per output revolution | 52 × 100 = 5200 | VERIFIED_FROM_MANUAL |
| Supply | +5 V DC (from drive pin 9) | VERIFIED_FROM_MANUAL |
| Edge rate at 18000 rpm base | 52 × 300 = 15 600 counts/s | Derived |

### 1.4 Motor wire colours

| Wire | Motor sheet (SRC-003) | Drive manual p.5 (SRC-002) |
|---|---|---|
| Black | GND | GND |
| Brown | +5 V DC | VCC (5 V) |
| Red | **EncA** | **ENC_B** |
| Orange | **EncB** | **ENC_A** |
| Yellow | Motor− | M− |
| Green | Motor+ | M+ |

Conflict **C-M3**: the two documents swap A and B. The only consequence is the sign
of counting. Resolve by measurement in MOTOR-02 (command "forward", check that the
position count increases), not by choosing a document.

### 1.5 Derived / estimated electromechanical parameters (for simulation only)

**None of these is measured.** They exist so that the simulation has plausible
numbers before MOTOR-02 identifies the real ones. The canonical values live in
`matlab/+servolab/+motor/params.m`, which carries the same status labels.

| Symbol | Value | Status | Derivation |
|---|---|---|---|
| R (armature resistance) | 1.6 Ω | ESTIMATED | 12 V / 7.5 A, assuming 7.5 A is the stall current |
| K_e = K_t | 5.69 × 10⁻³ V·s/rad = N·m/A | ESTIMATED | (12 − 0.8·R) / 1885 rad/s |
| b (viscous friction, base) | 2.41 × 10⁻⁶ N·m·s/rad | ESTIMATED | K_t · 0.8 A / 1885 rad/s — lumps Coulomb friction into viscous |
| J (rotor + gearbox, base side) | 1.0 × 10⁻⁶ kg·m² | ESTIMATED | Typical of a 30 mm can motor; **largest uncertainty** |
| L (armature inductance) | 0.5 mH | ESTIMATED | Typical; τ_e = L/R ≈ 0.3 ms ≪ τ_m |
| τ_m = R·J / (K_t·K_e) | ≈ 49 ms | Derived from estimates | |
| η (gearbox efficiency) | 1.0 | ASSUMED | See §1.2 |

Cross-check: with the drive's 3 A limit, max base torque ≈ K_t·3 A = 0.017 N·m →
1.7 N·m at the output (17 kgf·cm), close to the 15 kgf·cm rating.

---

## 2. Drive — Rhino RMCS-2303 DC servo drive, UART ASCII Modbus

Source: **SRC-002** (`RMCS-2303_updated_datasheet.pdf`, "Operating Manual v1.0", © 2020).

### 2.1 What the drive is

- A **closed-loop servo drive**, not an H-bridge. In every mode it closes its own loop on
  the encoder (p.8: "in position mode the drive always tries to make the error … 0,
  in case of speed mode it tries to make the speed same as set speed").
- There is **no open-loop voltage/PWM mode**. Mode 0 "analog" is closed-loop speed with
  the setpoint from an analog input.
- At power-up the position counter is 0; it is a 32-bit count (p.8).

### 2.2 Electrical

| Quantity | Value | Status | Page |
|---|---|---|---|
| Supply voltage | 10 – 30 V DC | VERIFIED_FROM_MANUAL | 4 |
| Phase current | 0.5 – 3 A, "peak 3 A per phase" | VERIFIED_FROM_MANUAL | 4 |
| Protection | Short-circuit (motor outputs), over/under-voltage, survives motor disconnect | VERIFIED_FROM_MANUAL | 3 |
| Analog input (Mode 0) max | 3.3 V | VERIFIED_FROM_MANUAL | 6 |
| UART logic level | UNVERIFIED | — | Uno is 5 V; manual shows a direct connection without level shifting |

### 2.3 Pins

| Pin | Function | Pin | Function |
|---|---|---|---|
| 1 | GND | 8 | GND (encoder) |
| 2 | RXD | 9 | +5 V DC (encoder supply) |
| 3 | TXD | 10 | ENC_B / Hall W |
| 4 | ENABLE | 11 | ENC_A / Hall V (p.4) — "Hall U" on p.5 |
| 5 | ADC | 12 | Hall U |
| 6 | DIRECTION | 13 | W |
| 7 | BRAKE | 14 | Motor− / V |
| | | 15 | Motor+ / U |
| | | 16 | VDD (10–30 V) |
| | | 17 | GND (supply) |

Conflict **C-M4**: p.4 and p.5 label pin 11 differently (Hall V vs Hall U). Irrelevant for a
DC motor with a quadrature encoder (Hall U/V/W are for BLDC), but it shows the tables
were not carefully proofread. **Wire by pin function, verified on the board silkscreen,
never by row alignment in the p.5 side-by-side table** (that table lists motor wire colours
beside drive pins they are *not* connected to).

Function mapping for this motor: Black→8, Brown→9, **Orange (EncB)→10, Red (EncA)→11** (per the RMCS-5032 sheet; confirmed by the 2026-10-11 runaway with the reverse),
Yellow (M−)→14, Green (M+)→15, supply +→16, supply −→17.

### 2.4 Modes (register 0x02, "Control and Mode", pp.23, 25)

| Value (hex) | Value (dec) | Meaning |
|---|---|---|
| 0x0001 / 0x0000 | 1 / 0 | Analog mode enable / disable |
| 0x0101 / 0x0100 | 257 / 256 | Digital speed mode, **CW**, enable / disable |
| 0x0104 | 260 | Digital speed mode, brake, CW |
| 0x0109 / 0x0108 | 265 / 264 | Digital speed mode, **CCW**, enable / disable |
| 0x010C | 268 | Digital speed mode, brake, CCW |
| 0x0201 / 0x0200 | 513 / 512 | Position mode enable / disable |
| 0x0700 | 1792 | **E-stop**: stop and remove motor power (shaft free) |
| 0x0701 | 1793 | **Stop**: stop motion, hold position |
| 0x0800 | 2048 | Set home (position count := 0) |
| 0x0900 | 2304 | Restart drive |

Bit layout: high byte = mode; low byte bit 3 DIR (0 CW, 1 CCW, digital mode only),
bit 2 BRK, bit 0 EN. "Enable has more priority than brake."

The Arduino library maps direction 0 = "forward (encoder count +)" and 1 = "reverse"
(p.33). Whether "forward" equals CW for this motor is UNVERIFIED (C-M3).

### 2.5 Register map (pp.23–28)

| Addr (dec) | Modbus | Name | Size | Default | Notes |
|---|---|---|---|---|---|
| 0 | 40001 | Slave ID + save-to-EEPROM | 16 | 0x0BFF read, ID 11 | Write `IDFF` to save, e.g. 0x0BFF |
| 2 | 40003 | Control and mode | 16 | 0x0000 | §2.4 |
| 4 | 40005 | Position proportional gain (PPG) | 8 used | 32 | 1–255 |
| 6 | 40007 | Position integral gain (PIG) | 8 used | 16 | 0–255; "affects torque" |
| 8 | 40009 | Velocity feed-forward gain (VFFG) | 8 used | 32 | 0–255 |
| 10 | 40011 | **Lines per rotation (LPR)** | 16 | **334** | **Must be 13 for RMCS-5032** |
| 12 | 40013 | Acceleration | 16 | 20000 | Units UNVERIFIED |
| 14 | 40015 | Speed command, **base-motor rpm** | 16 | 2048 | Unsigned 0–65535 |
| 16 | 40017 | Position command LSW | 16 | 0 | |
| 18 | 40019 | Position command MSW | 16 | 0 | **Motion starts only when 18 is written** |
| 20 | 40021 | Position feedback LSW | 16 RO | | |
| 22 | 40023 | Position feedback MSW | 16 RO | | |
| 24 | 40025 | Speed feedback, **base-motor rpm** | 16 RO | | Library returns negative for reverse — signedness UNVERIFIED |

Note that addresses are even-only. Whether "address 2" means Modbus register 2 or byte
offset 2 (= register 1) on the wire is **UNVERIFIED** (OI-M4). Resolve from the vendor
Arduino library source before writing firmware.

### 2.6 Slave ID (p.7)

Jumpers JP1–JP3 give IDs 1–7 (binary JP1 JP2 JP3, e.g. 0 0 1 → ID 1). **No jumper → the
programmed ID, factory default 11.** Jumpers are read at start-up only.

### 2.7 Count scaling (pp.20–21)

counts per output revolution = LPR × 4 × gear ratio. The manual's worked example is a
different motor (RMCS-5014, 334 lines, 90:1 → 120 240). For the RMCS-5032:
**13 × 4 × 100 = 5200**, matching the motor sheet.

Speed command and feedback are **base-motor rpm**: output rpm = base rpm / 100.
The drive computes rpm from LPR, so with LPR left at 334 every rpm reading would be
wrong by 334/13 ≈ 25.7×.

The manual warns (p.18): set speed must be below what the motor can reach at the supply
voltage, "otherwise the drive can give uncertain result".

### 2.8 Arduino Uno connection (p.29)

| Drive | Uno |
|---|---|
| GND (pin 1) | GND |
| RXD (pin 2) | D3 (SoftwareSerial TX) |
| TXD (pin 3) | D2 (SoftwareSerial RX) |

The Uno's single hardware UART is taken by USB, so the drive uses SoftwareSerial.
All vendor examples use **9600 baud**. Data bits, parity and stop bits are not stated
(OI-M3). D2 and D3 are the Uno's only external-interrupt pins (INT0/INT1).

> **This project does NOT use D2/D3.** It uses AltSoftSerial on **D9 → drive RXD (pin 2)** and
> **D8 ← drive TXD (pin 3)** (ED-M5). Wire from `docs/hardware/WIRING.md`, not from this summary.

### 2.9 Vendor Arduino library (pp.30–34)

`RMCS2303drive` from `http://robokits.co.in/downloads/RMCS2303drive_Arduino_Library.zip`
(not yet downloaded or reviewed — OI-M4). Documented calls:

```text
WRITE_PARAMETER(id, mode, PP_gain, PI_gain, VF_gain, LPR, acceleration, speed)
READ_PARAMETER(id)
Speed(id, rpm)                 Enable_Digital_Mode(id, dir)   Disable_Digital_Mode(id, dir)
Brake_Motor(id, dir)           Speed_Feedback(id) -> long
Absolute_position(id, counts)  Position_Feedback(id) -> long
SAVE(id)  RESET(id)  ESTOP(id)  STOP(id)  SET_HOME(id)  Restart(id)
```

---

## 3. Controller board — Arduino Uno (clone with a CH340C USB-serial chip)

Source: **SRC-004** (online documentation); board identified by the owner (2026-10-25) and by its
USB id 1a86:7523 (QinHeng CH340) on the lab PC.

| Quantity | Value | Status |
|---|---|---|
| MCU | ATmega328P, 16 MHz | VERIFIED_FROM_MANUAL |
| USB-serial bridge | **CH340C** (not the original ATmega16U2): Windows and older macOS need the WCH CH34x driver; Linux has it built in | MEASURED (USB id) |
| Hardware UARTs | 1 (shared with USB) | VERIFIED_FROM_MANUAL |
| External interrupt pins | D2, D3 | VERIFIED_FROM_MANUAL |
| Logic level | 5 V | VERIFIED_FROM_MANUAL |

The drive's UART is on D8/D9 (AltSoftSerial). The firmware's **BRIDGE** mode (`$BRIDGE,1`)
turns the Uno into a USB-to-drive adapter at 9600 baud so that the manufacturer's Windows
configuration software (SRC-017) can reach the drive without rewiring; a reset (reopening
the port) ends it.

---

## 4. Power: the battery

| Item | Value | Status |
|---|---|---|
| Pack | Pro-Range INR18650 Li-ion, **3S2P**, 11.1 V nominal, 4400 mAh, **2C** | VERIFIED_FROM_MANUAL (SRC-016, seller listing; owner 2026-10-25) |
| Voltage range | 12.6 V full (4.2 V/cell), 11.1 V nominal, ~9.0 V cut-off (3.0 V/cell) | VERIFIED_FROM_MANUAL (12.6, 11.1); cut-off from a generic 3S2P datasheet |
| Continuous discharge | 2C = **8.8 A** | Derived |
| Protection | built-in BMS (over-charge, over-discharge, short) | Seller listing |
| Connectors | Amass Nylon-T discharge, JST-XH balance/charge | Seller listing |
| Charger | 3S Li-ion CC/CV 12.6 V | Derived |

Who limits the current: the drive (3 A per phase, SRC-002 p.4) before the motor (stall
11.1 V / 1.6 Ω = 6.9 A, ESTIMATED) and before the battery (8.8 A). The drive therefore caps
the output torque at about 1.7 N·m, far below the datasheet's 5.9 N·m stall (C-M5). The
product page states 5 A peak (SRC-018), the manual 3 A per phase: conflict **C-M7**, the
model uses the manual's 3 A.

Free speed scales with the voltage: 180 rpm at 12 V gives 166.5 rpm at 11.1 V nominal, 189 rpm
full and 135 rpm near cut-off. The full-voltage runaways measured 165.9-175.3 rpm, median
166.8 (2026-10-11 to 10-24). A full pack therefore lets the drive reach a little more than the
150 rpm the experiments ever ask for; an almost empty one does not (the static map's 150 rpm
step needs at least ~10 V).

Motor nominal is 12 V; the drive accepts 10–30 V. A 24 V supply lets the drive spin the
motor beyond its 12 V no-load speed if commanded — **C-M6**. With this battery that cannot
happen.

---

## 5. Temperature-control hardware

Not started. DHT22, SSR-40DA, LCD and bulb are **UNVERIFIED** — see `OPEN_ITEMS.md`.
