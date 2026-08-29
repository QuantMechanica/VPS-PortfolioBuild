# QM5_41197_connors-rsi2-mean-reversion-opt - Strategy Spec

**EA ID:** QM5_41197
**Slug:** connors-rsi2-mean-reversion-opt
**Source:** cd42deaf-3608-581a-b346-a1c9d601bbde
**Parent source:** 2f18abf6-a4aa-5974-8299-aa2d8913fa7d
**Author of this spec:** Codex
**Last revised:** 2026-08-29

## 1. Strategy Logic

On each new D1 bar, the EA reads only the two most recent completed bars. It
buys when the last close is above SMA(200), below the prior close, and RSI(2)
is below 10. It sells when the last close is below SMA(200), above the prior
close, and RSI(2) is above 90.

A long closes when completed-bar RSI(2) rises above 65; a short closes when it
falls below 35. A restart-safe ten-D1-bar time stop is the final rule exit.
Every entry receives a frozen 2.0 times ATR(14) hard stop and no fixed target.

The derivative adds six optional, closed-D1 pattern veto slots: three for buy
entries and three for sell entries. A zero value disables its slot, making the
default profile mechanically identical to the approved parent. An enabled
predicate can suppress an entry on its own side; it cannot create a trade or
alter exits, sizing, or stops.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| strategy_rsi_period | 2 | completed-bar RSI lookback |
| strategy_rsi_long_entry | 10.0 | long oversold threshold |
| strategy_rsi_short_entry | 90.0 | short overbought threshold |
| strategy_rsi_exit_long | 65.0 | long mean-reversion exit |
| strategy_rsi_exit_short | 35.0 | short mean-reversion exit |
| strategy_sma_period | 200 | directional regime filter |
| strategy_atr_period | 14 | completed-bar stop range |
| strategy_atr_sl_mult | 2.0 | frozen ATR hard-stop multiplier |
| strategy_max_holding_bars | 10 | maximum completed D1 holding periods |
| opt_pp_buy1..3 | 0 | optional buy-side pattern veto predicate IDs |
| opt_pp_sell1..3 | 0 | optional sell-side pattern veto predicate IDs |

The Q02 baseline keeps every pattern input at zero. Pattern discovery belongs
to later governed optimization; Q01 does not select a predicate.

## 3. Symbol Universe

| Slot | Symbol | Rationale |
|---:|---|---|
| 0 | GBPUSD.DWX | liquid FX major and approved derivative target |

This derivative is intentionally restricted to GBPUSD.DWX. The single-symbol
host check matches the deterministic registry row, prevents accidental use of
the parent's wider basket, and provides FX diversity against the current
index/metal/energy survivor concentration.

## 4. Timeframe

The exact signal, execution, ATR, pattern-reference, and holding-period
timeframe is D1. Signals use completed bars only and execute at the first
tradable tick of the next D1 bar. There are no multi-timeframe dependencies.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year | approximately 25 |
| Typical hold time | approximately 2-5 D1 bars |
| Maximum hold time | 10 completed D1 bars |
| Regime preference | short-horizon mean reversion inside the SMA(200) regime |

The underlying evidence is equity and ETF based. Transfer to GBPUSD is a
falsifiable pipeline hypothesis, not an inherited profitability claim.

## 6. Source Citation

Derivative source ID: cd42deaf-3608-581a-b346-a1c9d601bbde. Parent source ID:
2f18abf6-a4aa-5974-8299-aa2d8913fa7d.

Larry Connors and Cesar Alvarez, *Short Term Trading Strategies That Work: A
Quantified Guide to Trading Stocks and ETFs* (2009), the 2-Period RSI rule.

The derivative approval and R1-R4 evidence are recorded in
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_41197_connors-rsi2-mean-reversion-opt.md`.
The parent lineage is recorded in
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11881_connors-rsi2-mean-reversion.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | USD 1,000 per trade |
| Live burn-in | RISK_PERCENT | min-lot equivalent under signed manifest |
| Full live after approval | RISK_PERCENT | OWNER-approved portfolio allocation |

Both risk inputs remain user-visible. The backtest setfile explicitly sets
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No live preset
is created. The baseline also disables both framework news axes and Friday
flattening so it measures only the approved card's entry and exit rules.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-29 | Approved derivative V5 build | farm task ce702ad7-9cf9-4c1d-b3f7-1f30510d4114 |
