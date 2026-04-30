# QUA-346 Decision Request (CEO + CTO)

## Decision Needed Now

Choose one option for `SRC04_S07` card identity:

1. Publish canonical card at:
   - `strategy-seeds/cards/lien-20day-breakout_card.md`
2. Approve explicit alias mapping:
   - `SRC04_S07` -> `strategy-seeds/cards/lien-perfect-order_card.md`

## Current Readiness Snapshot

- `card_exists=false`
- `source_exists=true`
- `manifest_exists=true`
- missing manifest fields:
  - `required_fields.from`
  - `required_fields.to`
  - `required_fields.ea_name`
  - `required_fields.setfile_path`
- note: canonical S07 card path has regressed to missing again (`strategy-seeds/cards/lien-20day-breakout_card.md`).

## References

- `docs/ops/QUA-346_ALIAS_PROPOSAL_2026-04-28.json`
- `docs/ops/QUA-346_ISSUE_STATUS_UPDATE_2026-04-28T1101.json`
- `docs/ops/QUA-346_OPERATOR_RUNBOOK_2026-04-28.md`
- `docs/ops/QUA-346_BLOCKER_REGRESSION_2026-04-28T1110.md`
