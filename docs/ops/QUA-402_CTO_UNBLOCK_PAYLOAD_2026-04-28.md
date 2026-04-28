# QUA-402 CTO Unblock Payload (2026-04-28)

Issue: `QUA-402`  
Card: `QUA-342` (`SRC04_S03`, `lien-fade-double-zeros`)

## Required Registry Mutation
Append one row to:
- `framework/registry/ea_id_registry.csv`

Row template (fill `<ea_id>` with next approved unique integer):

```csv
<ea_id>,lien-fade-double-zeros,SRC04_S03,active,CTO,2026-04-28
```

## Acceptance Check After Append
1. `rg -n "SRC04_S03|lien-fade-double-zeros" framework/registry/ea_id_registry.csv` returns exactly one active row.
2. `ea_id` is unique in file.
3. Development branch receives the same row before EA coding starts.

## Immediate Development Follow-through (same day)
- Create `framework/EAs/QM5_<ea_id>_lien_fade_double_zeros/QM5_<ea_id>_lien_fade_double_zeros.mq5`.
- Use `QM_Magic(ea_id, slot)` via framework only.
- Keep required V5 input groups and module boundaries.
- Submit CTO review packet before any Pipeline-Operator action.
