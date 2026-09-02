# QM5_41302_mql5-ichimoku-opt - Strategy Spec

**EA ID:** QM5_41302
**Slug:** mql5-ichimoku-opt
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Parent EA:** QM5_10513_mql5-ichimoku
**Parent source:** MQL5 CodeBase (https://www.mql5.com/en/code/20148)
**Author of this spec:** Claude CEO
**Last revised:** 2026-09-02

## 1. Strategy Logic

The EA evaluates completed D1 bars. It opens long when Tenkan-sen crosses up
through Kijun-sen and the completed close is above Senkou Span B. It opens
short when Tenkan-sen crosses down through Kijun-sen and the completed close is
below Senkou Span B. It closes an open position when the opposite signal
appears, otherwise it exits through the ATR hard stop, the fixed 1.5R take
profit, or the framework Friday close. Midpoints are read from completed bars
only (`card_shift + 1`); there is no trailing and one position per symbol/magic.

The derivative adds six optional closed-D1 pattern veto slots: three for buy
entries and three for sell entries. Zero disables a slot, so with all six at
zero the Q02 control is mechanically identical to the approved parent. An
enabled predicate may suppress an entry on its own side; it cannot create a
trade or alter exits, sizing, stop/take geometry, news, or Friday-close
behavior. The pattern reference bar is the last closed D1 bar
(`iTime(_Symbol, PERIOD_D1, 1)`), refreshed once per new D1 bar, and every
entry request is gated through `Pattern_AllowsRequest` immediately before
`QM_TM_OpenPosition`.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| strategy_signal_tf | PERIOD_D1 | Timeframe used for Ichimoku signal reads |
| strategy_tenkan_period | 9 | Lookback for Tenkan midpoint |
| strategy_kijun_period | 26 | Lookback for Kijun midpoint |
| strategy_senkou_b_period | 52 | Lookback for Senkou Span B midpoint |
| strategy_atr_period | 14 | ATR period for the hard stop |
| strategy_atr_sl_mult | 1.5 | ATR multiple for stop distance |
| strategy_tp_rr | 1.5 | Take-profit distance in R multiples |
| strategy_max_spread_points | 0 | Optional spread block; zero disables it |
| strategy_session_enabled | false | Optional time filter; disabled for baseline |
| strategy_session_start_hhmm | 0 | Session start if the optional time filter is enabled |
| strategy_session_end_hhmm | 2359 | Session end if the optional time filter is enabled |
| opt_pp_buy1..3 | 0 | optional buy-side pattern veto predicate IDs |
| opt_pp_sell1..3 | 0 | optional sell-side pattern veto predicate IDs |

The Q02 baseline keeps all six pattern inputs at zero. Pattern discovery is a
later governed measurement and is not part of this build.

## 3. Symbol Universe

| Slot | Symbol | Rationale |
|---:|---|---|
| 3 | XAUUSD.DWX | measurement carrier from the parent's approved R3 basket |

The parent is designed for a DWX FX/metals/index basket; this measurement
instrument is scoped to a single carrier symbol, XAUUSD.DWX. Portfolio
diversification remains a later Q09 claim, not a build assumption.

## 4. Timeframe

The host, signal, pattern-reference, and execution cadence is D1. Ichimoku
midpoints and the pattern reference bar use completed bars only. Entries are
evaluated once per new broker D1 bar.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year | 15-45, central prior 25 |
| Typical hold time | days |
| Entry style | Tenkan/Kijun cross with Senkou Span B close filter |
| Regime preference | trend-confirmation |

The parent inherits no profitability claim; this derivative is a falsifiable
structural port for pattern measurement and inherits none either.

## 6. Source Citation

Derivative source ID: b8b5125a-c67f-5bbc-baff-33456e08f5b2 (same as parent).
Parent source: artem1985 idea, Vladimir Karputov / barabashkakvn MQL5 code,
"Ichimoku", MQL5 CodeBase, published 2018-04-18,
https://www.mql5.com/en/code/20148.

Parent approval and R1-R4 evidence are recorded in
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_10513_mql5-ichimoku.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | RISK_FIXED | USD 1,000 per trade |
| Live | not authorized | n/a |

The backtest preset explicitly fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. It retains the parent's two-axis DXZ news gate and
Friday-close behavior. No live preset, deployment artifact, or portfolio-gate
change is created.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | Approved DL-089 derivative V5 build | CEO order 2026-09-02, pattern instrumentation sibling of QM5_10513 |
