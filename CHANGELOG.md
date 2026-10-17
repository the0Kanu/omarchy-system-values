# Changelog

## 1.0.6 — 2026-10-17

- Put notification controls behind a collapsible dropdown in the Hardware Values popup; settings start collapsed and reset on popup open.

## 1.0.5 — 2026-10-15

- Remove the predictable `/tmp` fallback for plugin logs and CPU state; preserve sensor output when persistence is unavailable.
- Validate the private state directory and reject symlink/non-regular log, state, and lock paths.
- Create plugin-owned state files with restrictive permissions and the state directory with mode `0700`.
- Bound `nvidia-smi` queries to five seconds and report failures in the runtime log.
- Add fail-before-fix symlink regression tests and run them through the control agent.
- Harden control-agent temporary stderr handling and distinguish unavailable user journals from a clean journal.
