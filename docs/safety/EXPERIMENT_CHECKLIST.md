# Pre-power Checklist — DC motor (RMCS-2303 + RMCS-5032)

Complete every line, initial it, and save a photo of the wiring before the first power-up of
each session. Do not power the motor without the operator's approval.

## Unpowered

- [ ] Supply label read: ____ V, ____ A (OI-M1). 12 V preferred (C-M6).
- [ ] Supply polarity to drive pin 16 (VDD +) and pin 17 (GND) checked with a multimeter.
- [ ] Motor wires by **function**, not by table row: Yellow M− → pin 14, Green M+ → pin 15,
      Lab cable: **Green → 8, Blue → 9, Yellow → 10, White → 11, thin Black → 14, thin Red → 15** (verified 2026-10-11; datasheet colours differ, see DC_MOTOR_WIRING.md). Photograph.
- [ ] Encoder supply is the drive's +5 V (pin 9), not the Uno's and not 12 V.
- [ ] Uno ↔ drive: GND–GND, **D9 → drive RXD (pin 2), D8 ← drive TXD (pin 3)** (not the vendor's D2/D3). Nothing else.
- [ ] No connection between the 12/24 V supply and any Uno pin.
- [ ] Jumpers JP1–JP3 state recorded (slave ID).
- [ ] Motor clamped; output shaft free or with a guarded load; nothing that can be thrown.
- [ ] Supply switch (or plug) within reach of the operator.

## First power-up

- [ ] Drive powered with the Uno disconnected; drive LED behaviour noted; no heat/smell.
- [ ] Drive TXD idle voltage measured: ____ V (OI-M11). If > 5.5 V, stop.
- [ ] Uno connected; firmware reports `$HELLO`; `READ_PARAMETER` dump saved (MOTOR-01).
- [ ] LPR = 13 confirmed before any speed command (otherwise rpm scaling is ×25.7 wrong).
- [ ] First motion: lowest useful speed (≤ 20 output rpm), STOP tested, E-STOP tested,
      power-switch removal tested.
- [ ] Watchdog tested: close MATLAB mid-run → motor stops within ~1 s.

## Abort immediately on

Unexpected direction, speed far from command, oscillation growing, drive or motor hot,
smell, noise, any Modbus timeout flag. Then record the anomaly with time and run ID.
