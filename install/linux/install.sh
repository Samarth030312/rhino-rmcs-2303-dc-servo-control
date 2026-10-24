#!/usr/bin/env bash
# Rhino DC Servo Lab: one-step set-up for Linux (Ubuntu / Debian; other distributions: see the notes).
#
#   curl -fsSL https://raw.githubusercontent.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/main/install/linux/install.sh | bash
#
# What it does:
#   1. clones the repository to ~/rhino-rmcs-2303-dc-servo-control, or updates it (installs git with apt if missing)
#   2. serial access: adds you to the dialout group if needed (asks for your password once)
#   3. finds MATLAB and starts it with setup open, which installs the Arduino toolchain
#      (into ~/.local/share/arduino-lab-tools) on first use and opens the app
#
# Options (environment variables):  SERVOLAB_DIR (default ~/rhino-rmcs-2303-dc-servo-control), SERVOLAB_NO_LAUNCH=1
set -euo pipefail
REPO_URL="https://github.com/Samarth030312/rhino-rmcs-2303-dc-servo-control.git"
DIR="${SERVOLAB_DIR:-$HOME/rhino-rmcs-2303-dc-servo-control}"
say()  { printf '\033[36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33m!!  %s\033[0m\n' "$*"; }

printf '\nRhino DC Servo Lab set-up (Linux, %s)\nRepository folder: %s\n\n' "$(uname -m)" "$DIR"

# ---------------------------------------------------------------- 1. git and the repository
if ! command -v git >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then say "Installing git (apt) ..."; sudo apt-get update -qq && sudo apt-get install -y -qq git
  else echo "Install git with your package manager, then run this again." >&2; exit 1; fi
fi
if [ -d "$DIR/.git" ]; then
  say "Updating $DIR (git pull) ..."
  git -C "$DIR" pull --ff-only || warn "git pull did not fast-forward (local changes?). Continuing with the copy you have."
elif [ -e "$DIR" ]; then
  echo "$DIR exists but is not a git checkout: rename it or set SERVOLAB_DIR, and run this again." >&2; exit 1
else
  say "Cloning into $DIR ..."; git clone "$REPO_URL" "$DIR"
fi

# ---------------------------------------------------------------- 2. serial permission
if id -nG | tr ' ' '\n' | grep -qx -e dialout -e uucp; then
  say "Serial access: you are in the dialout group."
elif getent group dialout >/dev/null 2>&1 && [ "${SERVOLAB_NO_LAUNCH:-0}" != 1 ]; then
  say "Adding you to the dialout group (serial access to the Arduino) ..."
  sudo usermod -aG dialout "$USER" && warn "Log out and back in once for the serial permission to take effect."
fi
if command -v brltty >/dev/null 2>&1; then
  warn "brltty is installed. On some Ubuntu releases it grabs CH340 boards (the port appears, then vanishes)."
  warn "If that happens: sudo apt remove brltty"
fi

# ---------------------------------------------------------------- 3. MATLAB
matlab="$(command -v matlab || true)"
if [ -z "$matlab" ]; then
  matlab="$(ls -d /usr/local/MATLAB/R20*/bin/matlab /opt/MATLAB/R20*/bin/matlab "$HOME"/MATLAB/R20*/bin/matlab 2>/dev/null | sort -r | head -1 || true)"
fi
mdir_q="$(printf '%s' "$DIR" | sed "s/'/''/g")"
echo
if [ "${SERVOLAB_NO_LAUNCH:-0}" = 1 ]; then
  say "Done (MATLAB not started: SERVOLAB_NO_LAUNCH=1)."
elif [ -n "$matlab" ]; then
  say "Starting MATLAB ($matlab). It installs the Arduino toolchain the first time (about 60 MB), then opens the lab."
  nohup "$matlab" -desktop -r "cd('$mdir_q'); setup open" >/dev/null 2>&1 &
else
  warn "MATLAB was not found. Install MATLAB R2023b or newer, then in MATLAB run:"
  echo "      cd('$mdir_q'); setup open"
fi
cat <<EOF

Next time: open MATLAB and run   cd('$mdir_q'); setup open
Problems:  in MATLAB run         setup fix
Push recorded data (after the owner adds your GitHub account as a collaborator):
      git -C "$DIR" add data results && git -C "$DIR" commit -m "data: <what you ran>" && git -C "$DIR" push

EOF
