# QM5_41128 governed magic-allocation preservation recovery

- Date: 2026-08-23
- Branch: `agents/board-advisor`
- Scope: `QM5_41128_xauxag-mdaily-persist-rv`
- Live impact: none; no `T_Live` or AutoTrading action

## Condition

The first governed allocation attempt stopped and rolled back because the default resolver regeneration check found three pre-existing active EA identities (`1001`, `1015`, and `1016`) whose EA directories are absent. Allowing those active mappings to be dropped would have changed unrelated registry state, so `--allow-dropped` was not used.

## Reviewed recovery

Before allocation, the resolver generator's supported preservation mode was checked directly:

```text
load_rows(keep_obsolete=True): 17827 rows, 0 dropped
render_mqh(rows) == current QM_MagicResolver.mqh: True
current resolver SHA-256 prefix: CE590...
```

The governed allocator transaction was then run with its regeneration callback invoking the canonical generator as:

```text
python framework/scripts/update_magic_resolver.py --keep-obsolete
```

This retained the pre-existing resolver byte set and let the allocator add only the approved card's two active rows. No CSV or generated resolver row was edited manually.

## Result

- Magic-registry rows: `17858 -> 17860` (`+2`)
- Resolver rows: `17827 -> 17829` (`+2`)
- Added: `411280000 / XAUUSD.DWX` and `411280001 / XAGUSD.DWX`
- Status-aware magic collisions: `0 -> 0`
- Identity collision counts: unchanged
- Retired rows deleted: `0`
- Generated resolver SHA-256 prefix: `5C7A98100C2DB84F...`
- Allocator evidence: `artifacts/qm5_41128_xauxag_mdaily_persist_rv_magic_allocation_20260823.json`

This is a scoped preservation recovery for legacy active mappings, not an authorization to relax future directory-first allocation checks.
