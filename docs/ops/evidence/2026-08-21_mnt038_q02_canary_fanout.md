# MNT-038 Q02 canary-before-fanout evidence — 2026-08-21

Router task: `8d0726d7-0e34-4f73-afc6-a052c4481eaa`

Verdict: **IMPLEMENTED_AND_TESTED**. No factory, terminal, active inventory,
work-item verdict, or live path was mutated during implementation.

## Measured defect

The live health check reported `q02_stranded_exhausted_pairs=275`: each pair had
at least 12 Q02 infrastructure failures, no non-infrastructure terminal
disposition, and no queued successor.

The pre-fix fanout path had two independent expansion mechanisms:

1. `_stage_q02_setfiles()` enqueued up to three symbols immediately.
2. `sweep_enqueue_built_eas.py` promoted every deferred symbol whenever any
   stage-1 symbol passed **or merely when the queue was below 50% capacity**.

The second condition was unrelated to canary evidence, so a deterministic EA or
build defect could consume every symbol in its cohort.

## Implemented contract

Commit `3fa1485a6` installs `qm-q02-canary-fanout/v1`:

- One liquid host is selected deterministically. Priority begins with EURUSD,
  USDJPY, GBPUSD, XAUUSD, SP500, NDX, GDAXI, XTIUSD, and XNGUSD; an unknown
  universe falls back to lexical symbol order.
- All remaining setfiles stay in `q02_deferred_symbols.json` with explicit
  `canary_symbols`, policy, and state.
- `INFRA_FAIL`, `INVALID`, `INVALID_EVIDENCE`, `DRAFT_DEFECT`, or a failed row
  without an economic verdict stops fanout and preserves the deferred cohort as
  `STOPPED` evidence. This includes OnInit and NO_HISTORY/infra outcomes.
- A first `ZERO_TRADES` result promotes exactly one second liquid host as a
  sequential confirmation.
- Two identical zero-trade signatures stop the cohort.
- Any valid economic result, or heterogeneous canary outcomes such as
  `ZERO_TRADES` on one host and `PASS` on another, releases the remainder.
- Open, missing, or unclassified evidence waits; it is never guessed into a
  strategy or pipeline verdict.
- A build failure already prevents `_auto_enqueue_q02_for_build()` from being
  called because Q02 auto-enqueue occurs only after a successful build record.

The old spare-capacity fanout bypass was removed. Queue capacity can delay an
otherwise authorized confirmation/release, but can no longer authorize one.
Existing work items and evidence are append-only and untouched.

## Verification

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_mnt038_canary_fanout.py \
  tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py

14 passed in 5.02s
```

The direct regression suite proves:

- one liquid canary is selected;
- OnInit/infra and failed-without-verdict cases stop;
- a first null signal requests one confirmation;
- two identical null signals stop; and
- a heterogeneous `ZERO_TRADES` + `PASS` strategy releases instead of being
  stopped early.

The apply-mode sweep integration test persists that heterogeneous release,
enqueues the remaining USDJPY setfile with
`promotion_reason=economic_or_heterogeneous_canary`, and removes the completed
deferred state only after the insert succeeds.

Related regression run:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_farmctl_cascade.py \
  tools/strategy_farm/tests/test_auto_build_routing.py \
  tools/strategy_farm/tests/test_levelup_cohort0.py

66 passed, 16 subtests passed in 26.74s
```

No pipeline verdict is asserted by this maintenance change. The pipeline remains
the sole judge of every canary and released cohort row.
