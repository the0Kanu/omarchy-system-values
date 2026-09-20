#!/usr/bin/env bash
set -u

# Deterministischer lokaler Kontrollagent für das Systemwerte-Plugin.
# Bewertet die aktuelle Implementierung von 0 bis 10.

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$BASE/system-values.sh"
MANIFEST="$BASE/manifest.json"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/kanu-system-values/system-values.log"
score=0
details=()

pass() { score=$((score + 1)); details+=("PASS: $1"); }
fail() { details+=("FAIL: $1"); }

if bash -n "$HELPER"; then pass "Helper-Syntax"; else fail "Helper-Syntax"; fi
if command -v jq >/dev/null 2>&1 && jq empty "$MANIFEST" && jq empty "$SHELL_CONFIG"; then pass "JSON-Konfiguration"; else fail "JSON-Konfiguration"; fi

output=$(bash "$HELPER" 2>/tmp/system-values-control.err)
if [[ $? -eq 0 ]]; then pass "Helper-Ausführung"; else fail "Helper-Ausführung"; fi

cpu_count=$(printf '%s\n' "$output" | awk -F '\t' '$1 == "CPU" {n++} END {print n+0}')
gpu_count=$(printf '%s\n' "$output" | awk -F '\t' '$1 == "GPU" {n++} END {print n+0}')
if [[ "$cpu_count" -eq 1 ]]; then pass "Genau eine CPU erkannt"; else fail "CPU-Erkennung unvollständig/dupliziert"; fi
if [[ "$gpu_count" -ge 1 ]]; then pass "Vorhandene GPU(s) erkannt"; else fail "Keine vorhandene GPU erkannt"; fi

if [[ -s "$LOG_FILE" ]] && [[ $(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0) -lt 524288 ]]; then
  pass "Laufzeitlog beschreibbar und unter Rotationslimit"
else
  fail "Laufzeitlog fehlt oder ist nicht lesbar"
fi

if [[ -z "$(cat /tmp/system-values-control.err 2>/dev/null)" ]]; then pass "Keine Helper-Fehlerausgabe"; else fail "Helper meldet Fehler auf stderr"; fi

if ! journalctl --user --since "5 minutes ago" --no-pager 2>/dev/null | rg -qi "system-values.*(error|failed)|BarWidget.qml.*error"; then
  pass "Keine aktuellen Quickshell-Pluginfehler"
else
  fail "Aktuelle Quickshell-Pluginfehler gefunden"
fi

if [[ "$output" == *$'CPU\t'*$'\tok'* ]]; then pass "CPU-Sensorstatus gültig"; else fail "CPU-Sensorstatus ungültig"; fi

if [[ "$gpu_count" -eq $(printf '%s\n' "$output" | awk -F '\t' '$1 == "GPU" {print $3}' | sort -u | wc -l) ]]; then
  pass "Keine doppelten GPU-Modelle"
else
  fail "Doppelte GPU-Modelle erkannt"
fi

printf 'BEWERTUNG %s/10\n' "$score"
printf '%s\n' "${details[@]}"
printf 'CPU=%s GPU=%s\n' "$cpu_count" "$gpu_count"

if (( score < 9 )); then exit 1; fi
