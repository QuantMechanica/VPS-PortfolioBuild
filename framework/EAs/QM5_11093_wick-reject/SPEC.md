# QM5_11093_wick-reject - Strategy Spec

**EA ID:** QM5_11093
**Slug:** wick-reject
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H4 candles for rejection wicks. A long entry is opened when the lower wick is at least 45% of the candle range, the upper wick is below 25%, and the candle closes in the upper half of its range. A short entry mirrors that rule with an upper wick of at least 45%, lower wick below 25%, and a close in the lower half. Exits occur through 1.5R take profit, the initial stop, an opposite completed-bar wick signal, or a 4-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 14 | >= 1 | ATR lookback for the stop buffer. |
| strategy_lower_wick_pct | 45.0 | 0-100 | Minimum lower-wick percentage for long entries. |
| strategy_upper_wick_pct | 45.0 | 0-100 | Minimum upper-wick percentage for short entries. |
| strategy_opposite_wick_max | 25.0 | 0-100 | Maximum wick percentage on the non-signal side. |
| strategy_body_close_pct | 50.0 | 0-100 | Close-location threshold used for upper/lower half tests. |
| strategy_stop_atr_buffer | 0.25 | > 0 | ATR multiple added beyond the signal candle extreme for stop placement. |
| strategy_take_profit_r | 1.5 | > 0 | Fixed reward-to-risk take-profit multiple. |
| strategy_time_stop_bars | 4 | >= 1 | Maximum hold measured in base-timeframe bars. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed liquid FX major with full DWX OHLC history.
- GBPUSD.DWX - Card-listed liquid FX major with full DWX OHLC history.
- USDJPY.DWX - Card-listed liquid FX major with full DWX OHLC history.
- XAUUSD.DWX - Card-listed liquid gold CFD with full DWX OHLC history.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtests.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Up to 4 H4 bars, or earlier on opposite signal / 1.5R TP / SL |
| Expected drawdown profile | Moderate mean-reversion losses during persistent trend continuation. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub / indicator source
**Pointer:** EarnForex Candle Wicks Length Display, `MQL5/Indicators/CandleWicksDisplay.mq5`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11093_wick-reject.md`

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
| v1 | 2026-06-07 | Initial build from card | c3838001-4dd8-4fab-ae08-4a4f2d9f9a80 |
