# QM5_11035_atc-atr-channel - Strategy Spec

**EA ID:** QM5_11035
**Slug:** atc-atr-channel
**Source:** 9441393d-5ffc-5b43-87be-bd532110f204
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H1 bars and builds an ATR channel around an EMA midline. A long entry fires when the last closed bar crosses above the upper channel; a short entry fires when it crosses below the lower channel. Open positions are held until the opposite channel cross, with an emergency stop at a fixed ATR multiple and no take-profit. If `strategy_mid_period` is set to 1, the midline is the prior closed bar close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_mid_period` | 20 | 1+ | EMA midline period; 1 uses prior closed bar close |
| `strategy_atr_period` | 14 | 1+ | ATR period for the channel and emergency stop |
| `strategy_channel_mult` | 1.5 | >0 | ATR multiplier added/subtracted from the midline |
| `strategy_emergency_sl_atr` | 3.0 | >0 | Emergency stop distance in ATR multiples |
| `strategy_adx_period` | 14 | 1+ | ADX period for optional trend-strength filter |
| `strategy_adx_min` | 18.0 | 0+ | Minimum ADX; 0 disables the filter |
| `strategy_median_spread_points` | 20 | 0+ | Median spread assumption in points; 0 disables spread gate |
| `strategy_spread_median_mult` | 2.0 | >0 | Maximum allowed spread multiple versus median |
| `strategy_weekend_guard_enabled` | true | true/false | Block new trades near weekly close |
| `strategy_weekend_guard_hour` | 21 | 0-23 | Broker Friday hour when weekend guard starts |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - listed in the card R3 FX P2 basket and present in the DWX matrix
- `GBPUSD.DWX` - listed in the card R3 FX P2 basket and present in the DWX matrix
- `USDJPY.DWX` - listed in the card R3 FX P2 basket and present in the DWX matrix
- `EURJPY.DWX` - listed in the card R3 FX P2 basket and present in the DWX matrix

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline registries require `.DWX` symbols for research and backtest

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Until opposite H1 channel cross; commonly hours to days |
| Expected drawdown profile | Whipsaw and open-profit giveback in ranges, bounded by ATR emergency stop |
| Regime preference | Trend-following channel breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9441393d-5ffc-5b43-87be-bd532110f204
**Source type:** MQL5 article interview
**Pointer:** https://www.mql5.com/en/articles/580
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11035_atc-atr-channel.md`

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
| v1 | 2026-06-07 | Initial build from card | fb311647-81f5-4696-a94f-6714fa1937ad |
