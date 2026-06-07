# QM5_11118_stoch-alert-cross - Strategy Spec

**EA ID:** QM5_11118
**Slug:** stoch-alert-cross
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86 (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades Stochastic Oscillator main-line and signal-line crosses on completed H4 bars using the EarnForex source defaults: %K 5, %D 3, slowing 3, SMA method, and low/high price field. A long entry occurs when the main line was below the signal line two closed bars ago and is above it on the last closed bar; a short entry uses the inverse cross. Open positions close on the opposite completed-bar cross, when the stochastic main line crosses the 50 level against the position, or after 12 H4 bars. Each entry uses a hard stop at 2.0 times ATR(14) from the entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_stoch_k` | 5 | 1-100 | Main stochastic %K period from the source default. |
| `strategy_stoch_d` | 3 | 1-100 | Signal stochastic %D period from the source default. |
| `strategy_stoch_slowing` | 3 | 1-100 | Stochastic slowing value from the source default. |
| `strategy_atr_period` | 14 | 1-100 | ATR lookback used for the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | Multiplier applied to ATR(14) for initial stop distance. |
| `strategy_time_stop_h4_bars` | 12 | 1-250 | Maximum holding period measured in H4 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid forex major with DWX H4 OHLC data for stochastic crosses.
- `GBPUSD.DWX` - Card-listed liquid forex major with DWX H4 OHLC data for stochastic crosses.
- `USDJPY.DWX` - Card-listed liquid forex major with DWX H4 OHLC data for stochastic crosses.
- `XAUUSD.DWX` - Card-listed gold symbol with DWX H4 OHLC data for stochastic crosses.

**Explicitly NOT for:**
- `SP500.DWX` - Not part of the card's R3 forex and gold basket.

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
| Trades / year / symbol | `60` |
| Typical hold time | `Several H4 bars, with a hard cap at 12 H4 bars` |
| Expected drawdown profile | `ATR-defined single-position losses with no averaging or grid exposure` |
| Regime preference | `momentum-cross / oscillator reversal` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub indicator source
**Pointer:** https://github.com/EarnForex/Stochastic-with-Alert
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11118_stoch-alert-cross.md`

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
| v1 | 2026-06-07 | Initial build from card | b307b26b-f913-48f6-a0ef-dd278f50773b |
