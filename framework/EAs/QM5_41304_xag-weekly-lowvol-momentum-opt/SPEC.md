# QM5_41304_xag-weekly-lowvol-momentum-opt - Strategy Spec

**EA ID:** QM5_41304
**Slug:** `xag-weekly-lowvol-momentum-opt`
**Source:** 28681f5d-aa78-584e-9698-750d1402e485
**Parent EA:** QM5_21505_xag-weekly-lowvol-momentum
**Parent source:** ZHAO-ST-MOMREV-2026_XAG_S01
**Author of this spec:** Claude CEO
**Last revised:** 2026-09-02

## 1. Strategy Logic

This EA implements a low-frequency silver momentum continuation sleeve on
`XAGUSD.DWX`. At the first D1 bar in each framework broker-week bucket, it
computes the latest completed five-D1 return and the tick-volume sum over the
same five bars. It ranks that sum against 40 earlier, non-overlapping five-bar
tick-volume windows. A rank in the bottom tercile (at or below 33%) permits a
trade in the same direction as the trailing five-bar return (continuation); a
higher volume rank or a zero return stays flat.

The weekly key is persisted before history, news, spread, quote, and order
gates, so a failed attempt cannot retry within the same week. An accepted
entry receives a frozen ATR hard stop and no take-profit. The position exits
after 10 completed D1 bars, upon a signal-flip re-evaluation, at the hard stop,
or through the framework Friday close. There is no trailing stop or scale-in.
Tick volume is an explicit runtime proxy for the source's unavailable
investor-position-derived speculative-flow component (representing the residual
non-flow portion).

The derivative adds six optional closed-D1 pattern veto slots: three for buy
entries and three for sell entries. Zero disables a slot, so the Q02 control is
mechanically identical to the approved parent. An enabled predicate may
suppress an entry on its own side; it cannot create a trade or alter exits,
sizing, ATR stop geometry, news behavior, or Friday-close behavior. Vetoes are
evaluated on the closed D1 reference bar through `QM_PatternPermissionEvaluate`
immediately before order placement and are applied symmetrically to BUY and
SELL requests.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| strategy_vol_lookback | 40 | earlier non-overlapping five-bar volume windows |
| strategy_vol_percentile | 33.0 | maximum empirical tick-volume percentile (low-vol tercile) |
| strategy_atr_period | 14 | completed-D1 ATR period for the hard stop |
| strategy_atr_sl_mult | 2.5 | ATR hard-stop distance |
| strategy_max_hold_bars | 10 | completed D1 bars before time exit |
| strategy_max_spread_points | 250 | entry spread ceiling in points |
| opt_pp_buy1..3 | 0 | optional buy-side pattern veto predicate IDs |
| opt_pp_sell1..3 | 0 | optional sell-side pattern veto predicate IDs |

The Q02 baseline keeps all six pattern inputs at zero. Pattern discovery is a
later governed measurement and is not part of this build.

## 3. Symbol Universe

| Slot | Symbol | Magic | Rationale |
|---:|---|---:|---|
| 0 | XAGUSD.DWX | 413040000 | approved silver low-volume continuation carrier |

The EA rejects every other symbol and timeframe. No external signal feed,
secondary symbol, or basket leg is used.

## 4. Timeframe

The host, signal, pattern-reference, holding-period, and execution cadence is
D1. The calendar gate evaluates the framework `PERIOD_W1` key on new D1 bars.
All signal, volume, ATR, and time-exit inputs use completed D1 bars only. The
attempted week is durably consumed before downstream entry gates, preventing
retry after restart or rejection.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year | about 15-18, research prior 16 |
| Maximum hold time | 10 completed D1 bars |
| Entry style | weekly low-volume-tercile return continuation |
| Direction | symmetric long/short following the trailing five-D1 move |

The source reports commodity-market short-horizon evidence, not XAGUSD
performance. This carrier is a falsifiable structural port and inherits no
profitability claim.

## 6. Source Citation

Derivative source ID: 28681f5d-aa78-584e-9698-750d1402e485 (parent source).

Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. "Momentum and Reversal on
the Short-Term Horizon: Evidence from Commodity Markets." SSRN, 2026,
https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598.

Derivative approval and R1-R4 evidence are recorded in
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_41304_xag-weekly-lowvol-momentum-opt.md`.
The complete parent rules are recorded in
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_21505_xag-weekly-lowvol-momentum.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | RISK_FIXED | USD 1,000 per trade |
| Live | not authorized | n/a |

The backtest preset explicitly fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. It retains the parent's two-axis DXZ news gate and
Friday-close behavior, holds at most one position per magic, uses the V5
framework risk sizing and kill switch, applies a frozen `2.5 * ATR(14,D1)` hard
stop, and fails closed on invalid history, volume, ATR, spread, quote, or stop
data. No live preset, deployment artifact, or portfolio-gate change is created.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | Approved DL-089 derivative V5 build | CEO order 2026-09-02, path-to-25 pattern instrumentation sibling |
