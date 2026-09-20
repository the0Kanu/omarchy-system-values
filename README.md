# Omarchy Systemwerte

Ein universelles Omarchy-Bar-Plugin für automatisch erkannte CPU- und GPU-Werte.

## Funktionen

- CPU-Modell, Temperatur, Auslastung und Load Average
- NVIDIA-GPUs über `nvidia-smi`
- Intel-, AMD- und weitere PCI-GPUs über `lspci`/sysfs
- Temperatur, Auslastung, Speicher und P-State, sofern der Treiber diese Werte bereitstellt
- Nur tatsächlich erkannte Komponenten werden angezeigt
- Laufzeitlog mit Zeitstempeln und Rotation bei 512 KiB
- Kontrollagent mit Bewertung von 0 bis 10
- Keine Änderungen an Treibern oder Systemdiensten

## Installation

Direkt aus GitHub installieren und aktivieren:

```bash
omarchy plugin add https://github.com/the0Kanu/omarchy-system-values --enable
```

Falls das Plugin in einen bestimmten Bar-Bereich verschoben werden soll:

```bash
omarchy bar move user.system-values --section right
```

Die Installation legt das Plugin automatisch unter
`~/.config/omarchy/plugins/user.system-values/` ab und aktiviert es in der
Omarchy-Shell.

## Entfernung

```bash
omarchy plugin remove user.system-values
omarchy restart shell
```

Voraussetzungen: `bash`, `awk`, `sed`, `lspci` und optional `nvidia-smi` für NVIDIA-Werte.

## Debugging

Das Laufzeitlog liegt standardmäßig unter:

```text
~/.local/state/omarchy-system-values/system-values.log
```

Manueller Status-Test:

```bash
~/.config/omarchy/plugins/user.system-values/system-values.sh
```

Kontrollagent:

```bash
~/.config/omarchy/plugins/user.system-values/system-values-control.sh
```

Der Kontrollagent prüft Syntax, JSON, Hardware-Erkennung, Logsystem,
Quickshell-Fehler und doppelte Komponenten. Zielwert ist mindestens 9/10.

## Lizenz

MIT. Siehe `LICENSE`.
