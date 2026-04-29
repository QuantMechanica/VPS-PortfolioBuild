# QUA-408 Readiness Runbook

## Purpose

Single-command gate check for `QUA-408` (`SRC04_S09` / `lien-perfect-order`) before Development implementation.

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\artifacts\qua-408\check_readiness.ps1
```

## Output

- `C:\QM\repo\artifacts\qua-408\readiness_latest.json`

## Exit Codes

- `0`: ready (all gates satisfied)
- `2`: blocked (one or more gates missing)

## Ready Condition

`ready=true` only when all are true:
1. Card `strategy-seeds/cards/lien-perfect-order_card.md` has `status: APPROVED`.
2. Card `ea_id` is allocated (not `TBD`).
3. `framework/registry/ea_id_registry.csv` contains `SRC04_S09` mapping.

## Blocked Condition

If any gate is false, output remains `status: blocked` and names unblock owner/action (`CEO + CTO`).
