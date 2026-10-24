# Electrical Safety

## DC motor experiment

- Supply 10–30 V DC to the drive only (SRC-002 p.4). Motor rated 12 V (SRC-003).
- The motor can draw up to 7.5 A; the drive limits phase current to 3 A peak. Use a supply
  rated ≥ 3 A and a fuse or current-limited bench supply where available.
- The drive survives motor disconnection and has short-circuit protection (SRC-002 p.3), but do
  not rewire anything while powered.
- The geared output (≈ 1.5 N·m rated, 180 rpm) can trap fingers and fling loose parts. Clamp
  the motor; keep hands away while enabled.
- Software STOP / E-STOP are conveniences. The real emergency stop is removing supply power.
- The Uno is powered from USB; its GND is shared with the drive's logic GND only.

## Temperature experiment (mains) — not started

- Never switch mains voltage directly from an Arduino GPIO.
- Never expose live mains wiring; enclose, insulate, fuse; separate mains and low voltage.
- Verify the SSR's exact datasheet and ratings before use (SRC-008 missing).
