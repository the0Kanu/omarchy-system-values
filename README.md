# Omarchy Hardware Values

A universal Omarchy bar plugin for automatically detected CPU and GPU values.

## Features

- CPU model, temperature, utilization and load average
- Temperature and utilization with one decimal place where raw data allows it
- NVIDIA GPUs via `nvidia-smi`
- Intel, AMD and other PCI GPUs via `lspci`/sysfs
- Temperature, utilization, memory and performance state when supported by the driver
- Only detected hardware components are displayed
- Runtime logging with timestamps and 512 KiB rotation
- Hardware warnings through Omarchy notifications with a 5-second timeout
- Concurrent status queries synchronized with a state-file lock
- Standard refresh interval: 10 seconds; right-click for a manual refresh
- No changes to drivers or system services

## Installation

Install and enable directly from GitHub:

```bash
omarchy plugin add https://github.com/the0Kanu/omarchy-system-values --enable
```

To place the widget in a specific bar section:

```bash
omarchy bar move user.system-values --section right
```

The plugin is installed at `~/.config/omarchy/plugins/user.system-values/`.

## Removal

```bash
omarchy plugin remove user.system-values
omarchy restart shell
```

Requirements: `bash`, `awk`, `sed`, `lspci`, and optionally `nvidia-smi` for NVIDIA metrics.

## Debugging

The runtime log is stored at:

```text
~/.local/state/omarchy-system-values/system-values.log
```

Manual status test:

```bash
~/.config/omarchy/plugins/user.system-values/system-values.sh
```

Control agent:

```bash
~/.config/omarchy/plugins/user.system-values/system-values-control.sh
```

The control agent checks syntax, JSON, hardware detection, logging,
Quickshell errors and duplicate components. The target score is at least 9/10.

## License

MIT. See `LICENSE`.
