# QM5_10548_mql5-fract-mfi - Strategy Spec

**EA ID:** QM5_10548
**Slug:** `mql5-fract-mfi`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA evaluates a closed-bar Fractal MFI oscillator formed from each bar's range divided by tick volume, normalized over the configured lookback. It buys when the oscillator crosses upward through the oversold level and sells when it crosses downward through the overbought level. Long positions close when the oscillator crosses back down through the midline or gives the opposite overbought sell signal; short positions close when it crosses back up through the midline or gives the opposite oversold buy signal. The P2 build adds an ATR hard stop and R-multiple target because the source test did not specify stop loss or take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_mfi_period` | 14 | 2-100 | Lookback used to normalize the Fractal MFI value to a 0-100 oscillator. |
| `strategy_oversold_level` | 30.0 | 0-50 | Long trigger level crossed upward by Fractal MFI. |
| `strategy_overbought_level` | 70.0 | 50-100 | Short trigger level crossed downward by Fractal MFI. |
| `strategy_midline_level` | 50.0 | 0-100 | Signal-exit level used after entry. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for hard stop distance. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiplier for the hard stop. |
| `strategy_rr_target` | 1.5 | 0.1-10.0 | Take-profit distance as a multiple of initial stop risk. |
| `strategy_use_trend_filter` | false | true/false | Optional P3 trend-filter switch, disabled for P2 baseline. |
| `strategy_trend_ma_period` | 200 | 2-500 | SMA period used only when the optional trend filter is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target and liquid major FX pair suitable for OHLC/volume oscillator testing.
- `EURAUD.DWX` - card target and available DWX cross pair for the source's EURAUD H2 example.
- `GBPUSD.DWX` - card target and liquid major FX pair suitable for portable oscillator testing.
- `XAUUSD.DWX` - card target and available metals symbol for portable range/volume oscillator testing.

**Explicitly NOT for:**
- `SP500.DWX` - not listed by the card's R3 basket.
- `NDX.DWX` - not listed by the card's R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H2` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | hours to several H2 bars |
| Expected drawdown profile | bounded mean-reversion drawdown with ATR hard stops |
| Regime preference | oscillator mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/17120`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10548_mql5-fract-mfi.md`

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
| v1 | 2026-05-29 | Initial build from card | 07e24a6d-af9b-40a6-bc69-f19067398a4a |
