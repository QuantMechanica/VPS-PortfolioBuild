# QM5_11302_tc-m5-bb-stoch-extreme-reversal — Strategy Spec

**EA ID:** QM5_11302
**Slug:** tc-m5-bb-stoch-extreme-reversal
**Framework:** QuantMechanica V5
**Approved card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11302_tc-m5-bb-stoch-extreme-reversal.md`

## 1. Strategy Logic

Evaluate closed M5 bars and enter at the next bar after an extreme-momentum breach followed by a one-bar pullback.

Long entry requires bar 2 to close above Bollinger Bands(20,2) upper band with Stochastic(5,3,3) %K above 80, and bar-2/bar-3/bar-4 highs to form consecutive higher highs. Bar 1 must then be bearish (`Close < Open`). Short entry is symmetric: bar 2 closes below the lower band with %K below 20, the three lows are successively lower, and bar 1 is bullish.

Only one position per EA magic and symbol is allowed. Each position uses a fixed 20-pip stop and 10-pip take profit. There is no discretionary strategy exit. Entries have a three-pip spread cap and no session restriction. Framework news, Friday-close, kill-switch, and position-management controls remain authoritative.

## 2. Parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `strategy_timeframe` | M5 | Signal timeframe |
| `strategy_bb_period` | 20 | Bollinger Band period |
| `strategy_bb_deviation` | 2.0 | Bollinger Band deviation |
| `strategy_stoch_k` | 5 | Stochastic %K period |
| `strategy_stoch_d` | 3 | Stochastic %D period |
| `strategy_stoch_slowing` | 3 | Stochastic slowing |
| `strategy_stop_pips` | 20 | Fixed initial stop |
| `strategy_tp_pips` | 10 | Fixed take profit |
| spread cap | 3 pips | Maximum entry spread |

## 3. Symbol Universe

- `EURUSD.DWX` — approved major FX symbol, magic slot 0.
- `GBPUSD.DWX` — approved major FX symbol, magic slot 1.
- `USDJPY.DWX` — approved major FX symbol, magic slot 2.

No other symbol is authorized by the approved card.

## 4. Timeframe

M5 only. The breach/trend conditions use closed bars 2–4, the pullback uses closed bar 1, and entry is submitted after bar 1 closes.

## 5. Expected Behaviour

The card expects approximately 24 trades per year per symbol, profit factor 1.1, and drawdown around 20%. These are expectations, not achieved gate verdicts. Sparse or zero trades require governed Q01/Q02 evidence and must not be inferred from compilation.

## 6. Source Citation

Thomas Carter, *20 Forex Trading Strategies (5 Minute Time Frame)* (2014), System #3. Lineage source ID: `e78a9f1f-4e6a-563c-a080-915133d6ed28`. The approved Strategy Card is the binding implementation contract.

## 7. Risk Model

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The source default retains the card's live-size declaration, but live use is not authorized by this package or review. Initial stop distance is 20 pips and take profit is 10 pips. No martingale, grid, adaptive sizing, or ML is present. The framework's mandatory news blackout remains enabled with `qm_news_stale_max_hours=336`.

## Revision History

| Date | Change |
|---|---|
| 2026-08-10 | Initial generated package. |
| 2026-09-12 | Replaced incomplete SPEC with the canonical seven-section card-fidelity contract. |
