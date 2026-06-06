# QM5_10917_grimes-freebar - Strategy Spec

**EA ID:** QM5_10917
**Slug:** `grimes-freebar`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (see `strategy-seeds/sources/fbfd7f6e-462a-55c8-9efa-9005a70c9f5c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H4 continuation after an Adam Grimes free bar. A long setup requires a bar within the last 10 bars whose low is above the EMA(20) + 2.25 * ATR(20) Keltner upper band, followed by 2-8 consolidation bars that do not close below EMA(20). It buys when the latest closed bar closes above the consolidation high; shorts mirror the rule below the lower band and below EMA(20). Stops are set beyond the consolidation extreme by 0.25 * ATR(20), targets are 1.5R, the stop trails by 2.0 * ATR(20) after price reaches 1R, and positions time out after 12 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_keltner_period` | 20 | 2-100 | EMA and ATR period for the Keltner channel. |
| `strategy_keltner_atr_mult` | 2.25 | 0.5-5.0 | ATR multiple added/subtracted from EMA for free-bar bands. |
| `strategy_freebar_lookback_bars` | 10 | 1-50 | Maximum closed-bar lookback for the qualifying free bar. |
| `strategy_pullback_min_bars` | 2 | 1-20 | Minimum consolidation bars after the free bar. |
| `strategy_pullback_max_bars` | 8 | 1-30 | Maximum consolidation bars after the free bar. |
| `strategy_climax_window_bars` | 12 | 3-50 | Window used to count same-direction free bars. |
| `strategy_max_freebars_same_dir` | 3 | 1-10 | Blocks entries when same-direction free bars exceed this count. |
| `strategy_stop_buffer_atr_mult` | 0.25 | 0.0-2.0 | ATR buffer beyond the consolidation high/low for stop placement. |
| `strategy_max_stop_atr_mult` | 3.00 | 0.5-10.0 | Rejects entries with stop distance above this ATR multiple. |
| `strategy_target_r_mult` | 1.50 | 0.5-10.0 | Fixed profit target in R. |
| `strategy_trail_start_r_mult` | 1.00 | 0.5-5.0 | Starts ATR trailing after this R multiple is reached. |
| `strategy_trail_atr_mult` | 2.00 | 0.5-10.0 | ATR multiple used by the trailing stop. |
| `strategy_spread_stop_frac` | 0.10 | 0.01-0.50 | Maximum spread as a fraction of stop distance. |
| `strategy_max_hold_bars` | 12 | 1-100 | Time exit in base timeframe bars. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair from the card's R3 basket.
- `GBPUSD.DWX` - liquid major FX pair from the card's R3 basket.
- `XAUUSD.DWX` - liquid metal symbol from the card's R3 basket.
- `GDAXI.DWX` - canonical DWX DAX symbol; the card states `GER40.DWX`, which is not in `dwx_symbol_matrix.csv`.
- `NDX.DWX` - liquid index symbol from the card's R3 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; registered as `GDAXI.DWX` instead.

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
| Trades / year / symbol | `20` |
| Typical hold time | `up to 12 H4 bars` |
| Expected drawdown profile | `Momentum continuation with bounded 1R stops and 1.5R targets; clustered losses possible in failed breakouts.` |
| Regime preference | `momentum-continuation / volatility-expansion` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** `blog`
**Pointer:** `Adam H. Grimes, Free bars: little patterns after big moves, 2021-02-26, https://www.adamhgrimes.com/free-bars-little-patterns-after-big-moves/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10917_grimes-freebar.md`

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
| v1 | 2026-06-06 | Initial build from card | a47cf98d-51e9-4225-9dab-f9c5ee009a7b |
