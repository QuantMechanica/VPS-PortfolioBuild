# QM5_20205 Zero-Trades Recovery

Date: 2026-08-03 (Europe/Berlin)

## Classification

`QM5_20205_wti-calmom1` is `TRADE_CAPABLE`, but its canonical Q02 verdict
remains `ZERO_TRADES`. The zero-trade result is a valid no-entry outcome caused
by the available-history/test-window interaction and strict sign disagreement,
not an initialization, artifact-drift, entry-hook, sizing, or broker-order
defect. This recovery does not label the strategy successful or Q02-ready.

## Original Bound Q02 Run

- Work item: `54e53b5e-aa92-4040-97c9-044bdb5cb1c8`.
- Evidence:
  `D:/QM/reports/work_items/54e53b5e-aa92-4040-97c9-044bdb5cb1c8/QM5_20205/20260802_234238/summary.json`.
- Contract: T2, `XTIUSD.DWX`, D1, real ticks/model 4,
  `2018.07.02` through `2022.12.31`, one run, Q02 minimum 25 trades.
- Result: valid report, zero trades, `MIN_TRADES_NOT_MET`; no OnInit failure or
  log bomb.
- Source/deployed EX5 and source/deployed setfile hashes matched and remained
  stable. Original MQ5, EX5, and setfile SHA256 values were respectively:
  `a7c4058f96c678562dae91d367eb9eb4265a1748d61581f9b6c7daa55aa6242f`,
  `7ef489cc58fe33c14e4cb8ac8416b470ce320e4072e8255c09d5d9fd009c7cad`,
  and `16d1dc965f8502068ec3555bd4b3d70ad84de3e9bb3a104f8f13fe0a08699b22`.
- Tester history reported that `XTIUSD.DWX` begins on `2017.10.02`.

## First Failed Layer

Harness and setup identity passed. The first false condition was the strategy
entry decision itself. A continuous diagnostic replay produced 54 monthly
attempt records over the exact Q02 interval:

- 52 attempts: `seasonal_history_invalid` because fewer than the governed five
  same-calendar samples existed;
- November 2022: five samples were valid, but seasonal direction was negative
  while the exact one-month direction was positive;
- December 2022: five samples were valid, but seasonal direction was positive
  while the exact one-month direction was negative; and
- zero `agreement_signal`, entry-fire, or order events in the Q02 interval.

The existing complementary sibling `QM5_20137_wti-seas-pb` independently
traded those same two late-2022 disagreements, corroborating the classification.
Therefore replaying the unchanged canonical Q02 interval would deterministically
produce another zero-trade row and was not enqueued.

## Same-Lineage Diagnostic Repair

Only bounded observability was added:

- one registered `STRATEGY_STATE` event per consumed monthly attempt, including
  sample count, both scores/directions, and an explicit outcome;
- registered `ENTRY_BLOCK` events for spread, ATR, price, stop, and geometry
  rejection paths; and
- one registered `ENTRY_SIGNAL_FIRE` event before framework handoff.

Initialization now records the frozen strategy inputs in the existing `INIT_OK`
payload. The seasonal estimator, one-month return, agreement rule, thresholds,
monthly attempt state, ATR stop, holding period, spread limit, symbol, timeframe,
news state, and risk contract did not change.

Final build evidence:

- Strict compile: PASS, 0 errors and 0 warnings; log
  `C:/QM/repo/framework/build/compile/20260803_000418/QM5_20205_wti-calmom1.compile.log`.
- Strict V5 build check: PASS, 0 failures and 0 warnings; report
  `D:/QM/reports/framework/21/build_check_20260803_000418.json`.
- P1 build validation: PASS; evidence
  `D:/QM/reports/pipeline/QM5_20205/P1/P1_QM5_20205_result.json`.
- SPEC validation: PASS.
- Final MQ5 SHA256:
  `59cbbe1392a550560068fb936c4a79cadb7e41bd805df715d6442f899e9f872a`.
- Final EX5 SHA256:
  `89a759edb05f1e0d142a563cf4ad389482c7a8844951e6f671c6f20732f0f18b`.
- Final setfile SHA256:
  `6cda2708dcf4edcd54f4d21ce85fbfd423e4f6c68c04068d5847d714e3327d8c`.

## Crown-Jewel Trade-Capability Proof

- Summary:
  `D:/QM/reports/recovery/QM5_20205/trade_capable_final/QM5_20205/20260803_000520/summary.json`.
- Contract: T1, `XTIUSD.DWX`, D1, real ticks/model 4,
  `2018.07.02` through `2023.12.31`, `SmokeMode`, minimum one trade.
- Dispatch capacity: 5 of 7 path-anchored factory terminals; the ceiling was
  not reached.
- Result: PASS, one valid run, four trades, no initialization failure, and
  stable source/deployed EX5 and setfile hashes matching the final hashes above.
- Decision events: 66 monthly states: 52 insufficient-history, 10 strict sign
  disagreements, and four agreement signals. The agreement months were January,
  March, May, and November 2023.
- Order path: four `ENTRY_SIGNAL_FIRE`, four `ENTRY_ACCEPTED`, and four `TM_OPEN`
  events; no strategy entry-block events.
- Structured logger snapshot: 1,508 events, exact byte copy, SHA256
  `74844ac46b39cdf310b639227ffa454b86f276558fcd2da05dbd954d81a5daa7`.
- Diagnostic economics only: PF `0.32`, net `-1083.40`, maximal equity drawdown
  `2.97%`. These weak figures are not a promotion verdict and must not be read as
  strategy success.

## Required Recovery Table

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| `QM5_20205` | Q02 `2018.07.02-2022.12.31`; proof `2018.07.02-2023.12.31` | 52/54 Q02 months lacked five same-calendar samples; the two valid months were strict sign disagreements | registered bounded diagnostics only; no economic change | PASS, 0/0 | 4 fires, 4 accepted, 4 opens in proof | 0 Q02; 4 proof | canonical Q02 not passed; frequency, profitability, OOS/stress, costs, data breadth, realized correlation, and portfolio admission remain open |

## Safety

- The canonical backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  and `PORTFOLIO_WEIGHT=1`.
- No `T_Live` path was accessed or edited and AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
- Recovery used only confirmed-free T1 with the evidence-bound smoke runner;
  tester groups restored to canonical SHA256
  `25314333af81faf48e2afe2db5d52beea640cc74ec33a85a46b7c43aadb921dd`.
