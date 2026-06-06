# QM5_10929_grimes-clearair - Strategy Spec

**EA ID:** QM5_10929
**Slug:** grimes-clearair
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c (see approved card citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA evaluates each H1 close for a Clear Air continuation setup. It builds an upper outer level from the previous D1 high and the highest three-bar H1 pivot high over the prior five broker days, and a lower outer level from the previous D1 low and the lowest matching H1 pivot low. It enters long at the next H1 open when the close clears the upper level by at least 0.35 ATR(20), the current broker-day range is at least 1.2 D1 ATR(20), and EMA(20) is rising; shorts mirror this below the lower level with a falling EMA. Initial risk is 1.4 ATR(20), the stop trails behind the last three H1 bars by 0.1 ATR(20), and positions close before broker day end or after an H1 close back inside the outer level.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 20 | 5-100 | ATR period for breakout distance, initial stop, trailing stop, and D1 range filter. |
| strategy_pivot_lookback_days | 5 | 1-20 | Broker days scanned for H1 pivot highs and lows. |
| strategy_breakout_atr_mult | 0.35 | 0.05-2.00 | Required close distance beyond the outer level in ATR units. |
| strategy_daily_range_atr_mult | 1.20 | 0.25-5.00 | Minimum current broker-day range versus D1 ATR. |
| strategy_ema_period | 20 | 5-100 | H1 EMA slope period. |
| strategy_initial_stop_atr_mult | 1.40 | 0.25-5.00 | Initial stop distance in H1 ATR units. |
| strategy_trail_bars | 3 | 1-10 | H1 bars used for the trailing structure stop. |
| strategy_trail_atr_mult | 0.10 | 0.00-2.00 | ATR padding beyond the trailing structure stop. |
| strategy_min_bars_to_day_end | 3 | 1-8 | Minimum full H1 bars remaining before broker day end for new entries. |
| strategy_spread_stop_ratio | 0.08 | 0.00-0.25 | Maximum spread as a fraction of initial stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 index exposure named in the card; valid backtest-only custom symbol.
- NDX.DWX - Nasdaq 100 index exposure named in the card.
- WS30.DWX - Dow 30 index exposure named in the card.
- GDAXI.DWX - Matrix-valid DAX proxy for card-stated GER40.DWX.
- XAUUSD.DWX - Gold exposure named in the card.

**Explicitly NOT for:**
- GER40.DWX - Card-stated symbol is not present in `dwx_symbol_matrix.csv`; GDAXI.DWX is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 ATR(20), previous D1 high, previous D1 low, current D1 open |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Same broker session, up to one trading day |
| Expected drawdown profile | Breakout continuation with ATR-defined losses during failed extensions. |
| Regime preference | Trend / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "How to Trade Support and Resistance Levels", 2020-10-16, https://www.adamhgrimes.com/how-to-trade-support-and-resistance-levels/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10929_grimes-clearair.md`

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
| v1 | 2026-06-06 | Initial build from card | 17086f95-1ac0-45d5-932e-31917c621052 |
