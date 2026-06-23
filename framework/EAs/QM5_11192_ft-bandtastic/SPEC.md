# QM5_11192_ft-bandtastic — Strategy Spec

**EA ID:** QM5_11192
**Slug:** `ft-bandtastic`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

Long-only Bollinger mean reversion ported from Robert Roman's freqtrade
`Bandtastic.py`. On the close of an M15 bar, enter long when the closed-bar
close prints below the lower Bollinger Band(20) at `bb_entry_std` deviations
(source default 1 std) — a stretched-below-the-band reversion buy. The source
"volume > 0" guard is implemented as a single closed-bar tick-volume check.
The RSI/MFI/EMA buy guards are disabled by source default (an optional RSI buy
guard is provided, off by default, for the P3 sweep). Exit when the source ROI
ladder is reached, or when BOTH source
signal-exit conditions hold: MFI(14) on tick volume is above `mfi_exit` (source
46) AND the close is above the upper Bollinger Band(20) at `bb_exit_std`
deviations (source 2). A source trailing stop activates after the configured
profit offset and ratchets the stop below current price. A protective ATR stop,
`QM_StopATR(14, atr_stop_mult)`, is the MT5 baseline for the source stoploss;
framework Friday close also applies. No fixed take-profit is set.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 10-50 | Bollinger Band period |
| `strategy_bb_entry_std` | 1.0 | 1-3 | Lower-band deviation for the entry trigger |
| `strategy_bb_exit_std` | 2.0 | 1-3 | Upper-band deviation for the signal exit |
| `strategy_mfi_period` | 14 | 7-28 | Money Flow Index period (tick volume) |
| `strategy_mfi_exit` | 46.0 | 40-55 | MFI threshold for the signal exit |
| `strategy_enable_rsi_guard` | false | false/true | Enable optional RSI buy guard |
| `strategy_rsi_period` | 14 | 7-28 | RSI period for the optional buy guard |
| `strategy_rsi_guard_max` | 50.0 | 30-70 | If guard on: require RSI(1) below this |
| `strategy_atr_period` | 14 | 7-28 | ATR period for the protective stop |
| `strategy_atr_stop_mult` | 2.0 | 1.5-2.5 | Stop distance = mult × ATR |
| `strategy_spread_pct_of_stop` | 8.0 | 1-20 | Skip if spread > this % of stop distance |
| `strategy_warmup_bars` | 999 | 999+ | Minimum bars before trading |
| `strategy_roi_pct_0` | 16.2 | fixed/source | Immediate ROI exit threshold |
| `strategy_roi_min_1` | 69 | fixed/source | Minutes before first lower ROI threshold |
| `strategy_roi_pct_1` | 9.7 | fixed/source | ROI threshold after `strategy_roi_min_1` |
| `strategy_roi_min_2` | 229 | fixed/source | Minutes before second lower ROI threshold |
| `strategy_roi_pct_2` | 6.1 | fixed/source | ROI threshold after `strategy_roi_min_2` |
| `strategy_roi_min_flat` | 566 | fixed/source | Minutes before breakeven-or-better ROI exit |
| `strategy_trail_offset_pct` | 5.8 | fixed/source | Profit offset before trailing activates |
| `strategy_trail_distance_pct` | 1.0 | fixed/source | Trail distance below current price |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; mean reversion to the band well-behaved.
- `GBPUSD.DWX` — liquid major with intraday range suiting M15 reversion.
- `USDJPY.DWX` — liquid major; tick-volume MFI portable.
- `XAUUSD.DWX` — metal with strong intraday mean-reversion episodes.

**Explicitly NOT for:**
- Index CFDs (`NDX.DWX`, `WS30.DWX`, `SP500.DWX`) — card baskets FX/metals only;
  trend persistence on indices works against a band-fade long.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `200` (capped conservative estimate after spread/news filters) |
| Typical hold time | `hours` (intraday M15 reversion) |
| Expected drawdown profile | `high risk class; reversion clusters in trends until the ATR stop trims` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** `forum` (open-source freqtrade strategy repo)
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Bandtastic.py`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11192_ft-bandtastic.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor worktree |
| v2 | 2026-06-23 | Rebuild in place from card | aea278d6-866d-4f58-8fc4-e9d3a36d3c38 |
