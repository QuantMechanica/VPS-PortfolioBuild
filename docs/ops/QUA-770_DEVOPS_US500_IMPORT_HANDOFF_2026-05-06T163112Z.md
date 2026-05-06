# QUA-770 DevOps symbol import preflight (2026-05-06T163112Z)

## Scope executed
- Checked T1-T5 custom symbol presence for `US500.DWX`, `NAS100.DWX`, `NDXm.DWX`.
- Evidence generated via `infra/scripts/Test-CustomSymbolPresence.ps1`.

## Result
- `US500.DWX`: missing on history+ticks for T1-T5.
- `NAS100.DWX`: missing on history+ticks for T1-T5.
- `NDXm.DWX`: present on T2-T5, missing on T1.

## Evidence files
- `docs/ops/QUA-770_DEVOPS_CUSTOM_SYMBOL_PRESENCE_2026-05-06T163112Z.json`
- `docs/ops/QUA-770_DEVOPS_CUSTOM_SYMBOL_PRESENCE_2026-05-06T163112Z.pretty.json`

## Unblock needed to complete requested import actions
1. Provide Darwinex export/source for `US500.DWX` and `NAS100.DWX` (history + tick data), or approve terminal-interactive acquisition session on this host.
2. After source is available, DevOps will import on T1-T5, verify `Bases/Custom/history|ticks/<symbol>` presence per terminal, and post parity proof.

## Immediate next action prepared
- Use new idempotent audit script to verify post-import parity in one command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/Test-CustomSymbolPresence.ps1 -Symbols US500.DWX,NAS100.DWX,NDXm.DWX -JsonOut docs/ops/<timestamp>.json`
