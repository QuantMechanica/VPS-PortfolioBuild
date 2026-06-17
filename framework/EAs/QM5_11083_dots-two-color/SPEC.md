# QM5_11083_dots-two-color — Strategy Spec

**EA ID:** QM5_11083
**Slug:** `dots-two-color`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (EarnForex "Dots", GitHub + article)
**Author of this spec:** Claude
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

The EarnForex "Dots" indicator (based on NonLagDOT by TrendLaboratory) plots a
low-lag moving average and colors each dot by the slope of that line: a rising
line gives a bullish dot, a falling line gives a bearish dot. The source's
"simple strategy" is to enter when two same-color dots appear. We mechanize the
low-lag MA with the framework LWMA(length=10) reader (the nearest framework
primitive to NonLagMA; less lag than SMA). The dot color at closed bar shift s
is the sign of LWMA[s] − LWMA[s+1]. Go LONG when the last two closed dots
(shift 1 and 2) are both bullish AND the dot before them (shift 3) was not
bullish — a fresh two-bullish-dot transition, so it fires once per swing. Go
SHORT on the mirror condition. Exit when an opposite-color dot appears at the
latest closed bar (a bearish dot closes a long; a bullish dot closes a short).
A catastrophic ATR(14) stop at 2.5× ATR can close first. No fixed take-profit —
the exit is dot-driven.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_dots_length` | 10 | 5-50 | LWMA smoothing length for the Dots line (card Length=10) |
| `strategy_atr_period` | 14 | 7-30 | ATR period for the catastrophic stop |
| `strategy_sl_atr_mult` | 2.5 | 1.0-5.0 | Catastrophic stop distance = mult × ATR (card P2 baseline) |
| `strategy_spread_pct_of_stop` | 15.0 | 5.0-50.0 | Block entry only if spread exceeds this % of the stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep-liquidity major; clean trend-swing behaviour suits the slope-color signal.
- `GBPUSD.DWX` — liquid major with sustained directional swings on H1.
- `USDJPY.DWX` — liquid major; trend persistence fits two-same-color confirmation.
- `XAUUSD.DWX` — strong trending metal; H1 swings give the indicator room to color-flip.

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500) — card targets FX majors + gold only; not validated here.

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
| Trades / year / symbol | `35` |
| Typical hold time | `hours to a few days (H1 trend swing)` |
| Expected drawdown profile | `moderate; whipsaw losses in chop, runners in trends` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `forum/indicator (EarnForex public repository + article)`
**Pointer:** `https://github.com/EarnForex/Dots` / `https://www.earnforex.com/metatrader-indicators/Dots/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11083_dots-two-color.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
