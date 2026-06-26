# QM5_1637_mql5-golden-death - Strategy Spec

**EA ID:** QM5_1637
**Slug:** mql5-golden-death
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades a closed-bar H4 EMA crossover. It opens long when the fast EMA crosses above the slow EMA and opens short when the fast EMA crosses below the slow EMA. A long position exits on the opposite death cross, and a short position exits on the opposite golden cross. Every entry also receives an ATR(14)-based protective stop and fixed reward/risk take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_fast_ema_period | 20 | 1-1000 | Fast EMA period used for the crossover trigger. |
| strategy_slow_ema_period | 50 | 2-1000 | Slow EMA period used for the crossover trigger; must be greater than the fast period. |
| strategy_atr_period | 14 | 1-500 | ATR period used for protective stop distance. |
| strategy_atr_stop_mult | 2.5 | 0.1-10.0 | ATR multiple used to place the initial stop. |
| strategy_take_profit_rr | 2.0 | 0.1-10.0 | Take-profit as a multiple of initial stop risk. |
| strategy_use_separation_filter | false | true/false | Enables the optional card filter that requires EMA separation at the cross. |
| strategy_min_separation_atr | 0.25 | 0.0-5.0 | Minimum EMA separation as a fraction of ATR when the optional filter is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed DWX forex major with native OHLC data for EMA crossover testing.
- GBPUSD.DWX - Card-listed DWX forex major with native OHLC data for EMA crossover testing.
- XAUUSD.DWX - Card-listed DWX metal symbol with native OHLC data for EMA crossover testing.

**Explicitly NOT for:**
- Non-DWX symbols - This build follows the DWX backtest registry and does not register broker-live stripped symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Not specified in card; positions hold until reverse cross, protective stop, take-profit, or framework Friday close. |
| Expected drawdown profile | Not specified in card; trend-following whipsaw risk during sideways regimes. |
| Regime preference | Trend-following |
| Win rate target (qualitative) | Not specified in card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** MQL5 article
**Pointer:** https://www.mql5.com/en/articles/16633
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1637_mql5-golden-death.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-26 | Initial build from card | 60b7463b-741d-4a69-8aec-bb1491e0ebba |
