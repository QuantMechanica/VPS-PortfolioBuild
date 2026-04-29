# QUA-338 Unblock Patch Contract (2026-04-28)

Purpose: single-edit unblock for Development P1 implementation on `SRC02_S01`.

## Required Registry Edit

File:
- `framework/registry/ea_id_registry.csv`

Append one row (example schema-conformant shape):

```csv
ea_id,slug,strategy_id,status,owner,created_at
<next_id>,chan-pairs-stat-arb,SRC02_S01,active,CTO,2026-04-28
```

Notes:
- `slug` should remain kebab-case in registry (`chan-pairs-stat-arb`) to match card header.
- EA directory/file slug normalization in code path should use underscore form:
  - `QM5_<ea_id>_chan_pairs_stat_arb/QM5_<ea_id>_chan_pairs_stat_arb.mq5`

## Re-dispatch Payload Needed

After registry commit lands, re-dispatch Development on QUA-338 with:
1. Allocated `ea_id` value.
2. Confirmation that Friday Close waiver from SRC02 S01 approval is accepted for scaffold defaults.
3. Confirmation to proceed with two-leg magic slot convention (`slot`, `slot+1`) in comments and signal scaffold.

## Immediate Post-Unblock Execution (Development)

1. Create EA scaffold in framework path above.
2. Implement required input groups + Strategy module functions.
3. Run strict compile (`framework/scripts/compile_one.ps1 -EAPath <mq5> -Strict`).
4. Commit source + compile evidence paths for CTO review handoff.
