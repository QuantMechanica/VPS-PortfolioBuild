# QM5_10916_grimes-impulse - Strategy Spec

**EA ID:** QM5_10916
**Slug:** grimes-impulse
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades H1 impulse continuation after a reluctant pullback. A long setup requires at least three of five impulse bars to close higher, an impulse move from start low to impulse high of at least 2.0 ATR(14), the impulse close above EMA(50), then a 2-8 bar pullback whose average range is below 0.8 ATR(14) and whose retracement is no deeper than 38.2% of the impulse. The EA enters long when the last closed H1 bar breaks above the pullback high; shorts mirror the same rules for downside impulses and shallow bounces. Stops sit beyond the pullback extreme by 0.25 ATR(14), targets are fixed at 1.5R, the stop trails by 2.0 ATR(14) after price reaches 1R, and positions time out after 18 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | 2-100 | ATR period used for impulse size, pullback contraction, stops, and trailing. |
| strategy_ema_period | 50 | 2-300 | EMA trend filter applied to the final impulse close. |
| strategy_impulse_bars | 5 | fixed at 5 | Number of bars in the impulse window from the card. |
| strategy_impulse_min_closes | 3 | 1-5 | Minimum higher or lower closes in the impulse window. |
| strategy_impulse_atr_mult | 2.0 | 0.1-10.0 | Minimum impulse move as a multiple of ATR(14). |
| strategy_min_pullback_bars | 2 | 1-20 | Minimum reluctant pullback length after the impulse. |
| strategy_max_pullback_bars | 8 | 1-30 | Maximum reluctant pullback length after the impulse. |
| strategy_max_retrace_fraction | 0.382 | 0.01-0.49 | Maximum permitted pullback retracement of the impulse. |
| strategy_pullback_range_atr_mult | 0.80 | 0.1-5.0 | Pullback average range must be below this ATR multiple. |
| strategy_stop_buffer_atr_mult | 0.25 | 0.0-2.0 | ATR buffer beyond pullback low or high for the stop. |
| strategy_max_stop_atr_mult | 2.50 | 0.1-10.0 | Maximum accepted stop distance as an ATR multiple. |
| strategy_target_r_multiple | 1.50 | 0.1-10.0 | Fixed take-profit distance in R multiples. |
| strategy_trail_trigger_r | 1.00 | 0.1-5.0 | Open profit in R required before trailing begins. |
| strategy_trail_atr_mult | 2.00 | 0.1-10.0 | ATR multiple for trailing from the highest or lowest close since entry. |
| strategy_spread_stop_fraction | 0.10 | 0.0-1.0 | Maximum spread as a fraction of stop distance. |
| strategy_time_exit_bars | 18 | 1-200 | Maximum hold time in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - card-listed S&P 500 proxy; valid DWX custom symbol for backtest-only index exposure.
- NDX.DWX - card-listed Nasdaq 100 proxy with DWX data and live-tradable large-cap index exposure.
- GDAXI.DWX - matrix-available DAX custom symbol used for the card's GER40.DWX DAX exposure.
- XAUUSD.DWX - card-listed gold symbol with DWX data and suitable volatility for impulse-pullback tests.

**Explicitly NOT for:**
- GER40.DWX - card-listed name is not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.
- SPX500.DWX, SPY.DWX, ES.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; SP500.DWX is the canonical available S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Up to 18 H1 bars |
| Expected drawdown profile | Continuation drawdowns should cluster when shallow pullbacks become full mean-reversion against the impulse. |
| Regime preference | Sharp impulse followed by reluctant pullback; trend-continuation / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "Impulse Moves and Market Patterns: A Real-Time S&P 500 Example", 2024-07-28, https://www.adamhgrimes.com/impulse-moves-and-market-patterns-a-real-time-sp-500-example/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10916_grimes-impulse.md`

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
| v1 | 2026-06-06 | Initial build from card | aaab58cc-7075-4193-87fd-d641417e83a1 |
