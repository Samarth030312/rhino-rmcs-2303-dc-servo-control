# macOS 11 or newer (Intel or Apple silicon)

## One step

In **Terminal**, paste:

```bash
curl -fsSL https://raw.githubusercontent.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/main/install/macos/install.sh | bash
```

It uses git (or installs it), clones to `~/rhino-rmcs-2303-dc-servo-control` (or updates it), installs Rosetta 2
on Apple silicon if missing, and starts MATLAB with `setup open`. MATLAB then installs
the Arduino toolchain into `~/Library/Application Support/arduino-lab-tools` (once, about 60 MB) and
opens the app. Another folder: `SERVOLAB_DIR=~/labs/rhino-rmcs-2303-dc-servo-control bash -c "$(curl -fsSL …)"`.

The script is [install.sh](install.sh).

## By hand

```bash
xcode-select --install                                  # git, if `git --version` fails
softwareupdate --install-rosetta --agree-to-license     # Apple silicon only
git clone https://github.com/Samarth030312/rhino-rmcs-2303-dc-servo-control.git ~/rhino-rmcs-2303-dc-servo-control
open -na "$(ls -d /Applications/MATLAB_R20*.app | sort -r | head -1)" --args -r "cd('$HOME/rhino-rmcs-2303-dc-servo-control'); setup open"
```

In MATLAB: `setup fix fix`, then `servolab.tools.flash('motor', '/dev/cu.usbserial-1420')`
(your port name is shown by `setup fix` and in the app).

## Notes

- **Ports.** A genuine Uno appears as `/dev/cu.usbmodem…`, a CH340 clone as
  `/dev/cu.usbserial-…` (or `/dev/cu.wchusbserial…` with the vendor driver). Always use the
  `cu.` name: the `tty.` twin waits for a modem signal and hangs. The app offers only `cu.`.
- **Rosetta 2.** The Arduino AVR compiler and uploader (`arduino:avr` 1.8.8) are published
  for Intel Macs only; on Apple silicon they run through Rosetta 2. Without it, compiling
  fails with `bad CPU type in executable`.
- **CH340 driver.** Included in macOS 11 and newer. On 10.15 or older install it from
  <https://www.wch-ic.com/downloads/CH34XSER_MAC_ZIP.html> and allow it under System
  Settings, Privacy & Security.
- **USB-C hubs** sometimes fail with clone boards: try another adapter if no port appears.
