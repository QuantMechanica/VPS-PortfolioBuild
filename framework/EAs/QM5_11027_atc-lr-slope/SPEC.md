# QM5_11027_atc-lr-slope — Strategy Spec

**EA ID:** QM5_11027
**Slug:** `atc-lr-slope`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (Andrey Barinov, Interview ATC 2012, MQL5 Articles)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

On the close of each H1 bar the EA fits an ordinary-least-squares linear-regression
line over the last `strategy_lr_period` closed bars and takes its slope (price per
bar). The raw slope is normalised by ATR(`strategy_atr_period`) and expressed as a
slope angle in degrees (`angle = atan(slope_per_bar / ATR) * 180/pi`) so the
threshold is scale-invariant across FX pairs. The EA goes long when the slope angle
is at least `strategy_long_slope_thresh` and short when it is at most
`strategy_short_slope_thresh`, taking at most one open position per symbol/magic. An
optional ADX filter (active when `strategy_adx_min > 0`) requires ADX above the floor.
Each position is protected by a fixed ATR stop (`strategy_sl_atr_mult * ATR`), moved
to break-even after price advances `strategy_breakeven_atr * ATR`, then ATR-trailed
(`strategy_trail_atr_mult * ATR`) once price advances `strategy_trail_start_atr * ATR`.
A position is closed at market when the slope flips to the opposite side past its
threshold (opposite-signal exit). The linear-regression slope is a bounded,
deterministic closed-bar computation evaluated once per new bar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lr_period` | 48 | 24-96 | Bars in the linear-regression window |
| `strategy_long_slope_thresh` | 10.0 | 5-15 | Long if slope angle (deg) >= this |
| `strategy_short_slope_thresh` | -10.0 | -15 to -5 | Short if slope angle (deg) <= this |
| `strategy_atr_period` | 14 | 7-21 | ATR period (normaliser / stop / trail) |
| `strategy_sl_atr_mult` | 2.0 | 1.0-2.5 | Stop distance = mult * ATR |
| `strategy_breakeven_atr` | 1.0 | 0.75-1.5 | Move SL to entry after this many ATR |
| `strategy_trail_start_atr` | 1.5 | 1.0-2.0 | Start ATR trail after this many ATR |
| `strategy_trail_atr_mult` | 2.0 | 1.0-3.0 | ATR trail distance multiple |
| `strategy_adx_min` | 0.0 | 0/18/25 | Optional ADX trend filter (0 = off) |
| `strategy_adx_period` | 14 | 7-21 | ADX period when adx_min > 0 |
| `strategy_spread_pct_of_stop` | 15.0 | 5-30 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary trend-following major in the card's source basket.
- `USDJPY.DWX` — major in the source basket; ATR-normalised slope handles JPY pip scale.
- `EURJPY.DWX` — cross from the source basket; sustained trend behaviour.
- `GBPUSD.DWX` — P2/P3 robustness major named in the card R3 basket.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the card source and slope-angle calibration are FX-major specific.

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
| Trades / year / symbol | `35 (range 20-60)` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `whipsaw losses in flat regimes, bounded by ATR stop + fixed risk` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** `forum` (MQL5 Articles interview)
**Pointer:** `https://www.mql5.com/en/articles/562`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11027_atc-lr-slope.md`

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
