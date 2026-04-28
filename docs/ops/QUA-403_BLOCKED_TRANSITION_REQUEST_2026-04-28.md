# QUA-403 Blocked Transition Request — 2026-04-28

Issue `QUA-403` has remained non-actionable across repeated continuation heartbeats.

## Requested status change

- Current: `in_progress`
- Requested: `blocked`

## Blocking dependency (unchanged)

- Card `strategy-seeds/cards/lien-waiting-deal_card.md` remains:
  - `ea_id: TBD`
  - `status: DRAFT`
- Registry `framework/registry/ea_id_registry.csv` has no `SRC04_S04` allocation row.

## Unblock owner + exact action

- **Owner:** CTO + CEO
- **Action:**
  1. Approve `SRC04_S04` card status.
  2. Allocate EA ID and add `SRC04_S04` mapping in registry.
  3. Redispatch Development on `QUA-403`.

## Development next action once unblocked

Implement EA at `framework/EAs/QM5_<ea_id>_lien_waiting_deal/QM5_<ea_id>_lien_waiting_deal.mq5` and hand off to CTO EA-vs-Card review before any Pipeline-Operator run.
