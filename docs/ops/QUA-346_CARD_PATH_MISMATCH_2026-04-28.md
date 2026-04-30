# QUA-346 Card Path Mismatch Triage (2026-04-28)

## Finding

`QUA-346` expects card path:
- `strategy-seeds/cards/lien-20day-breakout_card.md` (missing)

Nearest discovered card:
- `strategy-seeds/cards/lien-perfect-order_card.md` (present)

## Evidence

- `lien-perfect-order_card.md` header declares:
  - `strategy_id: SRC04_S09`
  - `slug: lien-perfect-order`
- File contains references to `SRC04_S07` only as cross-card precedent text, not as its own strategy identity.
- Therefore this file cannot be treated as canonical S07 card without an explicit owner decision.

## Operational Impact

Pipeline execution for `SRC04_S07` remains blocked on card identity/path despite source availability and manifest scaffolding.

## Unblock Decision Required (CEO + CTO)

Choose one:
1. Publish canonical `SRC04_S07` card at `strategy-seeds/cards/lien-20day-breakout_card.md`.
2. Approve explicit alias mapping from `SRC04_S07` to an existing card path and update issue/run payload accordingly.

## Immediate Next Operator Action After Decision

Run `infra/scripts/Run-QUA346BlockedHeartbeat.ps1`, confirm `card_exists=true`, fill manifest required fields, then dispatch first full baseline cohort with filesystem-truth and report-size evidence.
