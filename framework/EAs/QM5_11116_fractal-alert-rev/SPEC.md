# QM5_11116_fractal-alert-rev — Strategy Spec

**EA ID:** QM5_11116
**Slug:** `fractal-alert-rev`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (EarnForex Fractals-Alert)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

Trades confirmed Bill Williams fractals as swing reversals on completed H4 bars.
A fractal is a 5-bar pattern: a centre bar whose high is strictly above the two
bars on each side (top fractal) or whose low is strictly below the two bars on
each side (bottom fractal). The EA only acts on *finalized* fractals — it waits
until the two right-side bars have completed, so it never reacts to a
first-detected fractal that could still disappear (the centre bar sits at shift
`half+1`, i.e. shift 3 for the default half-width of 2).

Entry: go long at the next bar open when a bottom fractal confirms (swing-low
reversal up); go short when a top fractal confirms (swing-high reversal down).
One position per symbol/magic at a time. Stop loss is the confirmed fractal
level offset by 0.5×ATR(14): bottom fractal − 0.5·ATR for longs, top fractal +
0.5·ATR for shorts. Exit a long on an opposite (top) fractal confirmation, on a
completed-bar close below the last confirmed bottom fractal, or after 18 H4 bars
in trade; mirror conditions for shorts.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fractal_half` | 2 | 2-4 | Bars on each side of the centre bar (2 = standard 5-bar Bill Williams fractal) |
| `strategy_atr_period` | 14 | 5-50 | ATR period for the stop-loss offset |
| `strategy_atr_sl_mult` | 0.5 | 0.1-2.0 | ATR multiple added beyond the fractal level for the stop |
| `strategy_max_hold_bars` | 18 | 5-100 | Time-stop: close after this many completed H4 bars in trade |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean fractal structure on H4
- `GBPUSD.DWX` — liquid major with regular swing structure suited to reversal entries
- `USDJPY.DWX` — liquid major; trending/ranging mix gives confirmed fractals
- `XAUUSD.DWX` — high-volatility metal; ATR-scaled fractal stops adapt to its range

**Explicitly NOT for:**
- `SP500.DWX` — index, backtest-only and outside the card's FX/metal basket

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | `hours to a few days (≤18 H4 bars ≈ 3 days)` |
| Expected drawdown profile | `moderate; ATR-scaled structural stops cap per-trade loss` |
| Regime preference | `mean-revert / swing-reversal` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `forum` (EarnForex indicator repository / MQL5 source)
**Pointer:** `https://github.com/EarnForex/Fractals-Alert`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11116_fractal-alert-rev.md`

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
| v1 | 2026-06-07 | Initial build from card | 2c64e87e-2652-49b8-b537-5dfded31784e |
