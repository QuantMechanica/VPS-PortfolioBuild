# QM5_9505_chande-fo-bband-fade-h4 - Strategy Spec

**EA ID:** QM5_9505
**Slug:** `chande-fo-bband-fade-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-07-08

---

## 1. Strategy Logic

This EA trades Chande's Forecast Oscillator on completed H4 bars. For each bar it
fits a least-squares line to the prior 14 closes, forecasts the current close,
and computes `FO = 100 * (Close - Forecast) / Close`. It then builds a rolling
60-bar mean and standard-deviation band around FO.

The EA fades two-sigma FO extremes only when the Chande volatility ratio
`ATR(7) / ATR(28)` is below `0.7`, which identifies a consolidation regime.
It sells when FO crosses above its upper band and the trigger bar closes away
from its high; it buys when FO crosses below its lower band and the trigger bar
closes away from its low. It exits on FO mean reversion, a 14-bar time stop, the
server-side ATR stop, or the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lr_period` | 14 | 8-30 | Prior closed bars used for the linear-regression forecast |
| `strategy_fo_mean_lookback` | 60 | 40-100 | Rolling FO mean and standard-deviation lookback |
| `strategy_band_devs` | 2.0 | 1.5-2.5 | Standard deviations required for an FO band penetration |
| `strategy_vr_fast_atr` | 7 | 5-14 | Fast ATR period for Chande volatility ratio |
| `strategy_vr_slow_atr` | 28 | 20-40 | Slow ATR period for Chande volatility ratio |
| `strategy_vr_max` | 0.7 | 0.6-0.9 | Maximum volatility ratio allowed for consolidation fades |
| `strategy_atr_period` | 14 | 10-30 | ATR period for the hard stop and spread filter |
| `strategy_sl_atr_mult` | 1.0 | 0.5-2.0 | ATR cushion beyond the trigger bar high/low |
| `strategy_max_hold_bars` | 14 | 8-24 | H4 bars before a time-stop exit |
| `strategy_bar_confirm_frac` | 0.30 | 0.20-0.50 | Trigger close must retreat this fraction from the extreme |
| `strategy_slope_frac_max` | 0.005 | 0.002-0.010 | Maximum regression slope as a fraction of price |
| `strategy_spread_atr_frac_max` | 0.20 | 0.10-0.30 | Maximum live spread as a fraction of ATR |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`,
  `USDCHF.DWX`, `NZDUSD.DWX` - the FX-major basket in the approved R3 universe.
- `XAUUSD.DWX` and `XTIUSD.DWX` - liquid metal and oil CFDs that support the
  same price-only H4 oscillator primitive.
- `GDAXI.DWX`, `NDX.DWX`, `WS30.DWX`, `UK100.DWX` - index CFDs present in the
  DWX matrix for the portable H4 price-only basket.

**Explicitly NOT for:**
- `FRA40.DWX` and `JP225.DWX` - listed in the card but not present in the local
  DWX symbol matrix/history at build time.
- `SP500.DWX` - not part of this card's target list.
- Non-DWX exchange tickers, ETFs, and futures symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 18 |
| Typical hold time | several H4 bars to roughly two trading days |
| Expected drawdown profile | Medium; losses cluster when consolidation breaks into trend |
| Regime preference | Mean reversion in low-volatility consolidation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** Chande/Kroll book lineage plus ForexFactory strategy thread cluster
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9505_chande-fo-bband-fade-h4.md`
**R1-R4 verdict (Q00):** all PASS / see the approved strategy card.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV to mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-08 | Initial build from approved card | build task 64d69435-3f35-4280-9646-e3166e3b8767 |
