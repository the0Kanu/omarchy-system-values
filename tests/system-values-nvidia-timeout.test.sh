#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/system-values.sh"
root=$(mktemp -d "${TMPDIR:-/tmp}/system-values-nvidia-test.XXXXXX")
trap 'rm -rf -- "$root"' EXIT
mkdir -p "$root/mockbin"
printf '#!/usr/bin/env bash\nsleep 30\n' > "$root/mockbin/nvidia-smi"
chmod 700 "$root/mockbin/nvidia-smi"
start=$(date +%s)
PATH="$root/mockbin:$PATH" XDG_STATE_HOME="$root/state" bash "$SCRIPT" > "$root/output"
end=$(date +%s)
elapsed=$((end - start))
test "$elapsed" -le 8
grep -q 'nvidia-smi query timed out after 5 seconds' "$root/state/omarchy-system-values/system-values.log"
grep -q '^CPU' "$root/output"
printf 'NVIDIA timeout regression passed (%ss)\n' "$elapsed"
