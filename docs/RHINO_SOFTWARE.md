# The official Rhino software, and the bridge

Robokits publishes a Windows program for the RMCS-2303, *Rhino DC Servo 2303 Config Setup*
("configuration and testing software", on the drive's product page). It reads and writes the
drive's registers (slave id, lines per rotation, gains, acceleration, mode) and spins the motor
for a test. This page answers two questions: can this project's MATLAB be integrated into it,
and can both be shown to see the same drive?

## Can MATLAB be integrated into it? No, and it does not need to be

| From first principles | |
|---|---|
| What the Rhino program is | a closed Windows GUI (a *Setup Factory 9* installer, inspected 2026-10-25, SHA-256 `d52ef41e…258e8d`) with no command line, no API and no library to call |
| How it reaches the drive | Modbus ASCII at 9600 baud on a serial port, to the drive's UART (pins 2/3) |
| How this project reaches the drive | the same Modbus ASCII, from the Uno on the same pins |
| The constraint | the drive's UART is point to point: **one master at a time** |

So the two cannot run side by side, and there is nothing in the Rhino program to integrate
with. Everything it does to the drive, this project does from MATLAB on Windows, macOS and
Linux: **DRIVE CHECK** dumps the registers, the firmware sets the lines per rotation before
every run, and the app runs the motor with safety guards the Rhino program does not have.

## Can both see the same drive? Yes: the bridge

Without rewiring, the Uno can step aside. **RHINO SW BRIDGE** in the app (or `$BRIDGE,1`)
makes the firmware a transparent link: whatever the PC sends on the Uno's USB port at 9600 baud
goes to the drive, and the drive's replies come back. The Rhino program then talks to the drive
through the Uno's own USB cable, as if it were a USB-serial adapter.

```mermaid
sequenceDiagram
    participant App as rhino_servo_lab
    participant Uno as Uno (motor firmware)
    participant Rhino as Rhino software (Windows)
    participant Drv as RMCS-2303
    App->>Uno: DRIVE CHECK ($DIAG): registers read by this firmware
    App->>Uno: $BRIDGE,1
    Uno->>Drv: motor power off
    Note over Uno: EEPROM flag set; USB now 9600 baud, pass-through
    App-->>App: closes the port
    Rhino->>Uno: opens the COM port (the Uno resets, boots back into BRIDGE)
    Rhino->>Drv: Modbus ASCII through the Uno
    Drv->>Rhino: register values
    Rhino-->>Rhino: close
    App->>Uno: END BRIDGE ($ENDBRIDGE at 9600)
    Uno-->>App: $HELLO (the controller again)
```

The mode is kept in EEPROM because opening a serial port resets a CH340 Uno; it survives
resets until **END BRIDGE**, the STOP button on D4, or a CONNECT that finds the board bridged
(the app ends the bridge by itself then). While bridged, the Rhino program is in charge and
this firmware's watchdog and runaway guard are **not** active: the motor is under the Rhino
program's control alone.

## Proof that both see the same data (procedure)

On a Windows PC with the rig:

1. In the app: CONNECT, **DRIVE CHECK**. Note the dump: slave id, register 2 (mode),
   4 (P gain), 6 (I gain), 8 (VFF gain), 10 (LPR), 12 (acceleration), 14 (speed command), 24
   (speed feedback), and the position count. On the lab's drive on 2026-10-24: id 7, P 32,
   I 30, VFF 25, LPR 13, acceleration 5000.
2. **RHINO SW BRIDGE**, then open the Rhino program on the same COM port, slave id 7: read the
   same registers. They must be equal (the position count differs only by any motion between
   the two reads).
3. Turn the shaft by hand by a known angle (one full turn of the output = 5200 counts), read the
   position in the Rhino program; END BRIDGE, DRIVE CHECK: the count must agree.
4. Optional: write a different acceleration in the Rhino program, END BRIDGE, DRIVE CHECK: the
   new value is there. Restore 5000 (or the firmware's runs will no longer match the model).

Status:

- **Tested against the emulated drive**: a Modbus read through the Uno, a reset while bridged,
  `$ENDBRIDGE` (`firmware/tests/firmware_host_test.cpp`, and the MATLAB end-to-end test).
- **Tested on the lab's drive, 2026-10-25** (firmware `348dc56` and later, Linux): a script
  played the Rhino program's part, sending raw Modbus ASCII frames through the bridged Uno.
  The registers read that way equal the ones DRIVE CHECK reads through the firmware:

  | register | through the bridge (PC, raw Modbus) | DRIVE CHECK (firmware) |
  |---|---:|---:|
  | 0 id/save | 1792 (0x700) | 1792 (0x700) |
  | 2 mode | 512 (0x200) | 512 (0x200) |
  | 10 LPR | 13 | 13 |
  | 14 speed command | 0 | 0 |
  | 24 speed feedback | 0 | 0 |

  Every reply's LRC checked. Opening the port resets the Uno, which comes back bridged, silent
  and at 9600: the drive answered **1.0 s** after the port opened (the bootloader), with no
  stray bytes. Before this was fixed (`348dc56`) the Uno first printed its start-up text at
  115200 and listened only after 2.8 s, so a program that queries at once got noise and no
  answer. `$ENDBRIDGE` brought the controller back (`$HELLO`) every time.
- **Not yet run: the Rhino program itself.** It needs a Windows PC at the rig. Record the two
  register lists in the session's report when it is. If the program reports no drive right
  after opening the port, wait a second and connect again (the Uno's reset).
