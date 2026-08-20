# QM5_11881_connors-rsi2-mean-reversion - Strategy Spec

**EA ID:** QM5_11881
**Slug:** connors-rsi2-mean-reversion
**Source:** 2f18abf6-a4aa-5974-8299-aa2d8913fa7d
**Author of this spec:** Codex
**Last revised:** 2026-08-20

## 1. Strategy Logic

On each new D1 bar, the EA reads only the two most recent completed bars. It
buys when the last close is above SMA(200), below the prior close, and RSI(2)
is below 10. It sells when the last close is below SMA(200), above the prior
close, and RSI(2) is above 90.

A long closes when completed-bar RSI(2) rises above 65; a short closes when it
falls below 35. A restart-safe ten-D1-bar time stop is the final rule exit.
Every entry receives a frozen 2.0 times ATR(14) hard stop and no fixed target.
The baseline deliberately adds no crossover trigger, trend-break exit,
stop-distance cap, spread filter, or session filter.

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

The Q02 baseline uses these approved-card values without an optimization
surface.

## 3. Symbol Universe

The approved portable basket and deterministic magic slots are:

| Slot | Symbol | Rationale |
|---:|---|---|
| 0 | EURUSD.DWX | liquid FX major |
| 1 | GBPUSD.DWX | liquid FX major |
| 2 | USDJPY.DWX | liquid FX major |
| 3 | USDCAD.DWX | liquid FX major |
| 4 | USDCHF.DWX | liquid FX major |
| 5 | AUDUSD.DWX | liquid FX major |
| 6 | NZDUSD.DWX | liquid FX major |
| 7 | EURJPY.DWX | liquid FX cross |
| 8 | GBPJPY.DWX | liquid FX cross |
| 9 | NDX.DWX | approved index-transfer test |
| 10 | WS30.DWX | approved index-transfer test |
| 11 | SP500.DWX | canonical S&P 500 backtest alias |

The EA verifies the host symbol against its registered slot before framework
initialization.

## 4. Timeframe

The exact signal, execution, ATR, and holding-period timeframe is D1. Signals
use shifts one and two only and execute at the first tradable tick of the next
D1 bar. There are no multi-timeframe dependencies.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year per symbol | approximately 25 |
| Typical hold time | approximately 2-5 D1 bars |
| Maximum hold time | 10 completed D1 bars |
| Regime preference | short-horizon mean reversion inside the SMA(200) regime |

The source evidence is equity and ETF based; transfer to FX and index CFDs is
a falsifiable Q02 hypothesis, not an inherited profitability claim.

## 6. Source Citation

Source ID: 2f18abf6-a4aa-5974-8299-aa2d8913fa7d.

Larry Connors and Cesar Alvarez, Short Term Trading Strategies That Work - A
Quantified Guide to Trading Stocks and ETFs (2009), the 2-Period RSI rule.

R1 lineage is recorded and R2-R4 are PASS in the approved card:
D:/QM/strategy_farm/artifacts/cards_approved/QM5_11881_connors-rsi2-mean-reversion.md.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | USD 1,000 per trade |
| Live burn-in | RISK_PERCENT | min-lot equivalent under signed manifest |
| Full live after approval | RISK_PERCENT | OWNER-approved portfolio allocation |

Both risk inputs remain user-visible. Backtest setfiles explicitly set
RISK_FIXED=1000, RISK_PERCENT=0, and PORTFOLIO_WEIGHT=1. No live preset is
created by this build. They also disable both framework news axes and Friday
flattening so the Q02 baseline contains only the approved card's entry and
exit rules.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-20 | Card-conformant V5 build | task 3150f6f9-28aa-4c27-952e-64c55eaa1cf4 |
