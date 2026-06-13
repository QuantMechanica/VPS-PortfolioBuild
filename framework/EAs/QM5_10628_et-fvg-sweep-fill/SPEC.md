# QM5_10628_et-fvg-sweep-fill - Strategy Spec

**EA ID:** QM5_10628
**Slug:** et-fvg-sweep-fill
**Source:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades completed M15 fair value gaps that form after price sweeps a recent H4 or D1 swing level and closes back through that level. A long setup requires a sweep below a higher-timeframe swing low, bullish displacement, and a bullish three-candle FVG; the EA places a buy limit at the configured FVG fill level with a stop below the sweep low. A short setup mirrors this after a sweep above a higher-timeframe swing high. Exits use the opposing M15 swing target capped at 2R, close-through-FVG invalidation, the framework Friday close, or a 24-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | 2-100 | ATR period used for sweep depth, displacement, and FVG width filters. |
| strategy_h4_swing_lookback | 60 | 10-240 | H4 bars scanned for higher-timeframe swing levels. |
| strategy_d1_swing_lookback | 15 | 5-60 | D1 bars scanned for higher-timeframe swing levels. |
| strategy_sweep_depth_atr | 0.20 | 0.05-1.00 | Minimum sweep beyond the HTF level, in ATR units. |
| strategy_sweep_reclaim_bars | 3 | 1-10 | Bars allowed for close-back-through-level confirmation. |
| strategy_displacement_window | 8 | 1-24 | Bars allowed from reclaim to FVG displacement. |
| strategy_displacement_body_atr | 1.20 | 0.50-3.00 | Minimum body size of the displacement candle, in ATR units. |
| strategy_displacement_close_pct | 0.25 | 0.05-0.50 | Required close location in the top/bottom part of displacement range. |
| strategy_fvg_min_width_atr | 0.15 | 0.01-1.00 | Minimum FVG width, in ATR units. |
| strategy_fvg_max_width_atr | 1.20 | 0.10-3.00 | Maximum FVG width, in ATR units. |
| strategy_fvg_fill_level | 0.50 | 0.25-0.75 | Limit entry fill level inside the FVG zone. |
| strategy_max_spread_width_frac | 0.20 | 0.01-0.50 | Maximum spread as a fraction of FVG width. |
| strategy_max_fvg_level_atr | 1.50 | 0.25-5.00 | Maximum distance between FVG entry and swept HTF level. |
| strategy_pending_bars | 6 | 1-24 | Pending limit order lifetime in M15 bars. |
| strategy_m15_swing_lookback | 20 | 5-100 | M15 bars scanned for the opposing liquidity target. |
| strategy_time_exit_bars | 24 | 1-96 | Maximum hold time in M15 bars. |
| strategy_rr_cap | 2.00 | 0.50-5.00 | Maximum reward:risk target cap. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-approved DWX FX target with liquid M15 OHLC history.
- GBPUSD.DWX - card-approved DWX FX target with liquid M15 OHLC history.
- XAUUSD.DWX - card-approved DWX gold target where liquidity-sweep/FVG structure is portable.
- SP500.DWX - card-approved S&P 500 custom symbol for backtest-only validation.
- NDX.DWX - card-approved Nasdaq 100 index target and live-tradable US index proxy.

**Explicitly NOT for:**
- SPY.DWX - not present in `dwx_symbol_matrix.csv`; SP500.DWX is the canonical S&P 500 custom symbol.
- SPX500.DWX - not present in `dwx_symbol_matrix.csv`.
- ES.DWX - not present in `dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | H4 and D1 swing highs/lows; M15 opposing swing target |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Up to 24 M15 bars, usually intraday |
| Expected drawdown profile | Mean-reversion entries after liquidity sweeps; losses cluster during continuation moves through swept levels. |
| Regime preference | Mean-reversion after displacement and liquidity sweep |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/fair-value-gaps.372648/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10628_et-fvg-sweep-fill.md`

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
| v1 | 2026-06-13 | Initial build from card | c5188962-f83f-4b9e-a0e3-021a64b721e7 |
