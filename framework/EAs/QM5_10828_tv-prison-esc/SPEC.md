# QM5_10828_tv-prison-esc - Strategy Spec

**EA ID:** QM5_10828
**Slug:** tv-prison-esc
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades an M5 morning breakout from confirmed structural pivots after 08:30 America/Chicago. It records confirmed A-D pivots, builds the selected pivot range, and buys after two consecutive closed bars finish above the range high or sells after two consecutive closed bars finish below the range low. The stop is the opposite side of the selected range and the target is fixed 1R from entry to stop. New entries are limited to the 08:30-10:30 America/Chicago window, and open positions are force-closed at 12:30 America/Chicago.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_pivot_depth | 5 | 1-20 | Confirmed pivot depth on each side of the candidate bar. |
| strategy_selected_first_pivot | 0 | 0-7 | First selected pivot letter, where A=0. |
| strategy_selected_last_pivot | 3 | 0-7 | Last selected pivot letter, where D=3 for the baseline. |
| strategy_confirm_closes | 2 | 1-4 | Number of consecutive closed bars required outside the range. |
| strategy_atr_period | 14 | 1+ | ATR period for range-width and optional FVG filters. |
| strategy_min_range_atr_mult | 0.50 | 0+ | Minimum allowed selected-range width as ATR multiple. |
| strategy_max_range_atr_mult | 3.00 | >= min | Maximum allowed selected-range width as ATR multiple. |
| strategy_fvg_atr_mult | 0.00 | 0+ | Optional FVG width filter; 0 disables, 0.50 matches the card example. |
| strategy_rr_target | 1.00 | 0.1+ | Fixed R multiple target measured from entry to stop. |
| strategy_entry_start_hhmm | 830 | HHMM | America/Chicago entry window start. |
| strategy_entry_end_hhmm | 1030 | HHMM | America/Chicago entry window end. |
| strategy_flat_hhmm | 1230 | HHMM | America/Chicago hard-flat time. |
| strategy_one_trade_per_day | true | true/false | Preserves the one-position baseline and disables second-trade behavior. |
| strategy_max_spread_points | 0 | 0+ | Optional spread gate; 0 disables. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 index CFD exposure from the card's P2 basket.
- WS30.DWX - Dow 30 index CFD exposure from the card's P2 basket.
- GDAXI.DWX - Canonical available DAX custom symbol; used because GER40.DWX is not in the DWX matrix.
- XAUUSD.DWX - Gold/metals exposure from the card's P2 basket.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; replaced with GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday, bounded by 08:30-12:30 America/Chicago |
| Expected drawdown profile | High-frequency opening breakout profile with spread and slippage sensitivity |
| Regime preference | Volatility-expansion breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** TraderHayz, Prison Escape Breakout Strategy, TradingView open-source strategy, May 9 / updated May 10.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10828_tv-prison-esc.md`

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
| v1 | 2026-06-06 | Initial build from card | 86cb48a2-2b29-4d89-a5f5-0fb57ef85a2d |
