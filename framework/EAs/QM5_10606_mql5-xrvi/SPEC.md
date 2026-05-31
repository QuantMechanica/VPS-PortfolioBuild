# QM5_10606_mql5-xrvi - Strategy Spec

**EA ID:** QM5_10606
**Slug:** `mql5-xrvi`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see MQL5 CodeBase source set)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades a completed-bar cross between an XRVI-style oscillator and its signal line. The oscillator starts from the source RVI term `(close - open) / (high - low)`, smooths it over the XRVI period, and smooths that line again over the signal period. It opens long when the oscillator crosses above the signal line and opens short when it crosses below. It exits on the opposite cross or after 16 completed H4 bars, with a catastrophic stop at 2.5 ATR(14) from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for XRVI signal, exit cross, ATR stop, and time stop. |
| `strategy_xrvi_period` | `10` | `1+` | Smoothing period for the XRVI oscillator line. |
| `strategy_signal_period` | `5` | `1+` | Smoothing period for the XRVI signal line. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | `2.5` | `>0` | ATR multiple used to place the catastrophic stop. |
| `strategy_max_hold_bars` | `16` | `1+` | Maximum completed H4 bars to hold before fallback exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - the source test used XAUUSD H4 and the card names it as the direct baseline.
- `EURUSD.DWX` - DWX major FX pair included by the card's FX majors expansion.
- `GBPUSD.DWX` - DWX major FX pair included by the card's FX majors expansion.
- `USDJPY.DWX` - DWX major FX pair included by the card's FX majors expansion.
- `USDCHF.DWX` - DWX major FX pair included by the card's FX majors expansion.
- `USDCAD.DWX` - DWX major FX pair included by the card's FX majors expansion.
- `AUDUSD.DWX` - DWX major FX pair included by the card's FX majors expansion.
- `NZDUSD.DWX` - DWX major FX pair included by the card's FX majors expansion.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must use the canonical `.DWX` symbols.
- Equity index CFDs - the approved R3 universe is XAUUSD plus FX majors, not indices.

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
| Trades / year / symbol | `70` |
| Expected trade frequency | Not specified in frontmatter; derived expectation is roughly monthly-to-weekly H4 oscillator crosses. |
| Typical hold time | Up to 16 completed H4 bars by fallback time stop. |
| Expected drawdown profile | Stop-defined momentum-reversal losses, capped by 2.5 ATR catastrophic stop. |
| Regime preference | Momentum reversal / oscillator signal-cross regimes. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/1305`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10606_mql5-xrvi.md`

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
| v1 | 2026-05-31 | Initial build from card | 89871080-3b05-4ae8-abfd-7ccd1f436483 |
