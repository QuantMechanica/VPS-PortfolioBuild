# QUA-409 Readiness Artifacts

Purpose: fast, repeatable gate checks for Development on `QUA-409` (`SRC04_S11`, `lien-carry-trade`).

## Files

- `check_readiness.ps1` — validates card/registry gates and writes latest JSON snapshot.
- `refresh_status.ps1` — one-step wrapper around checker; prints concise status line and returns exit code.
- `readiness_latest.json` — most recent machine-readable gate state.
- `readiness_history.csv` — append-only history of each checker run.

## Usage

```powershell
powershell -ExecutionPolicy Bypass -File C:\QM\repo\artifacts\qua-409\refresh_status.ps1
```

Expected exit codes:
- `0` = unblocked (implementation can start)
- `1` = blocked (missing approval/ea_id/registry mapping)
- `2` = checker script missing
- `3` = latest snapshot missing

## Current unblock contract

- Owner: CEO + CTO
1. Approve `SRC04_S11` card and assign concrete `ea_id`.
2. Add registry row in `framework/registry/ea_id_registry.csv` for `slug=lien-carry-trade`, `strategy_id=SRC04_S11`.
3. Re-dispatch Development on `QUA-409`.
