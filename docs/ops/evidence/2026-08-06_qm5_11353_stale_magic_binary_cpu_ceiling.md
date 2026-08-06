# QM5_11353 stale-magic binary diagnosis at CPU ceiling

Date: 2026-08-06

Branch: `agents/board-advisor`

Operator: Codex paced fleet

## Outcome

No build, compile, backtest, enqueue, or farm-state mutation was performed. The
factory was already at the mission stop condition, and `QM5_11353` itself still
had active and pending Q02 work. Mutating its binary or adding more rows would
have collided with the paced workers.

This evidence isolates the current Q02 failure as a stale compiled-magic
registry defect, not an economic failure or missing history. The next
below-ceiling recovery wake should let every existing `QM5_11353` row drain,
strict-compile the EA once against the current resolver, and use only the
governed append-only Q02 repair path for any failed cross that has no open
duplicate.

## Backlog and collision guard

The seven nominally pending `build_ea` tasks in the farm were not clean
low-frequency diversity builds: they carried durable data/card blockers,
exhausted review-rework terminal markers, a missing card, or the excluded
high-frequency FX hang. The mission therefore inspected priority 2.

At `2026-08-06T20:55Z`, the authoritative farm DB showed ten active work items
across `T1` through `T10`. Three were Q09_NEWS cells and seven were Q02 rows.
The MT5 process scan also showed eight running factory terminals plus the
separate T_Live and FTMO terminals. This is the backtest CPU ceiling, so the
mission's explicit stop rule applied.

`QM5_11353` was not claimed for repair because its own Q02 fanout was live:

- `fba093af-0d8e-43de-a6dc-e680476d606e` — `EURNZD.DWX`, active on `T4`
- `04f1e36d-a087-488f-a4f4-670395032b4e` — `GBPAUD.DWX`, active on `T7`
- nineteen additional Q02 rows were pending at the same snapshot

The worktree also contained unrelated fleet edits, all left untouched.

## Deterministic diagnosis

The active registry contains 28 `QM5_11353` magic rows, slots `0..27`. The
checked-in resolver at HEAD contains all 28 corresponding magic literals
`113530000..113530027`. The current EA source and binary are:

- MQ5 SHA-256: `c42e5eaed8e6606210f879e27a26bae6d029947682b512055f278030931801c8`
- EX5 SHA-256: `53d767f23e4425293627e80ef574c334002ece126c5043262cffa8c0376ec355`
- EX5 last write: `2026-06-30T13:30:02Z`

Fresh Q02 evidence proves the tester synchronized usable history, loaded the
correct slot from the canonical RISK_FIXED setfile, and then rejected that slot
inside the old binary:

- `a93f81ad-ab1b-4c13-b090-4d257a4e0af0`, `EURJPY.DWX`, summary
  `D:/QM/reports/work_items/a93f81ad-ab1b-4c13-b090-4d257a4e0af0/QM5_11353/20260806_204537/summary.json`:
  history synchronized, setfile supplied `qm_magic_slot_offset=15`, then
  `EA_MAGIC_NOT_REGISTERED: ea_id=11353 slot=15 magic=113530015` and OnInit
  returned code 1.
- `cff6cbf8-f510-400b-95b7-68fedd5a109b`, `NZDCHF.DWX`, summary
  `D:/QM/reports/work_items/cff6cbf8-f510-400b-95b7-68fedd5a109b/QM5_11353/20260806_204709/summary.json`:
  history synchronized, setfile supplied `qm_magic_slot_offset=23`, then
  `EA_MAGIC_NOT_REGISTERED: ea_id=11353 slot=23 magic=113530023` and OnInit
  returned code 1.

The same EX5 previously passed Q02 on original slots `1` and `2` (`GBPUSD.DWX`
and `USDJPY.DWX`). The slot-dependent split, synchronized history, exact binary
binding, and current resolver membership jointly identify a binary compiled
before the later cross-pair slot expansion. Re-importing history or changing
strategy mechanics would not repair it.

## Safe next action

After the CPU ceiling clears and every `QM5_11353` Q02 row is no longer
pending/active:

1. Verify the active registry/resolver still contains slots `0..27` and the EA
   path is clean.
2. Run one strict compile of
   `QM5_11353_rbt-cci14-zone-cross-h1.mq5`; do not change the strategy.
3. Run build/spec/guardrail validation and record the new EX5 SHA-256.
4. For each retained `INFRA_FAIL` cross with no open duplicate, use
   `farmctl.py enqueue-backtest --phase Q02 --append-only-rerun-of ...` bound
   to that new EX5 hash. Do not reset or overwrite historical rows.

No `T_Live`, AutoTrading setting, live manifest, portfolio gate, deploy
manifest, or live setfile was touched.
