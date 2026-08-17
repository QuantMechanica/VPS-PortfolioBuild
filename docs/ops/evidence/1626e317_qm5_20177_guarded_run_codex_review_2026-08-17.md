# QM5_20177 guarded-run follow-up: mandatory Codex review

Date: 2026-08-17 (Europe/Berlin)

- Router review task: `1626e317-5435-4b45-98c0-a5732fbbcc95`
- Gemini source task: `141b8518-0be0-4c1d-87a3-3e8a2f20e14b`
- Source commit: `850855dad56532108cda9d67cc0aa62553a22751`
- Source artifact:
  `docs/ops/evidence/141b8518_qm5_20177_guarded_run_and_cohort_reconciliation_2026-08-17.md`

## Verdict

**RECYCLE: the guarded run was enqueued correctly, but the claimed
full-geometry positive fixture is not physically reachable and the cohort audit
is not reproducible.** Keep both the Gemini task and this review in `REVIEW`.
This review does not approve the code, move it to PIPELINE, amend the Strategy
Card, or supply a pipeline verdict.

## Blocking finding 1: both positive fixtures use impossible OHLC bars

The new simulator accepts the bullish fixture only because its `c2` bar is
impossible: `open=111.0` while `high=109.8`. A valid OHLC bar cannot open above
its high. The bearish positive fixture is also impossible: `open=109.0` while
`low=110.2`, so it opens below its low.

Consequently, the passing test does not establish that a market-reachable bar
sequence can satisfy `touch_ok && confirm_ok && t1_ok`. The 3/3 pytest result is
real, but the acceptance claim drawn from it is not.

## Blocking finding 2: the simulator bypasses the EA's fractal search

`simulate_strategy_entry_signal()` injects `A`, `B`, `C`, `ab_bars`, and
`c_shift` directly. It does not construct a bar window, run an equivalent of
`FindABC()`, or prove that the injected pivots are the three most-recent
alternating fractals that the MQ5 source would select. Thus it models the
post-pivot arithmetic, not the complete `Strategy_EntrySignal` geometry claimed
by the evidence headline.

The required positive regression must use valid OHLC bars and derive the
pivots/shifts from those bars, or use a governed fixture/backtest that exercises
the actual EA path.

## Blocking finding 3: the 255-EA audit cannot be regenerated

Commit `850855dad` adds the JSON inventory, prose evidence, and test changes,
but no audit generator or command. The JSON records keywords and categorical
assertions; it does not preserve the source-matching/classification algorithm
or per-EA source evidence needed to reproduce the claimed whole-repository
result. A machine-readable output without its generator does not support the
headline that all 3,624 EAs were scanned and exactly one defective instance was
proved.

Commit the deterministic generator and exact invocation, then demonstrate that
a fresh run produces the sealed JSON hash.

## Verified clean scope

- The corrected historical Q02 distribution is consistent with the six named
  receipts: USDJPY 8, GBPUSD 6, EURUSD 8, WS30 14, XAUUSD 6, NDX 0; total 42.
- The append-only USDJPY Q02 successor
  `af79d508-0959-4a93-bd2d-f3178a68f633` exists and is `pending`, bound to the
  current EX5. It has no evidence path or verdict yet.
- Current MQ5 SHA-256:
  `25ac3f5d38956c8135f8dafdbf972c493097938aaa29861515cb5ce7fee2db71`.
- Current EX5 SHA-256:
  `8709d1f64dba9509e057e0b33aa1444f25b7f8607ea205ebb754159a78c20796`.
- USDJPY setfile SHA-256:
  `20e75b585034f0af6e1b6c0b3b16aaf9d50c1eb10b2abc3519c999e72fdb584b`.
- `python -m pytest
  tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py -q`:
  3 passed; this confirms the assertions execute, not that the fixtures are
  reachable.
- `python tools/strategy_farm/validate_build_guardrails.py
  framework/EAs/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery`: PASS, no
  findings, maximum stale-news value 336 hours.

## Required next evidence

1. Replace both positive cases with valid OHLC sequences and derive the fractal
   pivots from the sequence instead of injecting them.
2. Preserve a negative macro-swing case proving the guard rejects T1-behind-fill
   geometry.
3. Commit the cohort-audit generator and exact deterministic rerun command.
4. Let the pending Q02 canary finish normally; do not interrupt it or infer its
   result before pipeline evidence exists.
