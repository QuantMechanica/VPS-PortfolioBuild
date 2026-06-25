# QM5_11317_tc-m5-9-ema50-100-macd - Strategy Spec

**EA ID:** QM5_11317
**Slug:** tc-m5-9-ema50-100-macd
**Source:** e78a9f1f-4e6a-563c-a080-915133d6ed28 (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades Thomas Carter's M5 System #9 as a trend-continuation scalp. A long entry requires the last closed M5 candle to close above EMA(50) and EMA(100), at least 10 pips above EMA(50), while MACD main(12,26,9) has crossed from non-positive to positive within the last five closed bars. A short entry mirrors the rule below both EMAs with a recent MACD zero-cross down. The initial stop is the prior five-bar structure low or high, the baseline take profit is a full 2R exit, and a defensive exit closes any remainder when price closes 10 pips through EMA(50) against the trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 50 | 1+ | EMA(50) trend gate and defensive exit anchor. |
| `strategy_ema_slow_period` | 100 | > fast | EMA(100) trend gate. |
| `strategy_macd_fast` | 12 | 1+ | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | > fast | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 1+ | MACD signal period. |
| `strategy_macd_cross_lookback` | 5 | 1+ | Closed-bar lookback for a MACD main-line zero-cross. |
| `strategy_distance_pips` | 10 | 1+ | Minimum closed-bar distance beyond EMA(50). |
| `strategy_structure_bars` | 5 | 1+ | Lookback for the structure stop low or high. |
| `strategy_tp_r_multiple` | 2.0 | >0 | Full baseline take profit at 2R. |
| `strategy_exit_break_pips` | 10 | 1+ | EMA(50) failure distance for discretionary close. |
| `strategy_spread_cap_points` | 20 | 1+ | Spread cap in broker points; zero modeled DWX spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid FX major for M5 trend-continuation testing.
- GBPUSD.DWX - card-listed liquid FX major with intraday movement suitable for M5 signals.
- USDJPY.DWX - card-listed liquid FX major; pip scaling is handled by QM_StopRules.

**Explicitly NOT for:**
- Index, metal, energy, and unavailable symbols - the approved card names only the three DWX FX majors above.

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
| Trades / year / symbol | 120 |
| Typical hold time | Minutes to a few hours. |
| Expected drawdown profile | Moderate whipsaw risk during non-trending M5 regimes. |
| Regime preference | Trend-continuation / momentum. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** e78a9f1f-4e6a-563c-a080-915133d6ed28
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)" (2014), 5 Min Trading System #9, pages 24-25, local PDF archive.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11317_tc-m5-9-ema50-100-macd.md`

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
| v1 | 2026-06-25 | Initial build from card | 2360fa1f-0353-4d46-807a-136db4c5618b |
