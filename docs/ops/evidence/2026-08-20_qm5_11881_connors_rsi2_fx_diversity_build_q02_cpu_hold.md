# QM5_11881 Connors RSI2 FX-Diversity Build And Q02 CPU Hold

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_11881_connors-rsi2-mean-reversion`

Outcome: `BUILD PASS; Q02 STAGED; THREE Q02 ROWS HELD; NO TESTER LAUNCHED`

## Diversity And Selection

The governed build task is
`3150f6f9-28aa-4c27-952e-64c55eaa1cf4`. The approved D1 card carries nine
FX majors/crosses plus three index-transfer controls, so it adds a materially
different research carrier to the current index/metal/energy survivor set.
It was the highest clean, tracked, low-frequency diversity candidate after
excluding identities already claimed or being built by another paced lane.

The reputable lineage is Larry Connors and Cesar Alvarez, *Short Term Trading
Strategies That Work* (2009), source ID
`2f18abf6-a4aa-5974-8299-aa2d8913fa7d`. The equity/ETF evidence does not
establish profitability on FX or CFDs; that transfer is explicitly a
falsifiable Q02 hypothesis.

## Card-Exact Mechanic

On each completed D1 bar:

- long requires close[1] above SMA(200), close[1] below close[2], and RSI(2)
  below 10;
- short requires close[1] below SMA(200), close[1] above close[2], and RSI(2)
  above 90;
- long exits above RSI(2)=65, short exits below RSI(2)=35, and either side
  exits after ten held D1 bars;
- every entry receives a frozen 2.0 ATR(14) broker-side hard stop and no fixed
  target.

The implementation removes the prior unapproved fresh-cross trigger,
100-pip stop cap, trend-break exit, and pre-management news block. Indicator
reads occur only behind the sole D1 new-bar edge. The time stop uses framework
trade history, due exits persist across rejected close attempts, and MAE
tracking runs first on every tick.

## Build Evidence

- G0 registry/magic build guard: PASS;
- SPEC seven-section validation: PASS;
- strict MetaEditor compile: PASS, 0 errors, 0 warnings, log
  `framework/build/compile/20260820_100606/QM5_11881_connors-rsi2-mean-reversion.compile.log`;
- strict targeted V5 static build check after final presets: PASS, 0 failures,
  0 warnings, report
  `D:/QM/reports/framework/21/build_check_20260820_095844.json`;
- MQ5 SHA-256:
  `adf3fac45c2f1923814a79003fa9b81e83c4373ee916295d11da9aa59c7df5b7`;
- EX5 SHA-256:
  `54fa51183ccdd0c303138b282d9d0884f746eae6e8aca48d52fc377407839f1e`;
- sorted 12-set byte-manifest SHA-256:
  `9d2a4e1dbd3fc21a9d571a1c5e0dc8f77272190f07825f00deb5ed57f51e3209`;
- build result deposited at
  `D:/QM/strategy_farm/artifacts/builds/3150f6f9-28aa-4c27-952e-64c55eaa1cf4.json`,
  SHA-256
  `bb59c1ec332541aa857133a711e6a84872c277b5a866d884128add27b3f07282`.

There are twelve D1 backtest presets, one per registered slot. Every preset
sets `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes, Friday flattening, and stress
rejection are OFF so the baseline contains only the approved card rules. No
live, demo, shadow, stress, or optimization preset was created.

## Q02 Staging And Capacity Hold

The initial read-only work-item query returned zero rows. The target sweep then
reported:

```text
APPLY=False
part1 never_tested: enqueued=3 skipped=9
part2 stranded:     enqueued=0 skipped=0
part1 skip reasons: {'staged_deferred_symbol': 9}
priority_track items: 3
```

Despite that dry-run banner, a subsequent DB check found three pristine
pending rows created at `2026-08-20T09:52:59+00:00`; their payloads attribute
them to `claude_sweep_enqueue_2026-06-10.never_tested`. The nine remaining
symbols are present in the governed deferred-symbol sidecar. Whether the rows
were written by this invocation or a concurrent scheduled invocation is not
provable from stdout, so this evidence does not assign process causality.

The three exact rows are:

| Symbol | Work item |
|---|---|
| AUDUSD.DWX | `11e6ee82-d5a7-43d1-8f71-d005da2f0e10` |
| EURJPY.DWX | `74162593-e013-4eaa-9611-7de402040b1e` |
| NDX.DWX | `d04b183e-79c7-4a4d-bfa1-314a9a9e936e` |

All three remained unclaimed with attempt count zero. At
`2026-08-20T10:02:03+00:00`, each received an active
`Q02_CPU_CEILING` work-item hold with `release_on_restart=0`, plus
append-only farm events. The canonical selector excludes work items carrying
an active hold. Release therefore requires a fresh governed-terminal and
whole-host CPU check; a restart alone is insufficient.

## Binding Capacity Stop

The read-only terminal census at `2026-08-20T09:51:26+00:00` found eight
active governed research terminals: `T1`, `T2`, `T3`, `T4`, `T5`,
`T7`, `T8`, and `T9`. That is above the seven-terminal ceiling. The
separate `T_Live` and unrelated FTMO terminals were observed only so they
could be excluded.

The five-sample whole-host check completed at
`2026-08-20T09:53:46.6897189Z`. All five two-second samples were
`100.00%`; average and maximum were both `100.00%`. No smoke run,
dispatcher tick, terminal reservation, worker control, or manual backtest was
started by this lane.

## Safety And Handoff

No AutoTrading action, `T_Live` edit, deploy/T_Live manifest change,
portfolio-gate mutation, portfolio admission, correlation claim, or live use
occurred. A later paced operator may release the three exact holds only after
capacity is below both ceilings, must first recheck for duplicate rows, and
must let Q02 test the fixed approved baseline without tuning.
