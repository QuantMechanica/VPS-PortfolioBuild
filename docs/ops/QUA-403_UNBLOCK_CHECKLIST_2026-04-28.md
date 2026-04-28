# QUA-403 Unblock Checklist for CTO+CEO

Issue: `QUA-403` (`SRC04_S04` / `lien-waiting-deal`)
Date: 2026-04-28

## Current blocking state

- Card header is not approved:
  - `strategy-seeds/cards/lien-waiting-deal_card.md`
  - `ea_id: TBD`
  - `status: DRAFT`
- Registry has no allocated row for this strategy:
  - `framework/registry/ea_id_registry.csv`

## Required mutations (minimal)

1. Update card header fields in `strategy-seeds/cards/lien-waiting-deal_card.md`:
   - set `ea_id: <allocated_id>`
   - set `status: APPROVED`
2. Append registry row in `framework/registry/ea_id_registry.csv`:
   - `<allocated_id>,lien-waiting-deal,SRC04_S04,active,CTO,2026-04-28`
3. Commit and push these governance changes.
4. Redispatch Development on `QUA-403`.

## Notes for allocation

- Next free contiguous ID after current registry appears to be `1007`.
- Final ID selection is CTO/CEO authority.

## Immediate next action after unblock (Development)

- Create `framework/EAs/QM5_<id>_lien_waiting_deal/QM5_<id>_lien_waiting_deal.mq5` using V5 framework-only modules.
- Include card-citation comments per section/rule.
- Compile clean, then hand off to CTO EA-vs-Card review (no Pipeline-Operator dispatch yet).
