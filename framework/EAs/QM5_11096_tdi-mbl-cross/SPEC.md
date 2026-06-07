# QM5_11096_tdi-mbl-cross - Strategy Spec

**EA ID:** QM5_11096
**Slug:** `tdi-mbl-cross`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed bars on the chart timeframe, with the P2 baseline using H1. It calculates RSI(13), a 2-period RSI price line, a 7-period trade signal line, and a 34-period market base line. A long opens when the trade signal line crosses from at or below the market base line to above it; a short opens on the inverse cross. Positions close on the opposite market-base-line cross, on an RSI price line cross against the position, or after 18 completed H1 bars; the initial stop is 2.0 x ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 13 | 2-100 | RSI lookback used by all TDI line calculations. |
| `strategy_volatility_band_period` | 34 | 2-200 | RSI averaging window for the market base line and volatility-band sanity check. |
| `strategy_stddev_mult` | 1.6185 | 0.1-5.0 | Standard-deviation multiplier from the source TDI defaults. |
| `strategy_rsi_price_line_period` | 2 | 1-50 | Smoothing period for the RSI price line. |
| `strategy_trade_signal_period` | 7 | 1-100 | Smoothing period for the trade signal line. |
| `strategy_atr_period` | 14 | 2-100 | ATR lookback for the baseline stop loss. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiple used for the initial stop loss. |
| `strategy_time_stop_bars` | 18 | 1-200 | Maximum hold time in chart bars before closing the position. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 names this major FX pair as part of the P2 basket.
- `GBPUSD.DWX` - card R3 names this major FX pair as part of the P2 basket.
- `USDJPY.DWX` - card R3 names this major FX pair as part of the P2 basket.
- `XAUUSD.DWX` - card R3 names this liquid metals CFD as part of the P2 basket.

**Explicitly NOT for:**
- Symbols outside the approved R3 basket - not registered for this EA in `magic_numbers.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | `hours; catastrophic stop at 18 H1 bars` |
| Expected drawdown profile | `Moderate FX/metal momentum-cross drawdown with ATR-capped per-trade risk.` |
| Regime preference | `momentum-regime` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `GitHub indicator source`
**Pointer:** `EarnForex Traders Dynamic Index repository and source article`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11096_tdi-mbl-cross.md`

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
| v1 | 2026-06-07 | Initial build from card | d294b0a3-5c1b-499b-b6b3-bc66bd32a595 |
