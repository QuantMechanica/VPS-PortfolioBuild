# MNT-039 remainder: RECYCLE sweeper, canonical identity, aging SLO

Date: 2026-08-21  
Router task: `1d8e74a0-92fe-4937-a51b-cc9fc602e8c5`  
Branch: `agents/board-advisor`  
Status: implementation complete; REVIEW only

## Prerequisite

The named build-gate prerequisite is present as commit `a834b1e20`. No build
gate was weakened. The previously delivered PIPELINE orphan disposition remains
in commit `a08cc8c0c`.

## Spoken sweeper rules

- `APPROVED`: build tasks advance to `PIPELINE`; accepted non-build tasks end in
  `PASSED`; safe-defer verdicts end in `BLOCKED`.
- `PIPELINE`: only real Q10/P8 closing evidence yields `PASSED` or `FAILED`;
  missing EA binding or an EA with no work items yields routing `BLOCKED` without
  inventing a pipeline verdict; genuinely in-flight rows remain unchanged.
- `RECYCLE`: requeue to `TODO` and increment `recycle_count` exactly once per
  review close; at the bounded maximum, park in `BLOCKED`.

All rules are implemented by the existing explicit, dry-run-first
`agent_router.py reconcile-exits` command. Autonomous routing does not silently
apply them.

## Canonical work identity

`tools/strategy_farm/work_identity.py` defines `qm.work_identity.v1` for both
queue namespaces:

- agent parentage follows `agent_tasks.parent_id` to its root;
- append-only farm retries follow
  `payload_json.append_only_rerun_of_work_item` to their root;
- old work-item parent-as-retry links are followed only if the parent resolves
  in the `work_items` namespace, so the ordinary legacy bundled-task parent is
  never conflated with a work item;
- an agent task carrying a known work-item link uses the retry root as its
  stable key; otherwise its root agent-task ID is the stable key.

Applied sweeper transitions now retain the identity object in payload evidence
and add `work_identity_key` to the append-only reconciliation history. Existing
payload fields and prior verdict evidence are preserved.

## Per-class aging SLO

`health.chk_agent_task_aging_slo` is registered in `ALL_CHECKS`, so it is emitted
through `qm.health.contract.v1`. It fails when any `RECYCLE`, `PIPELINE`, or
`BLOCKED` task is older than three days and reports each class separately.

The synthetic fixture proves one stale row in every class fires the alarm. A
live read-only evaluation produced:

```text
status=FAIL value=677 threshold=0
RECYCLE=468 oldest=2026-05-28T21:30:13+00:00
PIPELINE=98 oldest=2026-05-26T13:25:44+00:00
BLOCKED=111 oldest=2026-06-02T21:31:53+00:00
```

This is an alarm over inherited state, not a verdict or automatic disposition.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_mnt039_limbo_contract.py \
  tools/strategy_farm/tests/test_agent_router_state_exits.py \
  tools/strategy_farm/tests/test_mnt035_health_contract.py -q
34 passed in 20.82s

python -m py_compile tools/strategy_farm/work_identity.py \
  tools/strategy_farm/agent_router.py tools/strategy_farm/health.py
PASS

git diff --check -- <MNT-039 implementation/test paths>
PASS
```

Two live dry runs were byte-identical and performed no transition:

```text
python tools/strategy_farm/agent_router.py reconcile-exits --state RECYCLE
apply=false; moved_count=0; would_move RECYCLE->TODO:recycle_requeue=567

second identical run: true
```

No live RECYCLE row was moved, no verdict was overwritten, and no terminal,
AutoTrading, T_Live, backtest, recompile, or pipeline phase was started.
