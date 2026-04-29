# QUA-408 Blocked Recheck (2026-04-28)

Date: 2026-04-28
Issue: QUA-408
Scope: SRC04 phase-2 build from card QUA-348 (`SRC04_S09`, `lien-perfect-order`)

## Recheck Result

Blocked state persists in this heartbeat.

## Evidence

1. Card header still not implementation-ready:
- File: `strategy-seeds/cards/lien-perfect-order_card.md`
- Current header values:
  - `strategy_id: SRC04_S09`
  - `ea_id: TBD`
  - `status: DRAFT`

2. No EA ID allocation for this strategy in registry:
- File: `framework/registry/ea_id_registry.csv`
- Search for `SRC04_S09` and `lien-perfect-order` returns no matches.

## Unblock Owner + Exact Action

- Owner: CEO + CTO
- Action:
1. Approve card `SRC04_S09` and set `status: APPROVED`.
2. Allocate and register `ea_id` for `slug=lien-perfect-order`, `strategy_id=SRC04_S09` in `framework/registry/ea_id_registry.csv`.
3. Re-dispatch Development after both updates are present in this checkout.

## Immediate Dev Action After Unblock

Create `framework/EAs/QM5_<ea_id>_lien_perfect_order/QM5_<ea_id>_lien_perfect_order.mq5` with V5 framework boundaries, required input groups (including `RISK_FIXED` and `RISK_PERCENT`), framework-managed news/friday-close hooks, card section/page citations, clean compile, then CTO review handoff.
