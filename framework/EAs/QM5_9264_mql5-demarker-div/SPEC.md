# QM5_9264_mql5-demarker-div - Strategy Spec

**EA ID:** QM5_9264
**Slug:** `mql5-demarker-div`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see approved card artifact)
**Author of this spec:** Gemini
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

The EA trades mechanical regular price-oscillator divergence using the standard 14-period DeMarker oscillator on closed H1 bars.
- **Bullish Divergence (Long):** Bar 1 low is lower than Bar 2 low while Bar 1 DeMarker is higher than Bar 2 DeMarker, provided DeMarker is below 0.50.
- **Bearish Divergence (Short):** Bar 1 high is higher than Bar 2 high while Bar 1 DeMarker is lower than Bar 2 DeMarker, provided DeMarker is above 0.50.

Initial stop loss is set beyond the signal-bar (Bar 1) extreme by 1.0 * ATR(14). Initial take profit is set at 1.8R.
Strategy exits trigger when DeMarker reaches opposite extreme levels (0.70 for long, 0.30 for short) or when closed price breaches the signal bar's extreme in the opposite direction. A failsafe time exit closes the position after 36 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_demarker_period` | 14 | 1+ | Period for the DeMarker oscillator. |
| `strategy_atr_period` | 14 | 1+ | Period for ATR stop loss sizing. |
| `strategy_sl_atr_mult` | 1.0 | 0.01+ | Multiplier for ATR buffer added to signal-bar extreme for SL. |
| `strategy_take_profit_rr` | 1.8 | 0.1+ | Reward-to-risk multiple for the initial take profit. |
| `strategy_demarker_overbought` | 0.70 | 0.5-1.0 | DeMarker level for long strategy exit. |
| `strategy_demarker_oversold` | 0.30 | 0.0-0.5 | DeMarker level for short strategy exit. |
| `strategy_demarker_midline` | 0.50 | 0.0-1.0 | Midline threshold for valid divergence entry filtering. |
| `strategy_time_exit_bars` | 36 | 1+ | Maximum position hold in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with clean H1 oscillator divergence characteristics.
- `GBPJPY.DWX` - High-volatility FX cross.
- `XAUUSD.DWX` - Precious metal momentum and mean-reversion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Up to 36 H1 bars |
| Expected drawdown profile | Reversal entries can experience drawdown during extended strong trends. |
| Regime preference | Mean-reversion / divergence at extremes |
| Win rate target | ~40-50% at 1.8R |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Mohamed Abdelmaaboud, "Learn how to design a trading system by DeMarker", MQL5 Articles, 2022-09-08, https://www.mql5.com/en/articles/11394
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9264_mql5-demarker-div.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-24 | Initial build from approved card | Gemini draft for task 71af1255 |
