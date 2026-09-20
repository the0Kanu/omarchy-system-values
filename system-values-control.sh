#!/usr/bin/env bash
set -u

# Deterministic local control agent for the Hardware Values plugin.
# Rates the current implementation from 0 to 10.

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$BASE/system-values.sh"
MANIFEST="$BASE/manifest.json"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-system-values/system-values.log"
score=0
details=()

pass() { score=$((score + 1)); details+=("PASS: $1"); }
fail() { details+=("FAIL: $1"); }

if bash -n "$HELPER"; then pass "Helper syntax"; else fail "Helper syntax"; fi
if command -v jq >/dev/null 2>&1 && jq empty "$MANIFEST" && jq empty "$SHELL_CONFIG"; then pass "JSON configuration"; else fail "JSON configuration"; fi

output=$(bash "$HELPER" 2>/tmp/system-values-control.err)
if [[ $? -eq 0 ]]; then pass "Helper execution"; else fail "Helper execution"; fi

cpu_count=$(printf '%s\n' "$output" | awk -F '\t' '$1 == "CPU" {n++} END {print n+0}')
gpu_count=$(printf '%s\n' "$output" | awk -F '\t' '$1 == "GPU" {n++} END {print n+0}')
if [[ "$cpu_count" -eq 1 ]]; then pass "Exactly one CPU detected"; else fail "CPU detection incomplete/duplicated"; fi
if [[ "$gpu_count" -ge 1 ]]; then pass "Available GPU(s) detected"; else fail "No GPU detected"; fi

if [[ -s "$LOG_FILE" ]] && [[ $(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0) -lt 524288 ]]; then
  pass "Runtime log writable and within rotation limit"
else
  fail "Runtime log missing or unreadable"
fi

if [[ -z "$(cat /tmp/system-values-control.err 2>/dev/null)" ]]; then pass "No helper stderr output"; else fail "Helper reported stderr output"; fi

if ! journalctl --user --since "5 minutes ago" --no-pager 2>/dev/null | rg -qi "system-values.*(error|failed)|BarWidget.qml.*error"; then
  pass "No recent Quickshell plugin errors"
else
  fail "Recent Quickshell plugin errors found"
fi

if [[ "$output" == *$'CPU\t'*$'\tok'* ]]; then pass "CPU sensor status valid"; else fail "CPU sensor status invalid"; fi

if [[ "$gpu_count" -eq $(printf '%s\n' "$output" | awk -F '\t' '$1 == "GPU" {print $3}' | sort -u | wc -l) ]]; then
  pass "No duplicate GPU models"
else
  fail "Duplicate GPU models detected"
fi

printf 'BEWERTUNG %s/10\n' "$score"
printf '%s\n' "${details[@]}"
printf 'CPU=%s GPU=%s\n' "$cpu_count" "$gpu_count"

if (( score < 9 )); then exit 1; fi
