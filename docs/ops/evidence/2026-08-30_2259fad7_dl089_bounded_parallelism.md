# DL-089 bounded cross-program parallelism

Date: 2026-08-30
Router task: `2259fad7-3598-4e54-a0ae-dab475499097`
Branch: `agents/board-advisor`
Status: implementation verified; staged live observation pending

## Scope and invariants

The implementation changes only cross-program interleaving:

- `DL089_PROGRAM_SLOTS` defaults to 4, is bounded to 1..10, and K=1 is the
  immediate serialization rollback;
- one active `OPT_CENSUS` cell is allowed per governed program; the existing
  `(ea_id, symbol)` duplicate guard remains earlier than pruning;
- terminal avoidance, launch cooldown, active-pair, symbol-cap, Q04,
  multisymbol, commit, RAM, long-run, hold, and Factory-OFF admission remain in
  force before the pruning preflight;
- pruning deferral is candidate/program-head scoped, and the pruning lock is
  keyed by the program identity; the pending-row/payload fingerprint CAS is
  retained;
- the matrix service maintains the first K candidates in canonical
  `_queue_order`, each with its own eight-cell priority window, and reports
  `slot_owners` plus `PROGRAM_SLOT_WAIT:K=<K>` deferrals;
- same-program order and single-cell execution are preserved. There is no
  same-program parallelism;
- DL-089 cell definitions, authenticated declarations, 154 declared trials,
  activity floor, pruning amendment, walk-forward rules, and selection rules
  are unchanged.

The generic aggregate lookup now classifies a Q12 parent found in `work_items`
as `parent_managed_in_work_items` instead of emitting the misleading
`parent_missing` result intended for the unrelated `tasks` namespace.

## Replay-equivalence proof

The sealed fixture
`tools/strategy_farm/tests/fixtures/dl089_program_replay_fixture.json` was
replayed under K=1 and K=4 scheduling. Global traces differ, proving actual
interleaving, while the canonical per-program output is byte-identical. The
comparison covers terminal dispositions, pruning receipts with timestamps
exempted, selected cells, and evidence hashes.

Durable output:
`docs/ops/evidence/2026-08-30_2259fad7_dl089_replay_equivalence.json`.

## Verification before activation

```text
224 passed, 4 subtests passed in 82.07s
```

This is the complete local set matching `test_terminal_worker*.py`,
`test_dl089_matrix_service.py`, `test_opt_census*.py`, the parent reconciliation
suite, and the replay suite. An earlier aggregate run had one transient Windows
lock handoff failure in an existing five-thread contention test; the failed
test and all three new scheduling tests passed together on immediate isolated
rerun (`4 passed`). `compileall` and explicit `git diff --check` passed.

## Staged activation plan (documented before live activation)

1. Commit code, tests, replay output, and this plan on `agents/board-advisor`.
2. Let the normal governed matrix service expose the first four canonical
   owners and their independent eight-cell windows. Do not invoke apply-mode
   service outside its scheduled path.
3. Reload only idle resident workers through the existing governed worker
   starter. Never stop an active T1-T10 backtest and never start
   `terminal64.exe` manually.
4. Observe the live database read-only. Acceptance requires at least two
   distinct programs simultaneously active, no duplicate `(ea_id, symbol)`
   pair, no program with more than one active cell, and no admission-gate
   bypass.
5. Continue ordinary service only after that invariant snapshot. Any anomaly
   triggers K=1 rollback before code rollback.

## Rollback

Immediate: set `DL089_PROGRAM_SLOTS=1` in the governed worker/service
environment and allow the normal worker cadence to converge; do not terminate
active tests. Code rollback: revert the implementation commit, again allowing
active work to finish. Neither rollback changes ledgers, cells, receipts,
selection state, or terminal verdicts.

## Live observation

Pending after the implementation commit and governed activation. This section
will record the read-only concurrent-program and duplicate-pair snapshot.
