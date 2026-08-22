# Repair transition-ledger and mass-change visibility

Date: 2026-08-22
Router task: `4fcfbed3-abe6-46ff-8437-434ab00f9758`
Branch: `agents/board-advisor`
Verdict: `PASS_IMPLEMENTED_REVIEW_REQUIRED`

## Outcome

Every current `repair.py` path that changes an existing `work_items.status` now appends an
atomic row to `work_item_transition_ledger`. The ledger row records the exact repair handler,
reason, phase, EA, symbol, old/new status, old/new verdict, old/new claimant, repair run ID,
and transition timestamp. A missing transition-ledger table is fail-closed: the repair rolls
back instead of making an unjournalled status change.

The covered handlers are:

| Handler | Transition |
|---|---|
| `R5_dead_terminal_work_item` | `active -> pending` |
| `R5_stale_active_work_item` | `active -> pending` |
| `R11_pending_unclaimable_work_item` | `pending -> failed/INVALID` |
| `R18_duplicate_pending_q02_work_item` | duplicate `pending -> failed/INVALID` |

The status updates are now compare-and-swap constrained to their expected source status. The
status update and ledger insert commit in the same transaction. `run_all()` rolls back a
handler transaction on any exception, preventing a later handler's commit from accidentally
committing a partially failed repair.

## Low-threshold visibility alarm

The existing R11 limit of 200 remains unchanged and retains its catastrophic-run purpose.
Separately, any one repair handler invocation that commits more than 10 work-item status
transitions now raises `repair_mass_change_alarm` with:

- the repair function and exact handler-name distribution;
- the phase distribution of changed rows;
- transition count, threshold, and repair run ID.

The alarm is appended to `D:/QM/strategy_farm/state/health_alarms.log`, returned in the repair
summary, and appended to `events` as a `repair_run` event. Thus a valid 11-row repair is visible
even though it is nowhere near a catastrophic circuit-breaker limit.

## Incident pre-state confirmed

A read-only live-DB query found 91 exact `COMPILE_EA failed/INVALID` rows carrying both
`payload.repair_handler='R11_pending_unclaimable_work_item'` and
`payload.verdict_reason='ex5_missing'`. Their only matching transition-ledger entry is one
earlier `release_hold` entry for the rollout canary; there is no R11 transition record for any
of the 91 invalidations. The historical payloads and verdicts remain untouched as incident
evidence.

## Other repair mutations not represented by this work-item status ledger

Source audit of every mutation in `repair.py` found these intentionally out-of-scope mutations.
They do not change an existing `work_items.status`, so this task reports rather than silently
expands their governance contract:

- `R2_stranded_active_source`: changes `sources.status`.
- `R3_phantom_codex_review_fail`: deletes a review task/verdict file and may change a build
  task's status.
- `R6_grandchild_setfile`: deletes a work-item row and its setfile rather than transitioning
  the row.
- `R7_stranded_codex_review` and `R8_stranded_ea_review`: delete task rows and optional empty
  verdict files.
- `R9_orphan_g0_claim`: deletes stale claim files.
- `R10_permanent_build_failure`: changes a build task's status.
- `R12_incomplete_p2_parent_fanout`: inserts new pending work-item rows.
- `R13_infra_only_codex_review_failure`: rewrites build-result evidence, changes a build task,
  and deletes stale review tasks.
- `R14_gc_*`: deletes bounded old log/report/prompt/temp files.
- `R15_sparse_q09_portfolio_overlap`: changes an existing work-item verdict and rewrites its
  evidence, but leaves status unchanged.
- `R16_stale_portfolio_candidate`: changes `portfolio_candidates.state`.
- `R17_clear_stale_preflight_work_item`: clears stale work-item payload/evidence metadata but
  leaves status pending.
- `R18_duplicate_pending_q02_work_item`: normalizes the surviving pending row's metadata; only
  the suppressed rows change status and those transitions are now journalled.

If these non-status mutations need durable journals, they require entity-specific contracts
(especially delete tombstones and verdict immutability) rather than pretending they are
work-item status transitions.

## Focused verification

```text
python -m py_compile tools/strategy_farm/repair.py
PASS

python -m pytest \
  tools/strategy_farm/tests/test_repair_transition_visibility.py \
  tools/strategy_farm/tests/test_repair_r11_utility_phase_exemption.py \
  tools/strategy_farm/tests/test_canonical_checkout_guard.py \
  tools/strategy_farm/tests/test_repair_stale_preflight.py -q
21 passed in 1.42s
```

The new tests directly exercise R5, R11, and R18 ledger rows plus an alarm carrying both handler
and phase distributions. No terminal, backtest, setfile, gate verdict, T_Live, or AutoTrading
state was touched.
