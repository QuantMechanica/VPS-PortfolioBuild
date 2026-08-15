# QM5_41017 Q02 Zero-Trades Classification

Date: 2026-08-16 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: canonical Q02 `ZERO_TRADES`; valid bound run; frozen card mechanic
blocks recovery on the existing lineage

## Classification

The factory-bound Q02 run for `QM5_41017_wti-dom-ctrreg` is valid and
produced zero trades. Harness and setup identity passed. The first failed
layer is the entry hook's card-locked five-minute D1-open grace: the custom
WTI session normally delivered the first tick of a detected D1 bar at about
01:00 broker time, after the EA's `00:00 + 5 minutes` deadline.

This is not Q02 PASS, certification, or a profitability verdict. The current
code implements the approved card literally. Removing or widening the grace,
or redefining the decision as the first tradable session tick, changes the
execution mechanic and therefore requires an explicitly approved new card
variant. No such change, rerun, or re-enqueue was made.

## Original Bound Q02 Run

- Work item: `7eb89f24-8be4-49a0-8b94-5501e124f059`.
- Summary:
  `D:/QM/reports/work_items/7eb89f24-8be4-49a0-8b94-5501e124f059/QM5_41017/20260815_222420/summary.json`.
- Contract: T3, `XTIUSD.DWX`, D1, real ticks/model 4,
  `2018.07.02` through `2022.12.31`, one run, Q02 minimum 25 trades.
- Result: valid 33,422-byte report, zero trades, `MIN_TRADES_NOT_MET`; no
  OnInit failure, non-OK attempt, or log bomb.
- Tester evidence: 100% real ticks, 133,793,281 ticks, 1,164 generated D1
  bars, and history synchronized from 2017-10-02.
- MQ5 SHA-256:
  `2d0ee9baf1d8871647b4a03a7efd2eb5f32271152aac96a4d747356349948df5`.
- Source/staged/deployed EX5 SHA-256:
  `2df104131cb5efe2ca891cd16ee9e824835ef885bc110b28e33a42e3f746e6f2`.
- Source/deployed setfile SHA-256:
  `a5b79da170c3a1b8813b9ec4fb08b7b15ae6b8e3d2c6b3bc2876df2c1128217e`.
- Tester INI SHA-256:
  `9675050110ed154fa6294bc605445db4c2f1217a68d64b0261f84e5e2abc0eba`.
- Report SHA-256:
  `89531ec590f3694f4f846bd2505d1bceb56fa7101b2122df216863b91dce2bec`.
- `run_smoke.ps1` SHA-256:
  `e56a34e4e67fbfe991190f800be3d397bfaa9fb7afce73f2d150e45a6cd9bccd`.
- The source/deployed setfile matched, the deployed EX5 matched the required
  staged binary, and both remained stable through the run.

## First Failed Layer

1. **Harness: PASS.** The report, actual interval, symbol, D1 timeframe,
   model-4 real-tick marker, terminal, runner, and hashes are bound.
2. **Setup: PASS.** Initialization succeeded. The tester log proves the
   locked `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, exact
   day 8/day 26, 252-D1 lookback, five-minute grace, ATR, hold, and spread
   values were deserialized. History covers the requested run plus warm-up.
3. **Entry hook: FAIL at the grace gate.** `QM_EquityStreamOnNewBar()` emits
   one `EQUITY_SNAPSHOT` immediately after each D1-new-bar detection and
   before the entry hook. The exact-byte logger sample contains 1,163 such
   markers: 1,158 at hour 01, three at hour 02, and only two at hour 00.
   There are 76 markers whose broker date is exactly day 8 or day 26. Only
   one is within five minutes of midnight (`2018-07-26 00:00:00`), when the
   tester had only 193 pre-run D1 bars and could not supply the required 253
   completed closes. All 68 exact-date markers in 2019-2022 occur after the
   five-minute deadline. The original build consequently records zero entry
   acceptance, order, or position events.
4. **Order path: NOT REACHED.** No framework entry acceptance, broker
   retcode, fill, or close exists.
5. **Economics: NOT JUDGED.** Zero trades cannot establish the edge or its
   correlation.

The older sibling `QM5_20215_wti-dom-trend`, which uses the same five-minute
WTI D1-open convention, also has a valid Q02 `ZERO_TRADES` row. This is a
two-member corroboration, below the five-member cohort escalation threshold;
no unrelated family-wide repair was opened.

## Repair Boundary

No same-lineage implementation repair exists while the approved rule remains
"first observed tick within five minutes of the D1 bar timestamp." The EA's
`Strategy_EntryWithinGrace()` enforces that rule before consuming the exact
date, and the bound WTI run demonstrates that the executable session normally
starts later.

Any of the plausible remedies changes the authorized entry clock:

- increase `strategy_entry_grace_minutes` beyond the observed session offset;
- remove the grace; or
- anchor the grace to the first tradable WTI session tick instead of the
  nominal D1 timestamp.

Under the zero-trades version rule, those are card-mechanics changes rather
than diagnostics or code corrections. They require a new variant and explicit
OWNER approval. Replaying the unchanged binary and setfile would
deterministically repeat the same blocked entry path, so no duplicate Q02 row
was enqueued.

## Validation And Capacity

- Existing strict Q01 evidence remains PASS with 0 compile errors, 0 compile
  warnings, 0 build-check failures, and 0 build-check warnings:
  `D:/QM/reports/framework/21/build_check_20260815_221224.json`.
- Both deterministic card linters were replayed after enqueue and returned
  `status: ok`.
- The eight-test mechanic reference suite was replayed and passed 8/8. It
  proves the declared rule mapping, not session compatibility.
- A read-only capacity sample at `2026-08-15T22:47:07Z` found four active
  factory terminals (T1, T3, T7, T8), below the ceiling of seven. No recovery
  run was launched because the required correction lacks card authority, not
  because capacity was exhausted.

## Required Recovery Table

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| `QM5_41017` | Q02 `2018.07.02-2022.12.31`, T3, D1/model 4 | card-locked five-minute nominal D1-open grace expires before normal WTI first ticks; the lone in-grace date lacked warm-up | none; a session-aware clock is a new card mechanic | Q01 PASS, 0/0; reference tests 8/8 | 0 accepted/order events | 0 | explicit approval for a new variant; then Q01/Q02, frequency/economics, OOS/stress, costs, realized correlation, and portfolio admission |

## Safety

- The canonical setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- No backtest, tester dispatch, terminal reservation, process control, or
  re-enqueue was performed during classification.
- No `T_Live` file or manifest was changed and AutoTrading was not toggled.
- Neither the portfolio gate nor any deploy manifest was changed.
