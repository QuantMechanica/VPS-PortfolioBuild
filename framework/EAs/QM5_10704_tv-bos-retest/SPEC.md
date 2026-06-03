# QM5_10704_tv-bos-retest - Strategy Spec

**EA ID:** QM5_10704
**Slug:** tv-bos-retest
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA waits for a confirmed swing high or swing low using separate left-bar and right-bar pivot settings. A long setup begins when the last closed bar breaks above a confirmed swing high; the EA then waits for price to retest that broken level and close back above it inside the configured retest window. A short setup is the mirror image below a confirmed swing low. Stops are frozen from the opposite swing with an ATR floor, and the default baseline exits the full position at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_pivot_left | 16 | >=1 | Bars to the left of a pivot that define swing significance. |
| strategy_pivot_right | 3 | >=1 | Bars to the right of a pivot that confirm the swing. |
| strategy_retest_window_bars | 15 | >=1 | Maximum bars after BOS for a valid retest entry. |
| strategy_bos_max_age_bars | 30 | >=1 | Maximum age of a confirmed BOS level. |
| strategy_reclaim_mode | 0 | 0-2 | Retest confirmation: 0 close, 1 wick rejection, 2 full bar reclaim. |
| strategy_atr_period | 14 | >=1 | ATR period used for minimum stop distance and buffers. |
| strategy_atr_min_stop_mult | 1.25 | >0 | Minimum stop distance in ATR multiples. |
| strategy_structure_buffer_atr | 0.10 | >=0 | Extra ATR buffer beyond the swing stop. |
| strategy_rr_target | 2.00 | >0 | Full-position target when scale-out is disabled. |
| strategy_volume_filter_enabled | false | true/false | Enables above-average tick-volume filter on the BOS bar. |
| strategy_volume_lookback_bars | 20 | >=2 | Lookback for average tick volume. |
| strategy_volume_min_ratio | 1.20 | >0 | BOS volume must exceed average volume by this ratio. |
| strategy_scale_out_enabled | false | true/false | Enables optional thirds-style TP1/TP2/TP3 management. |
| strategy_tp1_rr | 1.00 | >0 | First scale-out R multiple. |
| strategy_tp2_rr | 2.00 | >0 | Second scale-out R multiple. |
| strategy_tp3_rr | 3.00 | >0 | Final broker target R multiple when scale-out is enabled. |
| strategy_tp1_close_fraction | 0.33 | 0-1 | Fraction of initial lots to close at TP1. |
| strategy_tp2_close_fraction | 0.33 | 0-1 | Fraction of initial lots to close at TP2. |
| strategy_be_buffer_atr_mult | 0.05 | >=0 | ATR buffer added to breakeven after TP1. |
| strategy_sunday_filter_enabled | true | true/false | Blocks Sunday trades on FX symbols. |
| strategy_session_filter_enabled | false | true/false | Optional intraday time window. |
| strategy_session_start_minute | 420 | 0-1439 | Session start minute of broker day. |
| strategy_session_end_minute | 1320 | 0-1439 | Session end minute of broker day. |
| strategy_max_spread_points | 250 | >=0 | Blocks entries when spread exceeds this many points; 0 disables. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - liquid Nasdaq 100 index CFD in the approved R3 basket.
- WS30.DWX - liquid Dow 30 index CFD in the approved R3 basket.
- GDAXI.DWX - canonical DWX DAX symbol used as the nearest available port for the card's GER40.DWX wording.
- XAUUSD.DWX - canonical DWX gold symbol used for the card's XAUUSD wording.
- EURUSD.DWX - liquid FX major in the approved R3 basket.
- GBPUSD.DWX - liquid FX major in the approved R3 basket.

**Explicitly NOT for:**
- GER40.DWX - not present in `dwx_symbol_matrix.csv`; use GDAXI.DWX.
- XAUUSD - unsuffixed symbols are not used in V5 backtests; use XAUUSD.DWX.
- Symbols outside the approved R3 basket - not registered for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 160 |
| Typical hold time | intraday, usually minutes to hours |
| Expected drawdown profile | explicit structure/ATR stops with fixed-risk sizing |
| Regime preference | break-of-structure breakout followed by retest |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView protected-source strategy
**Pointer:** https://www.tradingview.com/script/MFZfW0AE-Break-Retest-Scale-v1/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10704_tv-bos-retest.md`

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
| v1 | 2026-05-31 | Initial build from card | 7bbcb789-7160-439c-8eda-0cad1c784490 |
