# QM5_11003_the5ers-ma-macd-filter - Strategy Spec

**EA ID:** QM5_11003
**Slug:** `the5ers-ma-macd-filter`
**Source:** `1d445184-7c47-57da-9856-a123682a932d` (see `sources/the5ers-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades an H1 moving-average trend-following signal. A long entry is opened on the next H1 bar after EMA(5) crosses above EMA(35), provided MACD main(12,26,9) closed above zero. A short entry is opened after EMA(5) crosses below EMA(35), provided MACD main closed below zero. The initial stop is 2.0 x ATR(14), and the EA exits on the opposite EMA cross, MACD main crossing back through zero, or after 72 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 5 | 2-50 | Fast EMA period used for the crossover trigger. |
| `strategy_ema_slow_period` | 35 | 5-200 | Slow EMA period used for the crossover trigger. |
| `strategy_macd_fast` | 12 | 2-50 | Fast EMA period inside the MACD calculation. |
| `strategy_macd_slow` | 26 | 5-100 | Slow EMA period inside the MACD calculation. |
| `strategy_macd_signal` | 9 | 2-50 | Signal EMA period inside the MACD calculation. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for initial stop placement. |
| `strategy_sl_atr_mult` | 2.0 | 0.5-5.0 | Initial stop distance in ATR multiples. |
| `strategy_time_stop_bars` | 72 | 1-240 | Maximum holding time in H1 bars. |
| `strategy_spread_pct_of_stop` | 15.0 | 0-100 | Entry spread guard as a percentage of the ATR stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair supported by DWX H1 OHLC data.
- `GBPUSD.DWX` - liquid major FX pair supported by DWX H1 OHLC data.
- `USDJPY.DWX` - liquid major FX pair supported by DWX H1 OHLC data.
- `AUDUSD.DWX` - liquid major FX pair supported by DWX H1 OHLC data.
- `XAUUSD.DWX` - liquid metal symbol supported by DWX H1 OHLC data.

**Explicitly NOT for:**
- `SP500.DWX` - not part of the card's target FX/metal basket.
- `NDX.DWX` - not part of the card's target FX/metal basket.
- `WS30.DWX` - not part of the card's target FX/metal basket.

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
| Trades / year / symbol | `60` |
| Typical hold time | Up to 72 H1 bars by time stop; earlier exits on EMA or MACD reversal. |
| Expected drawdown profile | Trend-following whipsaw risk in sideways markets, bounded by ATR stop. |
| Regime preference | Trend-following / momentum-confirmation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1d445184-7c47-57da-9856-a123682a932d`
**Source type:** blog
**Pointer:** `https://the5ers.com/moving-average-for-trend-following/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11003_the5ers-ma-macd-filter.md`

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
| v1 | 2026-06-18 | Initial build from card | ada99fae-b4bd-4e79-9d04-1f22fa3925ca |
