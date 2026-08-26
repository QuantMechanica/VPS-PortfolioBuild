# QM5_41011 governed compile unblock and enqueue

- Date: `2026-08-26`
- Branch: `agents/board-advisor`
- Build task: `3245e4d6-da72-4d7e-bfb6-c35abe2cb5f3`
- EA: `QM5_41011_tokyo-london-bank-flow-handover`
- Approved review task: `86e63523-90c7-47e7-bd41-b220e70042e7`
- Governed compile work item: `38660d91-9dc6-4e3d-a71e-0f4369dd12a5`

## Selection and collision guard

The deterministic strategy-priority scorer ranked this card first among the
unclaimed pending build backlog (`score=23.20`, diversity contribution `0.143`).
It adds a low-frequency structural FX-session sleeve across `EURJPY.DWX`,
`GBPJPY.DWX`, and `USDJPY.DWX`, rather than adding another index, metal, or
energy build. The build task was claimed atomically with `BEGIN IMMEDIATE` and a
conditional pending/unclaimed update before any mutation. No other active Codex
router task or build dispatch referenced EA 41011 at claim time.

The approved card, active EA-ID row, three active magic rows, repaired source,
SPEC, and three canonical M15 `RISK_FIXED=1000` / `RISK_PERCENT=0` setfiles were
already present. Review task `86e63523-90c7-47e7-bd41-b220e70042e7` closed
`APPROVED` and states that a fresh governed compile is the pending next step.

## Defect and repair

The repaired source and tracked binary do not share a current build identity:

- MQ5 SHA-256: `19eda5c89b952f0e9a0f8f0bdac05387c5bfe14be5332296d3ad1395e0e6d3b7`
- stale EX5 SHA-256: `7a9dcbbc0de4f62ae7f8d2b0c46752f704fa005ee319562fda34c404de20e0a3`

The ordinary compile classifier therefore correctly refused the existing EX5,
bound setfile hashes, and open build task. `compile_work_items.py` was missing
the exact already-approved review/EA authority binding. The repair adds only:

```text
QM5_41011_tokyo-london-bank-flow-handover
  -> router_review_ea:86e63523-90c7-47e7-bd41-b220e70042e7
```

That binding permits one append-only, source-hash-bound `COMPILE_EA` successor.
It grants no Q02, gate, backtest, live, or cross-EA authority. The exact-map
regression test continues to reject a wrong task token and unrelated EA label.

The governed enqueue then created work item
`38660d91-9dc6-4e3d-a71e-0f4369dd12a5`, bound to the MQ5 hash above, all three
JPY-cross symbols, M15, and the fixed-risk contract. Its recorded waived reasons
are exactly `BOUND_SETFILE_HASH_EXISTS`, `BUILD_TASK_EXISTS`, and
`EX5_ALREADY_PRESENT`.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_compile_work_items.py tools/strategy_farm/tests/test_qm5_41011_rework_static.py -q
29 passed in 7.30s

python framework/scripts/validate_spec_doc.py framework/EAs/QM5_41011_tokyo-london-bank-flow-handover
PASS; 1 PASS, 0 FAIL

python tools/strategy_farm/validate_build_guardrails.py --max-news-stale-hours 336 <MQ5 and three setfiles>
PASS; four files, no findings

python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_41011_tokyo-london-bank-flow-handover
PASS; failures=[], warnings=[]

python tools/strategy_farm/raw_mq5_quarantine.py check --source-path <MQ5> --purpose compile --repo-root .
RAW_MQ5_SOURCE_ALLOWED

python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_41011_tokyo-london-bank-flow-handover --fail-on-leak --json
SINGLE_SYMBOL_OK; n_violations=0
```

## Activation boundary

The compile work item is pending under the fail-closed
`COMPILE_EA_WORKER_ROLLOUT_PENDING` hold. Its hold is marked
`release_on_restart=1`; the repository permits release only through a canonical
Factory_ON restart whose fresh OWNER runtime decision names the exact hold set.
The current agent has no authority to manufacture that decision or bypass the
hold. Until the hold is released and the governed worker emits a fresh EX5 PASS,
the build result cannot truthfully claim `compile_succeeded=true`, so Q02 was not
enqueued.

No tester was started, no backtest result or gate verdict was written, no
terminal or factory state was changed, and no file under `T_Live`, no
AutoTrading setting, portfolio gate, or live manifest was touched.

## Next deterministic transition

After the next OWNER-authorized full-fleet restart releases the hold, the worker
must compile work item `38660d91-9dc6-4e3d-a71e-0f4369dd12a5`. On PASS, record a
normal build result for task `3245e4d6-da72-4d7e-bfb6-c35abe2cb5f3`; the standard
`record-build` path will enqueue the liquid `USDJPY.DWX` Q02 canary and defer the
other two JPY crosses under the cohort fanout policy.
