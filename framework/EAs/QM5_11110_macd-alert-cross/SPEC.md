# QM5_11110_macd-alert-cross - Strategy Spec

**EA ID:** QM5_11110
**Slug:** macd-alert-cross
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86 (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades standard MACD main-line and signal-line crosses on completed H4 bars. A long entry occurs when MACD main was below signal two closed bars ago and is above signal on the last closed bar; a short entry uses the inverse cross. Open positions close on the opposite completed-bar cross or after 30 H4 bars. Each entry uses a hard stop at 2.5 times ATR(14) from the entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 1-100 | Fast EMA period for the MACD calculation. |
| `strategy_macd_slow` | 26 | 2-200 | Slow EMA period for the MACD calculation; must be greater than fast. |
| `strategy_macd_signal` | 9 | 1-100 | Signal smoothing period for the MACD signal line. |
| `strategy_atr_period` | 14 | 1-100 | ATR lookback used for the hard stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.1-10.0 | Multiplier applied to ATR(14) for initial stop distance. |
| `strategy_time_stop_h4_bars` | 30 | 1-250 | Maximum holding period measured in H4 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid forex major with DWX H4 OHLC data for MACD.
- `GBPUSD.DWX` - Card-listed liquid forex major with DWX H4 OHLC data for MACD.
- `USDJPY.DWX` - Card-listed liquid forex major with DWX H4 OHLC data for MACD.
- `XAUUSD.DWX` - Card-listed gold symbol with DWX H4 OHLC data for MACD.

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
| Trades / year / symbol | `40` |
| Typical hold time | `Several H4 bars, with a hard cap at 30 H4 bars` |
| Expected drawdown profile | `ATR-defined single-position losses with no averaging or grid exposure` |
| Regime preference | `momentum-reversal / trend-transition` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub indicator source
**Pointer:** https://github.com/EarnForex/MACD-with-Alert
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11110_macd-alert-cross.md`

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
| v1 | 2026-06-07 | Initial build from card | 7000cd56-5943-42b3-8b45-d35b32b7217d |
