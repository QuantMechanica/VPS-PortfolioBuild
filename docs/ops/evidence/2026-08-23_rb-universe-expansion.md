# Evidence — rb-universe-expansion

Date: 2026-08-23

Authority: `OWNER-DEC-13036-XAU` (`decisions/2026-08-23_owner_decisions_evening_batch_2.md:8`)

Status: COMPLETE — dry-run census emitted and first governed tranche appended.

## What changed

- Added the read-only-by-default universe planner and guarded apply path in
  `tools/strategy_farm/universe_expansion.py:76`, `:288`, `:669`, `:740`, and
  `:914`. Apply requires both acknowledgement flags (`:1016-1018`), invokes the
  governed setfile generator, keeps build checks scoped by exact `-EALabel`, and
  writes the farm DB only through `farmctl enqueue-backtest`.
- Added the transactional universe-Q02 enqueue contract in
  `tools/strategy_farm/farmctl.py:19705`. It rejects any existing EA-symbol row
  (`:19914`), carries the exact target symbol/timeframe/setfile, preserves the
  Q02 gate contract, and stamps `UNIVERSE_EXPANSION_LOW_PRIORITY` plus
  `BELOW_ALL_REBASELINE_BACKFILL` (`:19962-19964`).
- Changed pending claim ordering so universe rows rank after ordinary and
  recovery/backfill work (`tools/strategy_farm/farmctl.py:1348-1481`). The
  existing claim-time symbol cap and index-dispatch serialization remain the
  execution controls; this ticket did not change either criterion.
- Added 150 deterministic magic rows at
  `framework/registry/magic_numbers.csv:17866` onward and regenerated the
  resolver to 17,983 rows (`framework/include/QM/QM_MagicResolver.mqh:16-18`).
- Generated exactly the 150 selected backtest setfiles across 16 EAs. The apply
  now snapshots and restores non-selected setfiles around scoped build checks
  (`tools/strategy_farm/universe_expansion.py:740-895`); 300 incidental
  build-hash rewrites were restored and are absent from the final diff.
- Added policy, duplicate, priority, apply-guard, live-factory binding, relevant
  build-contract, worktree-override, and cleanup tests in
  `tools/strategy_farm/tests/test_universe_expansion.py:162-374`.

## Dry-run census

Command:

```text
python tools/strategy_farm/universe_expansion.py --date 2026-08-23
```

Durable outputs:

- `D:/QM/reports/rebaseline/universe_expansion_2026-08-23.csv`
- `D:/QM/reports/rebaseline/universe_expansion_2026-08-23.json`
- `docs/ops/rebaseline/UNIVERSE_EXPANSION_2026-08-23.md`

Result (`docs/ops/rebaseline/UNIVERSE_EXPANSION_2026-08-23.md:17-22`):

- wider active+built cohort: 2,901;
- native-symbol Q02-PASS starting cohort: 992 (921 multi-symbol, 71
  `CARD_SINGLE_SYMBOL`);
- untested candidate pairs: 9,144;
- apply-eligible pairs: 7,174;
- Q02 phase median: 6.5133 hours;
- estimated candidate Q02 terminal-hours: 59,557.615.

Candidate counts by family were FX majors 4,715, indices 4,018, and gold 411.
`SP500.DWX` is admitted from the DWX matrix at
`framework/registry/dwx_symbol_matrix.csv:29`; no private tradability list is
used.

## Governed first tranche

Command:

```text
python tools/strategy_farm/universe_expansion.py --date 2026-08-23 --apply --i-understand-append-only --max-rows 150
```

Receipt:
`D:/QM/reports/rebaseline/universe_expansion_apply_2026-08-23.json`.
The receipt contains all 150 work-item IDs; the same IDs are listed in
`docs/ops/rebaseline/UNIVERSE_EXPANSION_2026-08-23.md:56-61`.

Apply result:

- selected / attempted / enqueued: 150 / 150 / 150;
- ranks: 10 through 195, all multi-symbol cards, deepest native frontier first;
- EAs: 16;
- generated setfiles: 150, generator failures: 0;
- scoped build receipts: 16, relevant magic/setfile contracts passed: 16;
- DB mutation path: farmctl only, with the documented non-canonical override
  scoped to each child process (`tools/strategy_farm/universe_expansion.py:941`);
- runtime-card backups: 16 under
  `D:/QM/reports/rebaseline/universe_expansion_2026-08-23_backups_20260823T184911Z/cards/`.

The live factory stayed on. No terminal was stopped, no factory setting was
changed, and `C:/QM/mt5/T_Live` was not touched. Scoped `-SkipCompile` checks
used a quiescent T1-T10 binding selected at invocation; no EX5 was compiled or
changed.

## Read-only DB reconciliation

Database was opened with `file:...farm_state.sqlite?mode=ro` and
`PRAGMA query_only=ON`. The reconciliation selected the receipt IDs and checked
each `(ea_id, upper(symbol))` identity:

```sql
SELECT * FROM work_items WHERE id IN (<150 receipt ids>);
SELECT count(*) FROM work_items WHERE ea_id=? AND upper(symbol)=?;
SELECT id FROM (<farmctl pending_claim_order_sql()>);
```

Observed after apply:

- receipt IDs / DB rows / distinct pairs: 150 / 150 / 150;
- status: 150 pending; phase: 150 Q02; non-null verdicts: 0;
- `universe_expansion=true`: 150;
- `priority_track=false`: 150;
- `universe_expansion_priority=BELOW_ALL_REBASELINE_BACKFILL`: 150;
- exact single-item `target_symbols=[row.symbol]`: 150;
- exact OWNER decision stamp: 150;
- EA-symbol duplicate anomalies: 0;
- scheduler positions: 3548-3697 of 3697 pending rows — the tranche occupied
  the final 150 positions and therefore cannot starve the rebaseline frontier.

## Tests

Command:

```text
python -m pytest -q tools/strategy_farm/tests/test_universe_expansion.py tools/strategy_farm/tests/test_index_symbol_dispatch_serialization.py tools/strategy_farm/tests/test_farmctl_cascade.py tools/strategy_farm/tests/test_gen_setfile.py tools/strategy_farm/tests/test_build_gate_hardening.py tools/strategy_farm/tests/test_dwx_history_range_filter.py
```

Result: **80 passed, 6 subtests passed in 229.16s**. Full output:
`D:/QM/reports/rebaseline/universe_expansion_tests_2026-08-23.txt`.
`python -m py_compile tools/strategy_farm/farmctl.py
tools/strategy_farm/universe_expansion.py` also passed, as did
`git diff --check`. Resolver verification with
`update_magic_resolver.py --keep-obsolete --dry-run` kept 17,983 rows, dropped
zero, matched the checked-in resolver byte-for-text after newline normalization,
and reported registry SHA prefix `6DB6E053554E0EA5`. All 150 selected active
EA-symbol magic identities resolve to exactly one row.

## Risks and exceptions

- Three of 16 scoped build checks were overall PASS. Thirteen old sources report
  the pre-existing always-on `EA_Q08_MAE_HOOK_MISSING` hardening failure. This
  ticket did not alter those sources or Q08 criteria. All 16 checks completed,
  and all 16 relevant magic/setfile contracts passed; the exact stdout and
  framework report paths are retained in the apply receipt.
- The estimate is terminal-hours derived from the contemporaneous Q02 median,
  not wall-clock completion time. Claim-time symbol caps and serialized index
  dispatch determine actual throughput.
- The 150 DB rows are append-only. They were not run, deleted, requeued, or
  assigned verdicts by this ticket.

## Rollback

Before the enqueue boundary, the planner automatically restores runtime cards,
magic registry/resolver, generated setfiles, and non-selected setfiles from its
timestamped backup directory. After this completed append:

1. Revert the ticket commit to restore repository code, registry/resolver, and
   selected setfiles.
2. Under explicit OWNER rollback authority, restore the 16 runtime cards from
   `D:/QM/reports/rebaseline/universe_expansion_2026-08-23_backups_20260823T184911Z/cards/`.
3. Do **not** delete or overwrite the 150 work items or their verdicts. Any DB
   rollback requires a separate OWNER-authorized append-only cancellation/hold
   procedure referencing the receipt IDs.
