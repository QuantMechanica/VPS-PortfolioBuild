# QM5_12436_ea31337-wpr - Strategy Spec

**EA ID:** QM5_12436
**Slug:** ea31337-wpr
**Source:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233 (GitHub topic:mql5 — EA31337/Strategy-WPR)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

The EA trades a raw EA31337 Williams %R reentry rule on closed bars. A long
signal occurs when WPR(18) has reentered above `-50 - SignalOpenLevel`
(default -90) after the 4-bar minimum dipped below that same level, is
rising versus the prior closed bar, and rose by at least
`SignalOpenLevel / 10` percent versus 3 bars back. A short signal mirrors
that rule below `-50 + SignalOpenLevel` (default -10) with WPR falling.
Positions use fixed SL/TP and close earlier when the opposite WPR reentry
signal appears or after 30 bars.

**Framework addition:** `QM_WPR(sym, tf, period, shift)` did not exist yet
in this worktree's `QM_Indicators.mqh` (only in a newer checkout state per
prior worktree-staleness findings). Added it following the exact existing
`QM_CCI`/`QM_Stoch_K` pattern (handle-pooled via
`QM_IndicatorsLookup`/`QM_IndicatorsRegister`, single-buffer `iWPR` read) —
no reimplementation, same sanctioned indicator-cache mechanism as every
other `QM_*` reader.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wpr_period` | 18 | 1+ | Williams %R period from the EA31337 source default. |
| `strategy_signal_open_level` | 40.0 | >0 and <50 preferred | Distance from -50 used for long/short reentry+extreme thresholds. |
| `strategy_signal_open_method` | 0 | 0 only in V5 baseline | Compatibility switch; method 0 uses the raw WPR rule. |
| `strategy_stop_pips` | 80 | 1+ | Fixed stop-loss distance in pips. |
| `strategy_take_pips` | 80 | 1+ | Fixed take-profit distance in pips. |
| `strategy_max_hold_bars` | 30 | 1+ | Time exit after this many chart bars. |
| `strategy_max_spread_pips` | 4.0 | 0+ | Blocks only genuinely wide spreads above this pip distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair from the card's suggested first test universe.
- `GBPUSD.DWX` - liquid major FX pair from the card's suggested first test universe.
- `USDJPY.DWX` - liquid major FX pair from the card's suggested first test universe.
- `XAUUSD.DWX` - liquid metal CFD from the card's suggested first test universe.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - no DWX tester data is available.
- Non-FX/non-metal symbols - outside the card's first test universe for this raw WPR baseline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

M15 setfiles are generated as the card's secondary intraday candidate, using the same closed-bar rule on the chart timeframe.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 (card estimate) |
| Typical hold time | Intraday, maximum 30 chart bars |
| Expected drawdown profile | Mean-reversion oscillator losses bounded by fixed SL |
| Regime preference | Mean-reversion / oscillator reentry |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Source type:** GitHub repository
**Pointer:** https://github.com/EA31337/Strategy-WPR/blob/master/Stg_WPR.mqh and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12436_ea31337-wpr.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12436_ea31337-wpr.md`

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
| v1 | 2026-08-10 | Initial build from card; added `QM_WPR` to `QM_Indicators.mqh` | agents/claude-orchestration-2 |
