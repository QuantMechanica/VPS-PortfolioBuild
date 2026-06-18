# QM5_11317_tc-m5-9-ema50-100-macd — Strategy Spec

**EA ID:** QM5_11317
**Slug:** `tc-m5-9-ema50-100-macd`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Trend-continuation scalp on M5 from Thomas Carter "20 Forex Trading Strategies
(5 Minute Time Frame)", 5 Min Trading System #9. EMA(50) and EMA(100) form the
trend regime gate. Go LONG when the closed M5 bar closes above both EMAs, is at
least 10 pips above EMA(50), and sits above the higher of the two EMAs (price is
not inside the EMA band) — AND the MACD(12,26,9) main line has crossed zero from
below within the last 5 closed bars and is still positive. SHORT is the mirror
image (below both EMAs, ≥10 pips below EMA(50), below the lower EMA, MACD crossed
zero downward within 5 bars and still negative). The MACD zero-cross is the single
entry EVENT; the EMA stack and distance are STATES on the trigger bar — this
avoids the "two fresh crosses on one bar" zero-trade trap. Initial stop is the
5-bar low (long) / 5-bar high (short). Take 50% partial profit at 2R and move the
remainder's stop to breakeven. Final exit when the closed bar breaks EMA(50) by
10 pips against the position. Spread filter (fail-open) and Friday-close guard apply.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 50 | 20-100 | Fast EMA: trend gate + exit anchor |
| `strategy_ema_slow_period` | 100 | 50-200 | Slow EMA: trend gate |
| `strategy_macd_fast` | 12 | 5-20 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 15-40 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 5-15 | MACD signal EMA period |
| `strategy_macd_cross_lookback` | 5 | 3-8 | MACD zero-cross EVENT recency (closed bars) |
| `strategy_distance_pips` | 10 | 5-15 | Min distance of close beyond EMA(50) |
| `strategy_structure_bars` | 5 | 3-10 | Initial SL = N-bar low (long) / high (short) |
| `strategy_tp1_r_multiple` | 2.0 | 1.0-3.0 | R-multiple for partial take-profit |
| `strategy_partial_close_ratio` | 0.50 | 0.25-0.75 | Fraction closed at TP1 |
| `strategy_be_buffer_pips` | 0 | 0-10 | Breakeven offset after partial |
| `strategy_exit_break_pips` | 10 | 5-20 | EMA(50)-break distance for final exit |
| `strategy_spread_cap_pips` | 20 | 10-30 | Max spread (fail-open; M5 baseline) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deepest-liquidity major; tight spreads suit M5 scalping.
- `GBPUSD.DWX` — liquid major with directional intraday trends.
- `USDJPY.DWX` — liquid major; pip-factor handled via QM_StopRules pip scaling.

**Explicitly NOT for:**
- Index / metal CFDs — card is a forex M5 system; EMA-distance in pips is tuned for FX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_M5)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~120` |
| Typical hold time | `minutes to a few hours` |
| Expected drawdown profile | `moderate; structure stop + breakeven after 2R caps single-trade loss` |
| Regime preference | `trend / breakout` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)" (2014), 5 Min Trading System #9, pp. 24-25 (local PDF archive)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11317_tc-m5-9-ema50-100-macd.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
