# Windows 10 / 11

## One step

**Command Prompt** (Start, type `cmd`, Enter), paste:

```bat
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/main/install/windows/install.ps1 | iex"
```

**or PowerShell / Windows Terminal**, paste:

```powershell
[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/main/install/windows/install.ps1 | iex
```

It installs Git if missing (winget), clones to `%USERPROFILE%\rhino-rmcs-2303-dc-servo-control` (or updates it),
checks the board's USB driver, and starts MATLAB with `setup open`. MATLAB then installs
the Arduino toolchain into `%LOCALAPPDATA%\arduino-lab-tools` (once, about 60 MB) and opens the
DC-motor app. To use another folder, first run `set SERVOLAB_DIR=D:\labs\rhino-rmcs-2303-dc-servo-control` (cmd) or
`$env:SERVOLAB_DIR='D:\labs\rhino-rmcs-2303-dc-servo-control'` (PowerShell).

The script is [install.ps1](install.ps1): read it before running it if you like.

## The same, by hand (Command Prompt)

Change `COM5` to your port; everything else can be pasted as it is.

```bat
winget install --id Git.Git -e --source winget
git clone https://github.com/Samarth030312/rhino-rmcs-2303-dc-servo-control.git "%USERPROFILE%\rhino-rmcs-2303-dc-servo-control"
matlab -r "cd('%USERPROFILE%\rhino-rmcs-2303-dc-servo-control\matlab'); setup open"
```

Inside MATLAB, by hand:

```matlab
setup fix fix                              % install the toolchain, check everything
servolab.tools.flash('motor', 'COM5')            % compile and upload the motor firmware
rhino_servo_lab                                   % the app (it also has a FLASH button)
```

Update later: `git -C "%USERPROFILE%\rhino-rmcs-2303-dc-servo-control" pull`

## No COM port?

1. **Cable.** Many USB cables only charge. Use one that has carried data, directly into the
   laptop (no hub). The Uno's ON LED must light.
2. **Driver.** Clone Unos use a **CH340** USB chip. Check in Command Prompt:
   ```bat
   powershell -NoProfile -Command "Get-PnpDevice -PresentOnly | ? InstanceId -match 'VID_1A86|VID_2341' | ft Status,Class,FriendlyName -Auto"
   ```
   `OK  Ports  USB-SERIAL CH340 (COM5)` is good. `Error` or a class other than `Ports`
   (often "USB2.0-Serial" under *Other devices*) means no driver: open Device Manager
   (`devmgmt.msc`), right-click it, **Update driver → Search automatically**. If Windows finds
   nothing, install **CH341SER.EXE** from the chip maker:
   <https://www.wch-ic.com/downloads/CH341SER_EXE.html>, then unplug and replug the board.
3. **Busy port.** Close the Arduino IDE Serial Monitor and any other MATLAB window.
4. In MATLAB: `setup fix`, which lists the ports it sees and what each one is.

## Notes

- `irm … | iex` runs the script in memory, so the PowerShell execution policy does not block
  it. To run it from a file instead:
  `powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1`.
- The toolchain never touches `Documents\Arduino` or `%LOCALAPPDATA%\Arduino15`, so an
  installed Arduino IDE keeps its own settings.
- If your Windows user name has non-ASCII characters, the toolchain goes to
  `C:\arduino-lab-tools` instead (the AVR compiler fails on such paths). Keep the repository
  on a plain path too, e.g. `C:\rhino-rmcs-2303-dc-servo-control`.
