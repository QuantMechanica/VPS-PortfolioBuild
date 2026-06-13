# QM5_10640_et-rsi-trail - Strategy Spec

**EA ID:** QM5_10640
**Slug:** et-rsi-trail
**Source:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64 (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades H4 RSI mean reversion with a trend-quality guard. A long entry is allowed when the last closed H4 bar has RSI(14) below 20 and either ADX(14) is below 25 or price is above a rising EMA(200). A short entry is the mirror rule with RSI above 80 and either ADX below 25 or price below a falling EMA(200). Exits occur when RSI crosses back through the 50 midline, when the H4 time stop reaches 12 bars, or through the initial/trailing stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_rsi_period | 14 | 7-14 | RSI lookback on H4. |
| strategy_rsi_long_entry | 20.0 | 20-25 | Long threshold for oversold RSI. |
| strategy_rsi_short_entry | 80.0 | 75-80 | Short threshold for overbought RSI. |
| strategy_rsi_midline | 50.0 | 50 | RSI exit midline. |
| strategy_adx_period | 14 | 14 | ADX trend-quality period. |
| strategy_adx_max | 25.0 | 20-30 | Maximum ADX for range-mode entries. |
| strategy_ema_period | 200 | 200 | EMA bias period. |
| strategy_atr_period | 14 | 14 | ATR stop and trail period. |
| strategy_atr_stop_mult | 1.5 | 1.0-2.0 | ATR multiplier for initial and trailing stop distance. |
| strategy_price_stop_pct | 1.0 | 1.0-2.0 | Minimum stop and trail distance as percent of entry price. |
| strategy_trail_trigger_r | 0.75 | 0.75 | Favorable R move required before trailing starts. |
| strategy_time_exit_bars | 12 | 8-20 | Maximum holding time in H4 bars. |
| strategy_range_atr_max | 2.5 | 2.5 | Skips entries after unusually large H4 range bars. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed forex target for symmetric RSI mean reversion.
- XAUUSD.DWX - card-listed metal target with liquid DWX history.
- GDAXI.DWX - verified DAX DWX symbol used in place of card-stated GER40.DWX, which is not present in the symbol matrix.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`.

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
| Trades / year / symbol | 24 |
| Typical hold time | Up to 12 H4 bars, with earlier RSI or trailing-stop exits. |
| Expected drawdown profile | Mean-reversion drawdowns can cluster during persistent trends; ADX and EMA filters reduce trend-fade exposure. |
| Regime preference | RSI mean reversion with trend-quality filtering. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/simple-rsi-strategy.71238/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10640_et-rsi-trail.md`

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
| v1 | 2026-06-13 | Initial build from card | dbad8151-794b-4f45-a1b5-044889ff4178 |
