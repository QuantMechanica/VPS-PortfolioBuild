# QM5_10934_grimes-pong - Strategy Spec

**EA ID:** QM5_10934
**Slug:** grimes-pong
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades an M15 two-level range. It builds candidate levels from the previous D1 high, previous D1 low, previous D1 close, and confirmed H1 pivot highs and lows. A valid range has two levels one to three ATR(20, M15) apart, with both levels touched in the last 32 M15 bars. A long enters at the next bar open after the lower level is probed and the closed M15 bar finishes back above it with a lower wick of at least 35 percent of the bar range; short entries mirror this at the upper level. Targets sit just inside the opposite level, stops sit 0.35 ATR outside the entry-side level, stops move to breakeven at the range midpoint, and positions exit after 12 M15 bars or near broker day end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 20 | 5-100 | ATR period for range width, entry proximity, stop, and breakout pads. |
| strategy_adx_period | 14 | 5-50 | ADX period for the trend-day filter. |
| strategy_adx_max | 28.0 | 5.0-60.0 | Blocks new trades when ADX is above this value. |
| strategy_touch_lookback_bars | 32 | 8-200 | M15 lookback used to confirm both range levels were touched. |
| strategy_h1_pivot_lookback | 48 | 8-200 | H1 bars scanned for confirmed pivot highs and lows. |
| strategy_min_range_atr | 1.0 | 0.5-5.0 | Minimum two-level range width in ATR units. |
| strategy_max_range_atr | 3.0 | 1.0-8.0 | Maximum two-level range width in ATR units. |
| strategy_touch_atr_mult | 0.15 | 0.01-1.00 | ATR distance used for level touches and inside-range targets. |
| strategy_wick_min_fraction | 0.35 | 0.05-0.90 | Minimum wick share of the signal bar range. |
| strategy_stop_atr_mult | 0.35 | 0.05-2.00 | ATR distance outside the range for the stop loss. |
| strategy_breakout_atr_mult | 0.50 | 0.05-2.00 | Daily disable threshold after a close outside the selected range. |
| strategy_max_hold_bars | 12 | 1-96 | Maximum holding time measured in M15 bars. |
| strategy_session_start_hour | 8 | 0-23 | Broker-hour start for the broad liquid-session filter. |
| strategy_session_end_hour | 22 | 0-24 | Broker-hour end for the broad liquid-session filter. |

---

## 3. Symbol Universe

**Designed for:**
- GDAXI.DWX - matrix-canonical DAX CFD used in place of card-stated GER40.DWX.
- NDX.DWX - Nasdaq 100 index CFD from the approved R3 basket.
- WS30.DWX - Dow 30 index CFD from the approved R3 basket.
- XAUUSD.DWX - gold CFD from the approved R3 basket.
- XTIUSD.DWX - crude oil CFD from the approved R3 basket.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the available DAX symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | D1 previous high/low/close; H1 confirmed pivot highs/lows |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Intraday, capped at 12 M15 bars (about 3 hours) |
| Expected drawdown profile | Mean-reversion losses cluster on trend or breakout days. |
| Regime preference | Range-trading / support-resistance mean reversion |
| Win rate target (qualitative) | Medium to high, with targets inside the opposite range level. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "How to Trade Support and Resistance Levels", 2020-10-16
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10934_grimes-pong.md`

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
| v1 | 2026-06-06 | Initial build from card | d00b6f79-acba-41e3-a1c7-92d9dc7a4b34 |
