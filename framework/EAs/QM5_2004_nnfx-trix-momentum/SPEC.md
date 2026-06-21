# QM5_2004_nnfx-trix-momentum — Strategy Spec

**EA ID:** QM5_2004
**Slug:** `nnfx-trix-momentum`
**Source:** `GEMINI_NNFX_2004` (see `strategy-seeds/sources/GEMINI_NNFX_2004/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-21

---

## 1. Strategy Logic

Enter long on the D1 close when: (1) the prior bar's close is above the 34-period Zero-Lag EMA (approximated via single-pass EMA), (2) the 14-period TRIX oscillator is positive (line > 0, i.e., trending up), and (3) the 14-period Choppiness Index is below 61.8 (indicating a trending rather than ranging market). Enter short on the mirror conditions. Stop-loss is set at 1.5× ATR(14) from entry price; take-profit at 1.5R. Exit when the TRIX oscillator changes sign (line crosses from positive to negative for a long, or negative to positive for a short).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_zlema_period` | 34 | 10–100 | Period of the ZLEMA baseline indicator |
| `strategy_trix_period` | 14 | 5–50 | Period of the TRIX oscillator |
| `strategy_chop_period` | 14 | 5–50 | Lookback period for Choppiness Index |
| `strategy_chop_threshold` | 61.8 | 38–80 | CHOP must be below this to allow entry (trending regime) |
| `strategy_atr_period` | 14 | 7–28 | ATR period used for stop calculation |
| `strategy_atr_sl_mult` | 1.5 | 0.5–3.0 | ATR multiplier for stop distance |
| `strategy_rr` | 1.5 | 1.0–4.0 | Risk-to-reward ratio for take-profit |
| `strategy_spread_cap_points` | 25 | 0–200 | Block entry if spread exceeds this (0 = disabled) |

---

## 3. Symbol Universe

This is a price-only momentum strategy applicable across any trending DWX CFD.

**Designed for:**
- All 37 DWX symbols registered in `magic_numbers.csv` slots 0–36, including all major/minor FX pairs, indices (NDX, WS30, SP500, GDAXI, UK100), metals (XAUUSD, XAGUSD), and energies.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~20–60 (trend-following, daily bars) |
| Typical hold time | 3–15 days |
| Expected drawdown profile | Moderate; 1.5R TP limits upside per trade but caps loss at 1R |
| Regime preference | trend |
| Win rate target (qualitative) | low-medium (trend-following; large R multiples offset lower win rate) |

---

## 6. Source Citation

**Source ID:** `GEMINI_NNFX_2004`
**Source type:** AI
**Pointer:** `strategy-seeds/sources/GEMINI_NNFX_2004/`
**R1–R4 verdict (Q00):** R1=FAIL (no traceable book source), R2/R3/R4=PASS — see `artifacts/cards_approved/QM5_2004_nnfx-trix-momentum.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-21 | Initial build from card | a3a87c74-452c-4e7d-85ea-0b152942b495 |
