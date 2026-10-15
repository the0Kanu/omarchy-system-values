#!/usr/bin/env bash
set -euo pipefail

SCRIPT="${SYSTEM_VALUES_SCRIPT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/system-values.sh}"
root=$(mktemp -d "${TMPDIR:-/tmp}/system-values-state-test.XXXXXX")
trap 'rm -rf -- "$root"' EXIT

# If XDG state is unavailable, predictable TMPDIR symlinks must not be followed.
mkdir -p "$root/fallback/omarchy-system-values"
printf 'log sentinel\n' > "$root/fallback/log-target"
printf 'state sentinel\n' > "$root/fallback/state-target"
ln -s "$root/fallback/log-target" "$root/fallback/omarchy-system-values/system-values.log"
ln -s "$root/fallback/state-target" "$root/fallback/omarchy-system-values/cpu.state"
before_log=$(sha256sum "$root/fallback/log-target")
before_state=$(sha256sum "$root/fallback/state-target")
XDG_STATE_HOME=/proc/issue-7720 HOME="$root/home" TMPDIR="$root/fallback" bash "$SCRIPT" > "$root/fallback-output"
test "$before_log" = "$(sha256sum "$root/fallback/log-target")"
test "$before_state" = "$(sha256sum "$root/fallback/state-target")"
grep -q '^CPU' "$root/fallback-output"

# Normal operation retains private persistent log and CPU state.
XDG_STATE_HOME="$root/normal-state" HOME="$root/home" TMPDIR="$root/fallback" bash "$SCRIPT" > "$root/normal-output"
state_dir="$root/normal-state/omarchy-system-values"
test -f "$state_dir/system-values.log"
test -f "$state_dir/cpu.state"
test "$(stat -c %a "$state_dir")" = 700
test "$(stat -c %a "$state_dir/system-values.log")" = 600
test "$(stat -c %a "$state_dir/cpu.state")" = 600

# Reject a pre-existing log symlink in the validated private state directory.
mkdir -p "$root/log-link-state/omarchy-system-values"
printf 'log sentinel\n' > "$root/log-link-target"
ln -s "$root/log-link-target" "$root/log-link-state/omarchy-system-values/system-values.log"
before_log_link=$(sha256sum "$root/log-link-target")
XDG_STATE_HOME="$root/log-link-state" HOME="$root/home" bash "$SCRIPT" > "$root/log-link-output"
test "$before_log_link" = "$(sha256sum "$root/log-link-target")"
grep -q '^CPU' "$root/log-link-output"

# Reject a pre-existing CPU-state symlink without disrupting log/output.
mkdir -p "$root/state-link-state/omarchy-system-values"
printf 'state sentinel\n' > "$root/state-link-target"
ln -s "$root/state-link-target" "$root/state-link-state/omarchy-system-values/cpu.state"
before_state_link=$(sha256sum "$root/state-link-target")
XDG_STATE_HOME="$root/state-link-state" HOME="$root/home" bash "$SCRIPT" > "$root/state-link-output"
test "$before_state_link" = "$(sha256sum "$root/state-link-target")"
grep -q '^CPU' "$root/state-link-output"

echo 'system-values state-path security tests passed'
