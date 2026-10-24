#!/usr/bin/env bash
# Firmware tests on the PC (g++ only, no Arduino toolchain): the real sketch runs against an
# emulated plant; its output is the protocol transcript the MATLAB tests parse. The build is
# also the real-time emulator (--pty) the end-to-end test talks to.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
echo "== motor firmware against an emulated RMCS-2303 (tests the transcript fixture too)"
g++ -std=c++17 -O1 -w -include algorithm -I"$root/firmware/tests/host_stubs" -o "$tmp/fwtest" "$root/firmware/tests/firmware_host_test.cpp"
"$tmp/fwtest" "$root/firmware/tests/fixtures/firmware_transcript.txt"
# the same build is the real-time emulator the end-to-end test drives through a pty
cp "$tmp/fwtest" "$root/firmware/tests/fwsim"
