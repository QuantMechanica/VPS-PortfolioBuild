# QM5_10817_tv-trend-flow - Strategy Spec

**EA ID:** QM5_10817
**Slug:** tv-trend-flow
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView Trend Flow Strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades the fixed Trend Flow mode from the approved card. It enters long when EMA(20) crosses above EMA(50), the last closed bar closes above both EMAs, and SuperTrend(10, 3.0) is bullish. It enters short on the opposite EMA cross when the close is below both EMAs and SuperTrend is bearish. It exits on an opposite EMA cross, a SuperTrend direction flip, the V5 max-bars limit, or the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_ema | 20 | 1-200 | Fast EMA period for entry and reversal crosses. |
| strategy_slow_ema | 50 | 2-300 | Slow EMA period; coerced above the fast period in code. |
| strategy_supertrend_atr_period | 10 | 2-100 | ATR period used by the SuperTrend reconstruction. |
| strategy_supertrend_multiplier | 3.0 | 0.1-10.0 | ATR multiplier for the SuperTrend bands. |
| strategy_supertrend_lookback | 160 | 20-500 | Closed-bar warmup length for bounded SuperTrend state reconstruction. |
| strategy_atr_fallback_period | 14 | 2-100 | ATR period for the fallback safety stop. |
| strategy_atr_fallback_mult | 2.0 | 0.1-10.0 | ATR multiple for the fallback safety stop. |
| strategy_max_bars_h1 | 120 | 0-500 | Optional time exit when running on H1; 0 disables. |
| strategy_max_bars_h4 | 80 | 0-500 | Optional time exit when running on H4; 0 disables. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair named in the approved R3 basket.
- GBPUSD.DWX - liquid major FX pair named in the approved R3 basket.
- USDJPY.DWX - liquid major FX pair named in the approved R3 basket.
- XAUUSD.DWX - gold trend-following proxy; the card used bare XAUUSD and the DWX matrix canonical symbol is XAUUSD.DWX.
- GDAXI.DWX - DAX index proxy; registered because GER40.DWX is not present in the DWX matrix.
- NDX.DWX - Nasdaq 100 index in the approved R3 basket.
- WS30.DWX - Dow 30 index in the approved R3 basket.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.
- SP500.DWX - mentioned only as a possible later primary test target, not part of this card's primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 and H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | H1 positions up to 120 bars; H4 positions up to 80 bars |
| Expected drawdown profile | Trend follower that can lag reversals and lose during EMA/SuperTrend chop |
| Regime preference | trend-following / volatility-trailing |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView strategy page
**Pointer:** https://www.tradingview.com/script/Z4kcoUGT-Trend-Flow-Strategy/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10817_tv-trend-flow.md`

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
| v1 | 2026-06-14 | Initial build from card | 7d6f0784-a151-4540-9941-2d190658e4b0 |
