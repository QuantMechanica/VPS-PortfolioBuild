# QM5_10524_mql5-ma590-pend - Strategy Spec

**EA ID:** QM5_10524
**Slug:** `mql5-ma590-pend`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA evaluates closed H1 bars. It goes long by placing a Buy Stop when the last close is above SMA(590), the SMA is rising over the prior three closed bars, and the pending entry sits at the recent 5-bar high plus 0.25 ATR(14). It goes short by placing a Sell Stop when the last close is below SMA(590), the SMA is falling over the prior three closed bars, and the pending entry sits at the recent 5-bar low minus 0.25 ATR(14). Pending stops expire after six H1 bars or are removed when the MA side flips, and open positions close when the prior close crosses to the opposite side of SMA(590).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma_period` | 590 | 365-800 | Slow SMA period for direction and exit side. |
| `strategy_slope_bars` | 3 | 1-10 | Closed-bar distance used to confirm SMA slope. |
| `strategy_breakout_lookback` | 5 | 3-10 | Closed-bar high/low range used for pending-stop breakout levels and structure stop. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for entry indent and bounded stop distance. |
| `strategy_atr_indent_mult` | 0.25 | 0.0-1.0 | ATR multiplier added beyond the 5-bar range for pending-stop entry. |
| `strategy_atr_sl_mult` | 1.5 | 0.5-5.0 | Minimum ATR stop distance before structure comparison. |
| `strategy_atr_sl_cap_mult` | 2.5 | 1.0-6.0 | Maximum ATR stop distance cap. |
| `strategy_tp_r_mult` | 1.5 | 0.5-5.0 | Take-profit multiple of initial risk. |
| `strategy_pending_bars` | 6 | 1-24 | Pending order lifetime in base timeframe bars. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 primary FX basket member with H1 DWX data.
- `GBPUSD.DWX` - Card R3 primary FX basket member with H1 DWX data.
- `USDJPY.DWX` - Card R3 primary FX basket member with H1 DWX data.
- `XAUUSD.DWX` - Card R3 metals basket member with H1 DWX data.

**Explicitly NOT for:**
- `SP500.DWX` - Not in the card's R3 FX/metals basket.

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
| Typical hold time | `hours to days` |
| Expected drawdown profile | `ATR/range bounded hard stops with 1.5R targets` |
| Regime preference | `breakout / trend continuation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/19341`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10524_mql5-ma590-pend.md`

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
| v1 | 2026-05-29 | Initial build from card | 802508e2-a2b4-4f2b-a6d7-d4777303cf07 |
