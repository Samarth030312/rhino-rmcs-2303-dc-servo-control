#!/bin/bash
# Rhino DC Servo Lab: one-step set-up for macOS 11 or newer (Intel or Apple silicon).
#
#   In Terminal:
#     curl -fsSL https://raw.githubusercontent.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/main/install/macos/install.sh | bash
#
# What it does (no admin rights needed, except the one-time Rosetta 2 install):
#   1. uses git if it works; otherwise asks macOS to install the Command Line Tools and
#      downloads a ZIP meanwhile
#   2. clones the repository to ~/rhino-rmcs-2303-dc-servo-control, or updates it (git pull)
#   3. Apple silicon: installs Rosetta 2 if missing (the Arduino AVR compiler is an Intel binary)
#   4. finds MATLAB and starts it with setup open, which installs the Arduino toolchain
#      (into ~/Library/Application Support/arduino-lab-tools) on first use and opens the app
#
# Options (environment variables):  SERVOLAB_DIR (default ~/rhino-rmcs-2303-dc-servo-control), SERVOLAB_NO_LAUNCH=1
# Written for the bash 3.2 that ships with macOS.
set -eu
REPO_URL="https://github.com/Samarth030312/rhino-rmcs-2303-dc-servo-control.git"
ZIP_URL="https://github.com/Samarth030312/rhino-rmcs-2303-dc-servo-control/archive/refs/heads/main.zip"
DIR="${SERVOLAB_DIR:-$HOME/rhino-rmcs-2303-dc-servo-control}"
say()  { printf '\033[36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33m!!  %s\033[0m\n' "$*"; }

printf '\nRhino DC Servo Lab set-up (macOS %s, %s)\nRepository folder: %s\n\n' "$(sw_vers -productVersion)" "$(uname -m)" "$DIR"

major="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$major" -lt 11 ]; then
  warn "macOS $(sw_vers -productVersion): clone Unos (CH340 chip) need the WCH driver before macOS 11:"
  warn "https://www.wch-ic.com/downloads/CH34XSER_MAC_ZIP.html"
fi

# ---------------------------------------------------------------- 1-2. git and the repository
have_git=0
if git --version >/dev/null 2>&1; then have_git=1
elif command -v brew >/dev/null 2>&1; then say "Installing git (Homebrew) ..."; brew install git && have_git=1
else
  warn "git is not available. macOS will offer to install the Command Line Tools: accept, then run this again"
  warn "to switch to git (needed to pull updates and push data). Downloading a ZIP for now."
  xcode-select --install >/dev/null 2>&1 || true
fi
if [ "$have_git" = 1 ]; then
  if [ -d "$DIR/.git" ]; then
    say "Updating $DIR (git pull) ..."
    git -C "$DIR" pull --ff-only || warn "git pull did not fast-forward (local changes?). Continuing with the copy you have."
  elif [ -e "$DIR" ]; then
    echo "$DIR exists but is not a git checkout: rename it or set SERVOLAB_DIR, and run this again." >&2; exit 1
  else
    say "Cloning into $DIR ..."
    git clone "$REPO_URL" "$DIR"
  fi
elif [ -e "$DIR" ]; then
  warn "$DIR already exists: left as it is."
else
  tmp="$(mktemp -d)"
  say "Downloading the repository (ZIP) ..."
  curl -fsSL "$ZIP_URL" -o "$tmp/main.zip"
  (cd "$tmp" && unzip -q main.zip)
  mv "$tmp/rhino-rmcs-2303-dc-servo-control-main" "$DIR"; rm -rf "$tmp"
fi
[ -f "$DIR/setup.m" ] || { echo "The repository in $DIR is incomplete." >&2; exit 1; }

# ---------------------------------------------------------------- 3. Rosetta 2
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = 1 ]; then
  if arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    say "Rosetta 2 present (the AVR compiler runs through it)."
  else
    say "Installing Rosetta 2 (the Arduino AVR compiler is an Intel binary) ..."
    softwareupdate --install-rosetta --agree-to-license \
      || warn "Rosetta 2 not installed. Run: sudo softwareupdate --install-rosetta --agree-to-license"
  fi
fi

# ---------------------------------------------------------------- USB board (information only)
if ls /dev/cu.usbmodem* /dev/cu.usbserial* /dev/cu.wchusbserial* >/dev/null 2>&1; then
  say "Board port(s): $(ls /dev/cu.usbmodem* /dev/cu.usbserial* /dev/cu.wchusbserial* 2>/dev/null | tr '\n' ' ')"
else
  say "No Arduino plugged in yet (fine: plug it in later; the app notices it)."
fi

# ---------------------------------------------------------------- 4. MATLAB
app="$(ls -d /Applications/MATLAB_R20*.app "$HOME"/Applications/MATLAB_R20*.app 2>/dev/null | sort -r | head -1 || true)"
mdir="$DIR"
mdir_q="$(printf '%s' "$mdir" | sed "s/'/''/g")"
echo
if [ "${SERVOLAB_NO_LAUNCH:-0}" = 1 ]; then
  say "Done (MATLAB not started: SERVOLAB_NO_LAUNCH=1)."
elif [ -n "$app" ]; then
  say "Starting $(basename "$app"). It installs the Arduino toolchain the first time (about 60 MB), then opens the lab."
  open -na "$app" --args -r "cd('$mdir_q'); setup open"
else
  warn "MATLAB was not found in /Applications. Install MATLAB R2023b or newer, then in MATLAB run:"
  echo "      cd('$mdir_q'); setup open"
fi
cat <<EOF

Next time: open MATLAB and run   cd('$mdir_q'); setup open
Problems:  in MATLAB run         setup probe
Push recorded data (to a repository you can write to, e.g. your fork):
      git -C "$DIR" add data results && git -C "$DIR" commit -m "data: <what you ran>" && git -C "$DIR" push

EOF
