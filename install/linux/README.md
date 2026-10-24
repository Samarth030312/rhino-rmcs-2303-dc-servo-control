# Linux (Ubuntu / Debian)

## One step

```bash
curl -fsSL https://raw.githubusercontent.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/main/install/linux/install.sh | bash
```

It clones to `~/rhino-rmcs-2303-dc-servo-control` (or updates it), adds you to the `dialout` group if needed
(serial access, then log out and in once), and starts MATLAB with `setup open`, which
installs the Arduino toolchain into `~/.local/share/arduino-lab-tools` and opens the app.

## By hand

```bash
git clone https://github.com/Samarth030312/rhino-rmcs-2303-dc-servo-control.git ~/rhino-rmcs-2303-dc-servo-control
sudo usermod -aG dialout $USER        # once, then log out and in
matlab -r "cd('$HOME/rhino-rmcs-2303-dc-servo-control'); setup open"
```

Shell helpers (same toolchain as MATLAB): `scripts/setup/acli board list`,
`scripts/setup/upload motor /dev/ttyUSB0`, `scripts/validation/build_firmware.sh`.

## Notes

- A genuine Uno is `/dev/ttyACM0`; a CH340 clone is `/dev/ttyUSB0`.
- If a CH340 board's port appears and vanishes a second later, `brltty` took it:
  `sudo apt remove brltty`.
- `ffmpeg` (`sudo apt install ffmpeg`) turns the app's recordings into MP4; without it
  they stay AVI.
