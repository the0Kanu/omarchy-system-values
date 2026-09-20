#!/usr/bin/env bash
set -u

# Output records:
# CPU<TAB>model<TAB>temperature<TAB>utilization<TAB>load<TAB>source<TAB>status
# GPU<TAB>index<TAB>model<TAB>temperature<TAB>utilization<TAB>memory-used<TAB>memory-total<TAB>state<TAB>status<TAB>vendor

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-system-values"
log_file="$log_dir/system-values.log"
if ! mkdir -p "$log_dir" 2>/dev/null || ! printf '' >> "$log_file" 2>/dev/null; then
  log_dir="${TMPDIR:-/tmp}/omarchy-system-values"
  log_file="$log_dir/system-values.log"
  mkdir -p "$log_dir" 2>/dev/null || true
fi
if [[ -f "$log_file" && $(stat -c %s "$log_file" 2>/dev/null || echo 0) -gt 524288 ]]; then
  mv -f "$log_file" "$log_file.1" 2>/dev/null || true
fi
log() {
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S%z')" "$1" "$2" >> "$log_file" 2>/dev/null || true
}
format_temp() {
  local raw="$1"
  awk -v raw="$raw" 'BEGIN { if (raw ~ /^[0-9]+$/) printf "%.1f", raw / 1000; else printf "%s", raw }'
}
start_ns=$(date +%s%N 2>/dev/null || date +%s)
  log INFO "status poll started; pid=$$"

cpu_name=$(awk -F: '/^model name[[:space:]]*:/ {sub(/^[[:space:]]*/, "", $2); print $2; exit}' /proc/cpuinfo)
[[ -n "$cpu_name" ]] || cpu_name=$(awk -F: '/^Hardware[[:space:]]*:/ {sub(/^[[:space:]]*/, "", $2); print $2; exit}' /proc/cpuinfo)
[[ -n "$cpu_name" ]] || cpu_name="CPU"

cpu_type=""
cpu_temp=""
for preferred_type in x86_pkg_temp coretemp TCPU_PCI; do
  for zone in /sys/class/thermal/thermal_zone*; do
    [[ -r "$zone/type" && -r "$zone/temp" ]] || continue
    type=$(cat "$zone/type")
    [[ "$type" == "$preferred_type" ]] || continue
    raw=$(cat "$zone/temp")
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
      cpu_type="$type"
      cpu_temp=$(format_temp "$raw")
      break 2
    fi
  done
done

read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
now_total=$((user + nice + system + idle + iowait + irq + softirq + steal))
now_idle=$((idle + iowait))
state_file="$log_dir/cpu.state"
util="--"
state_lock="$state_file.lock"
if exec 9>"$state_lock" 2>/dev/null && command -v flock >/dev/null 2>&1; then
  flock -x 9 2>/dev/null || true
fi
if [[ -r "$state_file" ]]; then
  read -r old_total old_idle < "$state_file" || true
  total_delta=$((now_total - old_total))
  idle_delta=$((now_idle - old_idle))
  if (( total_delta > 0 )); then
    util=$(awk -v busy="$((total_delta - idle_delta))" -v total="$total_delta" 'BEGIN { printf "%.1f", 100 * busy / total }')
  fi
fi
printf '%s %s\n' "$now_total" "$now_idle" > "$state_file"
exec 9>&- 2>/dev/null || true
load=$(awk '{print $1}' /proc/loadavg)

if [[ -n "$cpu_temp" ]]; then
  printf 'CPU\t%s\t%s\t%s\t%s\t%s\tok\n' "$cpu_name" "$cpu_temp" "$util" "$load" "$cpu_type"
  log INFO "CPU detected: model=$cpu_name temp=${cpu_temp}C util=${util}% load=$load source=$cpu_type"
else
  printf 'CPU\t%s\t--\t%s\t%s\t--\terror\n' "$cpu_name" "$util" "$load"
  log WARN "CPU temperature unavailable: model=$cpu_name util=${util}% load=$load"
fi

gpu_index=0
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia_count=0
  while IFS=',' read -r index name temp util mem_used mem_total pstate; do
    name=$(printf '%s' "$name" | xargs)
    [[ -n "$name" ]] || continue
    temp=$(printf '%s' "$temp" | xargs)
    util=$(printf '%s' "$util" | xargs)
    mem_used=$(printf '%s' "$mem_used" | xargs)
    mem_total=$(printf '%s' "$mem_total" | xargs)
    pstate=$(printf '%s' "$pstate" | xargs)
    printf 'GPU\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tok\tNVIDIA\n' "$gpu_index" "$name" "$temp" "$util" "$mem_used" "$mem_total" "$pstate"
    log INFO "NVIDIA GPU detected: index=$index model=$name temp=${temp}C util=${util}% memory=${mem_used}/${mem_total}MiB state=$pstate"
    gpu_index=$((gpu_index + 1))
    nvidia_count=$((nvidia_count + 1))
  done < <(nvidia-smi --query-gpu=index,name,temperature.gpu,utilization.gpu,memory.used,memory.total,pstate --format=csv,noheader,nounits 2>/dev/null || true)
  [[ "$nvidia_count" -gt 0 ]] || log WARN "nvidia-smi is available but returned no GPU data"
fi

# Detect non-NVIDIA display adapters from PCI. NVIDIA devices are already
# reported by nvidia-smi and are therefore excluded here to avoid duplicates.
if command -v lspci >/dev/null 2>&1; then
  other_count=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    name=$(printf '%s' "$line" | sed 's/.*: //')
    [[ -n "$name" ]] || name="GPU"
    temp="--"
    util="--"
    vendor="GPU"
    hwname=""
    if [[ "$name" =~ [Aa][Mm][Dd] ]]; then vendor="AMD"; hwname="amdgpu"; fi
    if [[ "$name" =~ [Ii][Nn][Tt][Ee][Ll] ]]; then vendor="Intel"; hwname="i915"; fi

    for hw in /sys/class/hwmon/hwmon*; do
      [[ -r "$hw/name" ]] || continue
      [[ "$(cat "$hw/name")" == "$hwname" ]] || continue
      for input in "$hw"/temp*_input; do
        [[ -r "$input" ]] || continue
        raw=$(cat "$input")
        if [[ "$raw" =~ ^[0-9]+$ ]]; then temp=$(format_temp "$raw"); break; fi
      done
      break
    done

    for card in /sys/class/drm/card*; do
      [[ -r "$card/device/gpu_busy_percent" ]] || continue
      if [[ "$vendor" == "AMD" && -r "$card/device/vendor" && "$(cat "$card/device/vendor")" == "0x1002" ]]; then
        util=$(cat "$card/device/gpu_busy_percent")
        break
      fi
    done
    printf 'GPU\t%s\t%s\t%s\t%s\t--\t--\t--\tok\t%s\n' "$gpu_index" "$name" "$temp" "$util" "$vendor"
    log INFO "$vendor GPU detected: model=$name temp=${temp}C util=${util}%"
    gpu_index=$((gpu_index + 1))
    other_count=$((other_count + 1))
  done < <(lspci -D 2>/dev/null | rg -i 'VGA compatible controller|3D controller|Display controller' | rg -vi 'NVIDIA' || true)
fi

end_ns=$(date +%s%N 2>/dev/null || date +%s)
log INFO "status poll finished; cpu=1 gpus=$gpu_index duration_ns=$((end_ns - start_ns))"
