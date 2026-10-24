# Sourced by the scripts in scripts/setup and scripts/validation (bash, Linux and macOS).
# Same folders as servolab.tools.paths in MATLAB; SERVOLAB_TOOLS overrides the default.
#   SERVOLAB_ROOT   repository root
#   SERVOLAB_CLI    arduino-cli executable of this project
# and exports the ARDUINO_DIRECTORIES_* variables, so arduino-cli and the Arduino IDE
# use this project's own cores and libraries (the global ~/.arduino15 is never touched).
SERVOLAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -z "${SERVOLAB_TOOLS:-}" ]; then
  case "$(uname -s)" in
    Darwin) SERVOLAB_TOOLS="$HOME/Library/Application Support/arduino-lab-tools" ;;
    *) SERVOLAB_TOOLS="$HOME/.local/share/arduino-lab-tools" ;;
  esac
fi
SERVOLAB_CLI="$SERVOLAB_TOOLS/arduino-cli/arduino-cli"
export ARDUINO_DIRECTORIES_DATA="$SERVOLAB_TOOLS/arduino/data"
export ARDUINO_DIRECTORIES_DOWNLOADS="$SERVOLAB_TOOLS/arduino/downloads"
export ARDUINO_DIRECTORIES_USER="$SERVOLAB_TOOLS/arduino/user"
export ARDUINO_UPDATER_ENABLE_NOTIFICATION=false
