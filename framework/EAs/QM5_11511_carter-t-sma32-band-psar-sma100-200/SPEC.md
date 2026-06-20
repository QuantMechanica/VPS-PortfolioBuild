# QM5_11511_carter-t-sma32-band-psar-sma100-200 - Strategy Spec

**EA ID:** QM5_11511
**Slug:** `carter-t-sma32-band-psar-sma100-200`
**Source:** `8794b680-f6f4-5142-b12c-e5e0057e7bcf` (see `sources/carter-thomas-20-forex-trend-following-systems`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades an M30 trend-following channel breakout from Thomas Carter System #6. It buys when the last closed bar closes above the SMA(32) of highs, is bullish, is above both SMA(100) and SMA(200), and PSAR(0.02, 0.2) is below the bar. It sells when the last closed bar closes below the SMA(32) of lows, is bearish, is below both SMA(100) and SMA(200), and PSAR is above the bar. Positions use the PSAR dot at entry as the stop, capped at 20 pips, with a fixed 13-pip take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_band_period` | 32 | 21-50 | SMA period for the high/low channel. |
| `strategy_sma_trend_fast` | 100 | 50-150 | Fast macro trend SMA on close. |
| `strategy_sma_trend_slow` | 200 | 150-250 | Slow macro trend SMA on close. |
| `strategy_sar_step` | 0.02 | 0.01-0.10 | Parabolic SAR acceleration step. |
| `strategy_sar_max` | 0.20 | 0.10-0.30 | Parabolic SAR acceleration maximum. |
| `strategy_tp_pips` | 13 | 10-25 | Fixed take-profit in pips for M30. |
| `strategy_sl_cap_pips` | 20 | 5-40 | Maximum PSAR-derived stop distance in pips. |
| `strategy_no_friday_entry` | true | true/false | Blocks new Friday entries per card. |
| `strategy_spread_cap_pips` | 12 | 0-30 | Blocks only genuinely wide spreads above this pip cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed M30 DWX forex major.
- `GBPUSD.DWX` - card-listed M30 DWX forex major.
- `AUDUSD.DWX` - card-listed M30 DWX forex major.

**Explicitly NOT for:**
- `SP500.DWX` - not a forex pair and not listed by the card.
- `XAUUSD.DWX` - commodity behavior is outside the card's FX system.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | intraday to a few hours |
| Expected drawdown profile | small fixed take-profit with PSAR-capped stop creates frequent short-distance losses during chop. |
| Regime preference | breakout / trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `8794b680-f6f4-5142-b12c-e5e0057e7bcf`
**Source type:** book
**Pointer:** `sources/carter-thomas-20-forex-trend-following-systems`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11511_carter-t-sma32-band-psar-sma100-200.md`

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
| v1 | 2026-06-20 | Initial build from card | 0855247c-4e4c-43fa-937a-26727659ee85 |
