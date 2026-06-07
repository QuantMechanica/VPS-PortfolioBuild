# QM5_11189_ft-hlhb - Strategy Spec

**EA ID:** QM5_11189
**Slug:** `ft-hlhb`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades long on H4 closed bars when the HLHB trend signal aligns. It computes RSI(10) on `hl2 = (open + close) / 2`, EMA(5), EMA(10), and ADX(14); a long entry fires when RSI crosses above 50, EMA(5) crosses above EMA(10), ADX is above 25, and the closed bar has positive tick volume. The initial stop is an ATR(14) stop at 2.5x ATR, and the source ROI ladder can close profitable positions. A strategy exit fires when RSI crosses below 50, EMA(5) crosses below EMA(10), ADX remains above 25, and tick volume is positive.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 10 | 8-14 | RSI period used on `(open + close) / 2`. |
| `strategy_rsi_midline` | 50.0 | fixed | RSI crossover threshold from the source strategy. |
| `strategy_ema_fast` | 5 | 5-10 | Fast EMA period for the trend cross. |
| `strategy_ema_slow` | 10 | 10-20 | Slow EMA period for the trend cross. |
| `strategy_adx_period` | 14 | fixed | ADX period for the trend-strength filter. |
| `strategy_adx_min` | 25.0 | 20-30 | Minimum ADX value for entries and signal exits. |
| `strategy_atr_period` | 14 | fixed | ATR period for the MT5 baseline stop. |
| `strategy_atr_stop_mult` | 2.5 | 2.0-3.0 | ATR multiple for the initial stop loss. |
| `strategy_max_spread_stop_frac` | 0.08 | fixed | Maximum spread as a fraction of planned stop distance. |
| `strategy_warmup_bars` | 30 | fixed | Minimum closed bars required before signal evaluation. |
| `strategy_roi_0m_pct` | 62.25 | source | Immediate ROI threshold from the source ladder. |
| `strategy_roi_703m_pct` | 21.87 | source | ROI threshold after 703 minutes. |
| `strategy_roi_2849m_pct` | 3.63 | source | ROI threshold after 2849 minutes. |
| `strategy_roi_5520m_pct` | 0.0 | source | Flat ROI threshold after 5520 minutes. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair in the card's primary portable basket.
- `GBPUSD.DWX` - major FX pair in the card's primary portable basket.
- `USDJPY.DWX` - major FX pair in the card's primary portable basket.
- `XAUUSD.DWX` - liquid DWX metal symbol included by the approved card.

**Explicitly NOT for:**
- Equity index `.DWX` symbols - the card's R3 basket is FX/metals only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `32` |
| Typical hold time | H4 trend holds, often hours to several days; ROI ladder reaches flat threshold after 5520 minutes. |
| Expected drawdown profile | Medium risk profile from the approved card. |
| Regime preference | Trend-following FX/metals regime. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** GitHub strategy file
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/hlhb.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11189_ft-hlhb.md`

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
| v1 | 2026-06-07 | Initial build from card | 43d1fd71-4436-4633-ba9a-74da3a204478 |
