# QM5_41347 NDX.DWX slot — registry row done, governed rebuild blocked (2026-09-19)

Task `fa45d828-8424-45bb-ba61-83cae7e24f82`. DL-089 sibling of QM5_11294; card was amended
2026-09-19 by Fable to add `NDX.DWX` as a second measurement target
(`framework/EAs/QM5_41347_cs-ichi-cloud-opt/docs/strategy_card.md`).

## Done

1. `governed_magic_allocator.py --card` (exact_card, dry-run) refused with
   `active_magic_contract_mismatch:active_magic_row_count_mismatch:expected=2:actual=1`
   (`docs/ops/evidence/2026-09-19_factory_unblock/allocator_dryrun_41347_ndx.json`, pre-existing).
2. Added the registry row exactly as specified by the task payload:
   `41347,cs-ichi-cloud-opt,1,NDX.DWX,413470001,2026-09-19,claude governed slot add,active`
   (`framework/registry/magic_numbers.csv`).
3. Regenerated the resolver: `python framework/scripts/update_magic_resolver.py` ->
   `framework/include/QM/QM_MagicResolver.mqh`, 18362 rows kept, 0 dropped.
4. Verified: `python -m pytest tools/strategy_farm/tests/test_governed_magic_allocator.py
   tools/strategy_farm/tests/test_magic_allocation_precheck.py
   framework/scripts/tests/test_magic_resolver_strict_default.py -q` -> **23 passed**.

## Blocked

Step 2 (append-only source-repair authority + `farmctl enqueue-compile
--source-repair-authority ... ` + `release_compile_wave.py --apply` -> COMPILE_OK) could not be
completed as specified. Full diagnosis in
`QM5_41347_ndx_slot_rebuild_authority.json`. Summary: the QM5_21505 waiver pattern the task cites
as precedent only fires when the current `.mq5` has **no** prior `COMPILE_OK` row for its exact
`(mq5_sha256, ex5_sha256)` pair. QM5_41347's `.mq5` is byte-identical to what already compiled
successfully on 2026-09-05 (work item `245ee112-e9b1-4346-a5b0-82ae91cd039c`) — unlike 21505,
whose `.mq5` content itself had changed. `compile_work_items.classify_candidate` therefore reports
`USABLE_CURRENT_COMPILE_VERDICT_EXISTS`, which is **not** one of the three waivable reasons
(`EX5_ALREADY_PRESENT` / `WORK_ITEMS_EXIST` / `BOUND_SETFILE_HASH_EXISTS`) and short-circuits any
source-repair authority (`source_repair_authorized = repair_authorized and not current_compile_ok`,
`tools/strategy_farm/compile_work_items.py:4967`).

The underlying technical need is real, not a false alarm: `QM_MagicResolver.mqh` is a shared
`#include` whose lookup arrays are baked into the `.ex5` at compile time
(`framework/include/QM/QM_Common.mqh` `QM_MagicChecked`/`QM_FrameworkMagic`). The 2026-09-05
binary's arrays predate today's NDX.DWX/413470001 row, so it cannot resolve that magic at runtime.
`classify_candidate`'s identity model tracks only `.mq5`/`.ex5` hashes, not the resolver file, so
it cannot see this and treats the rebuild as redundant.

I registered a `BACKLOG_SOURCE_REPAIR_REGISTRATIONS` entry in `compile_work_items.py` mirroring the
21505 pattern, confirmed via a read-only `classify_candidate(...)` dry run (no DB writes) that it
does not actually authorize the compile, and **reverted the edit** (`git checkout --
tools/strategy_farm/compile_work_items.py`) rather than commit an inert registration. No
`enqueue-compile` or `release_compile_wave.py --apply` was run. The staged measurement setfile
`docs/ops/evidence/2026-09-19_factory_unblock/staged_41347_ndx/QM5_41347_cs-ichi-cloud-opt_NDX.DWX_H4_backtest.set`
was left in place — moving it now would bind a `build_hash` header to a `.ex5` that does not exist
yet. `farmctl.py service-dl089-matrix` was not re-checked for `ff3325b3` since nothing changed on
the compile side.

## Recommended next step

A proper fix belongs in `classify_candidate`'s identity model (fold the resolver's
`QM_MAGIC_REGISTRY_SHA256` into the staleness check), reviewed by Codex — not an ad hoc Claude-side
bypass of a gate the task payload didn't anticipate. Alternative: OWNER/Codex mints a new named,
OWNER-referenced force-rebuild allowlist entry scoped to exactly QM5_41347 (parallel to
`DL089_FORCE_REBUILD_EA_IDS`), if the one-off route is preferred over a general fix.

## No verdict mutation

Nothing in this session touched a pipeline verdict, the XAUUSD.DWX 1089-cell census evidence, T_Live,
or AutoTrading.
