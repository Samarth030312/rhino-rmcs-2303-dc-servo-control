# Troubleshooting

First: `setup probe` in MATLAB (from the repository folder). It checks MATLAB, the toolchain,
the USB driver, the serial permission, a busy port, and asks the board for its firmware;
each problem comes with its fix. Installation problems per system: [install](../install/README.md).

## Computer and board

| Symptom | Cause | Fix |
|---|---|---|
| no port in the app's list | charge-only cable, hub, missing CH340 driver (Windows, old macOS), Linux permission | data cable, another socket; `setup probe` names the cause; Windows: [CH340 driver](../install/windows/README.md) |
| port appears, then vanishes (Ubuntu) | `brltty` grabs CH340 boards | `sudo apt remove brltty` |
| "port in use" | Arduino IDE Serial Monitor, another MATLAB, the Rhino software | close it |
| connected, but no `$HELLO` within 6 s | another sketch on the board; or the board is in BRIDGE | **FLASH FIRMWARE**; **END BRIDGE** |
| compile fails with `bad CPU type` (Apple silicon) | the AVR compiler is an Intel binary | install Rosetta 2 (`softwareupdate --install-rosetta`); the macOS installer does it |
| compile fails on Windows with odd path errors | non-ASCII user name | the toolchain goes to `C:\arduino-lab-tools` automatically; or set `SERVOLAB_TOOLS` |

## Drive and motor

| Symptom | Cause | Fix |
|---|---|---|
| "no drive answered" | battery off or below 10 V; D8/D9 swapped; GND missing | battery; D9 → drive pin 2, D8 ← pin 3, GND → pin 1 |
| `runaway: wrong way` on the first run | encoder A/B or motor leads reversed | swap **one** pair (motor leads 14/15 or A/B 10/11), never both |
| `runaway: too fast` | LPR not 13 (every speed 25.7× wrong); or a reverse runaway at start | DRIVE CHECK must show LPR 13; firmware e60d046+ re-homes at every RUN |
| `host silent >2 s - motor power off` | MATLAB stopped sending (frozen, closed, laptop asleep) | CLEAR FAULT, RUN again |
| `modbus feedback lost` | loose wire, battery sagging, electrical noise | wiring, battery; the firmware stops the motor rather than act on stale data |
| speeds stop at 140–150 rpm | battery nearly empty (free speed ∝ voltage) | charge it (12.6 V full) |
| the rig is slower or faster than the grey line | another acceleration register, battery or load | IDENTIFY FROM SELECTED RUN on one of your open-loop runs |
| a jolt when an experiment ends | the motor was still turning when motor power was cut (firmware before the soft stop) | flash the current firmware |

## Data

| Symptom | Fix |
|---|---|
| a run is missing from RUNS | runs are saved when they end, even stopped or aborted; check `data/RUN_REGISTER.csv` |
| SYNC DATA fails | no write access to the GitHub repository: push to your own fork |
| a raw file cannot be edited | on purpose: raw data is read-only ([data](../data/README.md)) |
