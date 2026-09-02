# QM5_41306_bandy-cci-extreme-fade-mr-index-opt - Strategy Spec

**EA ID:** QM5_41306
**Slug:** bandy-cci-extreme-fade-mr-index-opt
**Source:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Parent EA:** QM5_9641_bandy-cci-extreme-fade-mr-index
**Parent source:** Howard Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015
**Author of this spec:** Claude CEO
**Last revised:** 2026-09-02

## 1. Strategy Logic

Daily-close, long-only mean-reversion fade on US equity indices. On each
closed D1 bar, compute `CCI(20)` (Lambert's classic typical-price formula)
and a `SMA(200)` regime filter. Enter long at next session open when
`CCI(20) <= -100` (deeply oversold) AND `close > SMA(200)` (still in a
long-term uptrend — the regime gate keeps the fade out of bear-market
freefalls). A vol-chaos guard skips new entries when `ATR(14)/close` sits in
the top 1st percentile of the trailing 252 closed D1 bars. Exit on the next
closed bar after `CCI(20) >= 0` (back to the zero line) or after 7 trading
days, whichever comes first. Hard stop at `2.5×ATR(14)` from entry.

The derivative adds six optional closed-D1 pattern veto slots: three for buy
entries and three for sell entries (this carrier is long-only, so the sell
slots stay inert while remaining wired symmetrically). Zero disables a slot,
so the Q02 control is mechanically identical to the approved parent. An
enabled predicate may suppress an entry on its own side; it cannot create a
trade or alter exits, sizing, the ATR hard stop, the vol-chaos filter, the
news gate, or the Friday-close behavior.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| strategy_cci_period | 20 | CCI lookback (Lambert typical-price CCI) |
| strategy_entry_cci | -100.0 | Entry threshold: CCI must be at/below this |
| strategy_exit_cci | 0.0 | Exit threshold: CCI zero-line take-profit |
| strategy_regime_sma_period | 200 | Long-only regime filter (close > SMA) |
| strategy_atr_period | 14 | ATR period for stop-loss and vol-chaos filter |
| strategy_atr_stop_mult | 2.5 | Hard SL distance in ATR multiples |
| strategy_time_stop_days | 7 | Max holding period (trading days) before forced exit |
| strategy_vol_lookback_bars | 252 | Lookback window for the vol-chaos percentile filter |
| strategy_vol_percentile | 99.0 | Skip entries when ATR/close sits at/above this percentile |
| opt_pp_buy1..3 | 0 | optional buy-side pattern veto predicate IDs |
| opt_pp_sell1..3 | 0 | optional sell-side pattern veto predicate IDs |

The Q02 baseline keeps all six pattern inputs at zero. Pattern discovery is a
later governed measurement and is not part of this build.

## 3. Symbol Universe

| Slot | Symbol | Rationale |
|---:|---|---|
| 2 | WS30.DWX | Dow 30 measurement carrier for the DL-089 census |

The parent is designed for the US large-cap index basket (SP500.DWX,
NDX.DWX, WS30.DWX). This measurement sibling carries the single WS30.DWX D1
census cell. The EA rejects no additional asset classes beyond the parent's
equity-index scope.

## 4. Timeframe

The host, signal, pattern-reference, holding-period, and execution cadence is
D1. All indicator reads use completed shifts only; entries are considered at
the first tradable tick of a new broker D1 bar under `QM_IsNewBar`. The
pattern-permission reference bar is the last closed D1 bar (shift 1).

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year per symbol | 7 (parent card prior) |
| Typical hold time | 1-7 trading days |
| Entry style | daily-close oversold fade, long-only |
| Regime preference | mean-revert within an uptrend (close > SMA200) |

The parent inherits an informational R1 (TIER_C) and a conservative
frequency prior; this measurement carrier inherits no profitability claim.

## 6. Source Citation

Derivative source ID: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016 (parent source).

Bandy, Howard. *Quantitative Technical Analysis*. Blue Owl Press, 2015,
ISBN 978-0-9791037-7-1.

Derivative approval and R1-R4 evidence are recorded in
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_41306_bandy-cci-extreme-fade-mr-index-opt.md`.
The complete parent rules are recorded in
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_9641_bandy-cci-extreme-fade-mr-index.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | RISK_FIXED | USD 1,000 per trade |
| Live | not authorized | n/a |

The backtest preset explicitly fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. It retains the parent's two-axis DXZ news gate and
Friday-close behavior. No live preset, deployment artifact, or portfolio-gate
change is created.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | Approved DL-089 derivative V5 build | CEO order 2026-09-02, WS30.DWX D1 census carrier |
