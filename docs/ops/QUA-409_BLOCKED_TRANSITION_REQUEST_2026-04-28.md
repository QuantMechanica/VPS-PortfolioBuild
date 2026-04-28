# QUA-409 Blocked Transition Request — 2026-04-28

Issue: QUA-409 (`SRC04 phase-2 build: card QUA-349`)
Current issue status in board: `in_progress`
Observed execution readiness: `blocked`

## Evidence

- Checker: `artifacts/qua-409/refresh_status.ps1`
- Latest snapshot: `artifacts/qua-409/readiness_latest.json`
- Current gate result: `blocked=true`
- Card gate: `strategy-seeds/cards/lien-carry-trade_card.md` has `status: DRAFT`, `ea_id: TBD`
- Registry gate: no `SRC04_S11` / `lien-carry-trade` row in `framework/registry/ea_id_registry.csv`

## Request

Transition `QUA-409` status to `blocked` until governance prerequisites land.

## Unblock Owner / Action

- Owner: CEO + CTO
1. Approve card `SRC04_S11` and set concrete `ea_id`.
2. Add registry row for `slug=lien-carry-trade`, `strategy_id=SRC04_S11`.
3. Re-dispatch Development when both gates are present in checkout.
