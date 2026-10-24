# Install: one snippet per operating system

You need **MATLAB R2023b or newer** (base MATLAB; Simulink only for the `.slx` models),
an internet connection the first time, and, for the rig, an Arduino Uno on a **data** USB
cable. No admin rights are needed, apart from Git and Rosetta 2 if they are missing.

Copy one line into a terminal and press Enter. It fetches the repository, checks the USB
driver, starts MATLAB, installs the project's own Arduino toolchain on first use (about
60 MB, hash-checked), and opens the app.

| System | Open | Paste |
|---|---|---|
| **Windows 10 / 11**, Command Prompt | `cmd` | `powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/main/install/windows/install.ps1 \| iex"` |
| **Windows 10 / 11**, PowerShell | PowerShell or Windows Terminal | `[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/main/install/windows/install.ps1 \| iex` |
| **macOS 11+** (Intel or Apple silicon) | Terminal | `curl -fsSL https://raw.githubusercontent.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/main/install/macos/install.sh \| bash` |
| **Linux** (Ubuntu / Debian) | Terminal | `curl -fsSL https://raw.githubusercontent.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/main/install/linux/install.sh \| bash` |

(In the table `\|` is a plain `|`; the per-system pages below have the lines ready to copy.)

Details, the same steps by hand, and fixes: [Windows](windows/README.md) ·
[macOS](macos/README.md) · [Linux](linux/README.md).

## After the first time

In MATLAB:

```matlab
cd ~/rhino-rmcs-2303-dc-servo-control      % Windows: cd(fullfile(getenv('USERPROFILE'), 'rhino-rmcs-2303-dc-servo-control'))
setup open                % checks, then opens the app
setup fix               % full check of this computer, with the fix for each problem
```

Running the snippet again updates the repository (`git pull`) and starts the lab.

## What can go wrong, and what the set-up does about it

| Problem | Where | What happens |
|---|---|---|
| No COM port for a clone Uno (CH340 chip, USB id 1a86:7523) | Windows | the installer and `setup fix` find the device without a driver, open Device Manager and the maker's driver page, and say which button to press |
| Charge-only USB cable, hub, or wrong socket | all | `setup fix`: "no serial port found", with what to try |
| Port held by the Arduino IDE Serial Monitor or another MATLAB | all | `setup fix` and the app name the port that is busy |
| `/dev/tty.*` port that hangs on open | macOS | only `/dev/cu.*` ports are offered |
| Apple silicon: `bad CPU type` when compiling | macOS | the AVR compiler is an Intel binary; the installer installs Rosetta 2 |
| CH340 driver on macOS 10.15 or older | macOS | the installer warns and links the driver |
| No permission on `/dev/ttyUSB0` | Linux | the installer adds you to `dialout`; the doctor checks it |
| `brltty` grabbing the CH340 board | Linux (Ubuntu) | the installer and the doctor warn and give the command |
| Git missing | Windows, macOS | installed with winget / Homebrew / the Command Line Tools; otherwise a ZIP download |
| Repository in OneDrive / iCloud, or a long or non-ASCII path | Windows, macOS | the doctor warns; the toolchain itself goes to a plain-ASCII folder |
| `arduino-cli` downloaded but altered or truncated | all | refused: the SHA-256 must match the pinned value (`tools.manifest`) |
| An Arduino IDE already on the computer | all | untouched: this project keeps its own cores and libraries |
| PowerShell blocks scripts (execution policy) | Windows | the snippet uses `irm \| iex`, which the policy does not apply to |
| Old TLS default in Windows PowerShell 5.1 | Windows | the snippet switches to TLS 1.2 first |

The Windows and macOS installers and the whole MATLAB test suite run on GitHub's Windows,
macOS and Ubuntu machines for every change ([CI](../.github/workflows/ci.yml)). A real
USB board is the one thing CI cannot plug in.
