# Serial Protocol v1 — MATLAB ⇄ Arduino (DC motor)

**STATUS: IMPLEMENTED, not yet run on a real board.** MATLAB side: `servolab.protocol.*`,
`servolab.io.SerialLink`. Firmware: `firmware/motor_controller` ($TEL),
`temperature/firmware/temperature_controller` ($TTEL), `water_level/firmware/level_controller` ($LTEL).
The motor firmware has been run on the PC against an emulated RMCS-2303
(`firmware/tests/firmware_host_test.cpp`, 23 checks) and its full output is parsed by MATLAB
(`test_firmware_transcript`).

This is the USB link between MATLAB and the Uno. It is *not* the Modbus ASCII link between the
Uno and the RMCS-2303 (HARDWARE_REFERENCE §2).

## 1. Physical

USB CDC serial, **115200 baud, 8N1**, lines terminated by `\n` (a preceding `\r` is ignored).

## 2. Framing

```
$<TYPE>,<version>,<field1>,…,<fieldN>*<CS>\n
```

- `version` is `1`. A frame with another version is rejected.
- `CS` = two hex digits, XOR of every byte strictly between `$` and `*` (the NMEA 0183 rule).
- Fields never contain `,` `*` `$` or control characters.
- Numbers: decimal, `.` as the separator. Missing value: `nan`.
- A line starting with `#` is **human-readable debug text**. The host logs it and never parses it
  as data. Nothing else may be printed by the firmware.
- Anything else is invalid; the host counts it and keeps going.

## 3. Host → device

| Frame | Meaning |
|---|---|
| `$PING,1` | Keep-alive. Sent by the host every 0.25 s while running. |
| `$CFG,1,<loop>,<ctrl>,<Kp>,<Ki>,<Kd>,<Tf_ms>,<Ts_ms>,<umax_rpm>` | loop `S` speed / `P` position; ctrl `OL` `P` `I` `PI` `PID`; gains in the units of `CONTROL_THEORY.md` §5 |
| `$SET,1,<setpoint>` | Output rpm (S) or output degrees (P) |
| `$RUN,1` | Reset t and seq to 0, start the loop and telemetry |
| `$STOP,1` | End the run. A turning motor is first brought to rest on the drive's own ramp (speed register ← 0, at most 4 s, `# soft stop: … ms` line), then register 2 ← 0x0700: **motor power off**, shaft free. Never 0x0701 (hold): with a reversed encoder it runs away (2026-10-11). |
| `$STOP,1,NOW` | End the run and switch motor power off at once (register 2 ← 0x0700): the app's ABORT. |
| `$BRIDGE,1` | Motor power off, then the Uno becomes a transparent USB ↔ drive link at **9600 baud 8N1** for the manufacturer's configuration software. Kept in EEPROM: survives resets (opening a port resets a CH340 Uno). The firmware's watchdog and guards are not active. |
| `$ENDBRIDGE` (raw, sent at 9600) | Leaves BRIDGE: EEPROM cleared, the firmware restarts at 115200 and says `$HELLO`. The STOP button does the same. |
| `$ESTOP,1` | Drive E-STOP (register 2 ← 0x0700): **remove motor power**, shaft free. |
| `$HOME,1` | Set home (register 2 ← 0x0800). Only when stopped. Also clears the E-STOP latch. |
| `$DIAG,1` | Read and print the drive registers as `#` lines (MOTOR-01). Only when stopped. |

Temperature board: `$CFG,1,<ONOFF|HYST|MA|P|TPROP>,<setpoint>,<hyst>,<window>,<Kp>,<tprop_ms>`.
Level board: `$CFG,1,<ONOFF|P|PI>,<Lmin>,<Lmax>,<setpoint>,<Kp>,<Ki>` and `$CAL,1,<sensor_to_floor_cm>,<full_cm>`.
Both accept `$RUN`, `$STOP`, `$SET`, `$PING`.

Device answers every command with `$ACK,1,<TYPE>` or `$ERR,1,<TYPE>,<code>,<text>`.

## 4. Device → host

| Frame | Meaning |
|---|---|
| `$HELLO,1,<fw_name>,<git_rev>,<slave_id>` | Sent once after reset |
| `$TEL,1,<seq>,<t_ms>,<loop>,<ctrl>,<setpoint>,<meas>,<err>,<u>,<pos_counts>,<spd_base_rpm>,<flags>` | One per control sample |

`TEL` units: setpoint / meas / err in output rpm (S) or output degrees (P); `u` = speed command
in **output** rpm (the firmware multiplies by 100 before writing register 14); `pos_counts` =
drive position feedback (5200 / output rev); `spd_base_rpm` = drive register 24 as read.
`flags` (hex): bit0 RUNNING, bit1 SATURATED, bit2 MODBUS_TIMEOUT, bit3 MODBUS_LRC_ERROR,
bit4 ESTOPPED, bit5 SPEED_CLAMPED, bit6 WATCHDOG_STOP, bit7 OVERRUN (sample took longer than Ts).

`$TTEL,1,<seq>,<t_ms>,<mode>,<setpoint>,<temp_raw>,<temp_filt>,<err>,<u>,<heater>,<flags>` and
`$LTEL,1,<seq>,<t_ms>,<mode>,<setpoint>,<level_cm>,<level_pct>,<err>,<u>,<pump>,<flags>`:
field lists and flag bits in `matlab/functions/+servolab/+protocol/schema.m` (the single source).

## 5. Safety behaviour required of the firmware

1. **Watchdog**: while running, if no frame arrives from the host for **1.0 s**, send drive STOP,
   set WATCHDOG_STOP, stop the loop. A hung MATLAB therefore stops the motor.
2. Clamp |command| to 18000 base rpm (and lower if the supply is 24 V, C-M6); set SPEED_CLAMPED.
3. On any Modbus timeout during a run: STOP, set MODBUS_TIMEOUT, report `$ERR`.
4. At reset: drive disabled until `RUN`.
5. Never print anything that is not a frame or a `#` line.

The physical E-stop is the power switch. Software stop is a convenience, not a safety function.

## 6. Example

```
host:   $CFG,1,P,P,0.3,0,0,10,150,180*7E
host:   $SET,1,90*7A
host:   $RUN,1*54
device: $ACK,1,RUN*31
device: $TEL,1,0,0,P,P,90,0,90,27,0,0,1*68
```

Checksums computed with the XOR rule (and identical to `servolab.protocol.encode`).
