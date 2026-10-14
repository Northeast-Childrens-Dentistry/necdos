#!/usr/bin/env bash
# Run: bash tests/necd-update-reboot.test.sh
set -euo pipefail
script=$(realpath "$(dirname "$0")/../system_files/usr/libexec/necd-update-reboot")
stub=$(mktemp -d); trap 'rm -rf "$stub"' EXIT

# run <bootc-json> <sessions-json> [bootc-exit] -> prints reboot|none
run() {
  printf '%s' "$1" > "$stub/bootc.json"; printf '%s' "$2" > "$stub/sessions.json"
  printf '#!/bin/sh\ncat %s/bootc.json\nexit %s\n' "$stub" "${3:-0}" > "$stub/bootc"
  printf '#!/bin/sh\ncat %s/sessions.json\n' "$stub" > "$stub/loginctl"
  printf '#!/bin/sh\necho "$@" >> %s/log\n' "$stub" > "$stub/systemctl"
  chmod +x "$stub/bootc" "$stub/loginctl" "$stub/systemctl"; : > "$stub/log"
  PATH="$stub:$PATH" bash "$script" >/dev/null 2>&1 || true
  grep -q reboot "$stub/log" && echo reboot || echo none
}
staged='{"status":{"staged":{"image":{}}}}'
idle='{"status":{"staged":null}}'
[[ $(run "$idle" '[]') == none ]]                         || { echo "FAIL no-staged"; exit 1; }
[[ $(run "$staged" '[{"class":"user"}]') == none ]]       || { echo "FAIL user-session"; exit 1; }
[[ $(run "$staged" '[{"class":"greeter"}]') == reboot ]]  || { echo "FAIL greeter-only"; exit 1; }
[[ $(run "$staged" '[]') == reboot ]]                     || { echo "FAIL no-sessions"; exit 1; }
[[ $(run "$staged" '[]' 1) == none ]]                     || { echo "FAIL bootc-error"; exit 1; }
echo PASS
