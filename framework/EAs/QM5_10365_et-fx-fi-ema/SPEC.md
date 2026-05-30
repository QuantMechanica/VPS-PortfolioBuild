# QM5_10365_et-fx-fi-ema - Strategy Spec

**EA ID:** QM5_10365
**Slug:** `et-fx-fi-ema`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA evaluates closed H1 bars on the registered FX symbols. It buys when EMA(5) crosses above EMA(12), RSI(14) is above 50, and the 14-period EMA of Force Index is above zero; it sells on the symmetric bearish conditions. Entries are market orders on the next H1 bar after the closed-bar signal, with a fixed 100-pip stop and 250-pip target. Open positions are moved to breakeven after +80 pips and then trailed by a 100-pip step after +190 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema_period` | 5 | >=1 | Fast EMA period used for the cross. |
| `strategy_slow_ema_period` | 12 | > fast EMA | Slow EMA period used for the cross. |
| `strategy_rsi_period` | 14 | >=1 | RSI confirmation period. |
| `strategy_rsi_midline` | 50.0 | 0-100 | RSI threshold for long above and short below. |
| `strategy_force_index_period` | 14 | >=1 | EMA period applied to raw Force Index. |
| `strategy_stop_pips` | 100 | >0 | Fixed source stop in pips. |
| `strategy_target_pips` | 250 | >0 | Fixed source profit target in pips. |
| `strategy_breakeven_trigger_pips` | 80 | >0 | Profit in pips before moving stop to breakeven. |
| `strategy_breakeven_buffer_pips` | 0 | >=0 | Breakeven stop buffer in pips. |
| `strategy_trail_trigger_pips` | 190 | >0 | Profit in pips before trailing begins. |
| `strategy_trail_step_pips` | 100 | >0 | Step trailing distance in pips. |
| `strategy_spread_median_bars` | 48 | >=3 | H1 bars used for the rolling spread median. |
| `strategy_spread_median_mult` | 2.5 | >0 | Entry is skipped when current spread exceeds this multiple of the median. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair.
- `GBPUSD.DWX` - card-listed major FX pair.
- `USDCHF.DWX` - card-listed major FX pair.
- `USDCAD.DWX` - card-listed major FX pair.
- `AUDUSD.DWX` - card-listed major FX pair.
- `NZDUSD.DWX` - card-listed major FX pair.
- `EURJPY.DWX` - card-listed cross FX pair.
- `GBPJPY.DWX` - card-listed cross FX pair.

**Explicitly NOT for:**
- Equity index and commodity DWX symbols - the source card defines this as a forex EMA/RSI/Force Index swing setup.

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
| Typical hold time | `hours to days` |
| Expected drawdown profile | `Medium; vulnerable to range whipsaws and fixed-pip scaling differences across FX pairs.` |
| Regime preference | `trend-following swing` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/an-effective-swing-trading-strategy.237496/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10365_et-fx-fi-ema.md`

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
| v1 | 2026-05-25 | Initial build from card | 8324302b-12f1-4028-9e2e-80259ff8b146 |
