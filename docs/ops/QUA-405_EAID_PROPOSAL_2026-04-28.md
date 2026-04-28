# QUA-405 Registry Allocation Proposal (CTO Ready)

Date: 2026-04-28
Issue: QUA-405
Strategy: `SRC04_S06` (`lien-fader`)

## Current Blocked Facts

- Card in this checkout is still `DRAFT` with `ea_id: TBD`:
  - `strategy-seeds/cards/lien-fader_card.md`
- `framework/registry/ea_id_registry.csv` has no `SRC04_S06` row.

## Proposed Registry Allocation (for CTO execution)

Current highest `ea_id` in this checkout is `1008`, so the next available candidate is `1009`.

Proposed row to append to `framework/registry/ea_id_registry.csv`:

```csv
1009,lien-fader,SRC04_S06,active,CTO,2026-04-28
```

## After Allocation + Card Approval

Development can immediately implement at:

- `framework/EAs/QM5_1009_lien_fader/QM5_1009_lien_fader.mq5`

using V5 framework constraints and then submit to CTO review gate.
