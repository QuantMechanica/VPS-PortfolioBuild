# QM5_11550_carter-t-m5-ema50-100-macd-partial — Strategy Spec

**EA ID:** QM5_11550
**Slug:** carter-t-m5-ema50-100-macd-partial
**Source:** 42530cb3-0265-534a-89cc-150f80733ff5 (see `sources/carter-thomas-20-forex-strategies-5min`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades Carter System #9 on M5. It enters long when the last closed bar is above EMA(50) and EMA(100), is at least 10 pips above EMA(50), and MACD(12,26,9) crossed from negative to positive within the last five closed bars. It enters short with the opposite EMA and MACD conditions. The initial stop is the 5-bar structure low or high capped at 30 pips; at 2R the EA closes 50% and moves the remainder to break-even, then closes the remainder when price breaks EMA(50) by 10 pips against the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 50 | 2-300 | Fast EMA used for trend state and trailing exit reference. |
| `strategy_ema_slow_period` | 100 | 2-400 | Slow EMA used with EMA(50) for trend confirmation. |
| `strategy_macd_fast` | 12 | 2-50 | MACD fast period. |
| `strategy_macd_slow` | 26 | 3-100 | MACD slow period. |
| `strategy_macd_signal` | 9 | 2-50 | MACD signal period. |
| `strategy_macd_lookback` | 5 | 1-20 | Closed-bar window in which the MACD zero-cross may occur. |
| `strategy_breakout_pips` | 10 | 1-50 | Minimum close-to-EMA(50) distance in the trend direction. |
| `strategy_sl_struct_bars` | 5 | 1-50 | Closed bars used for structure stop low/high. |
| `strategy_sl_cap_pips` | 30 | 1-200 | Maximum initial stop distance. |
| `strategy_partial_rr` | 2.0 | 0.5-10.0 | Profit multiple that triggers the partial close. |
| `strategy_partial_fraction` | 0.5 | 0.1-0.9 | Fraction of current volume closed at the partial. |
| `strategy_exit_break_pips` | 10 | 1-50 | EMA(50) adverse-break distance for strategy exit. |
| `strategy_no_friday_entry` | true | true/false | Blocks new Friday entries in broker time. |
| `strategy_spread_cap_pips` | 5 | 0-50 | Maximum positive spread allowed for entry; zero modeled spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — the approved card names EURUSD.DWX M5, and the symbol is present in `framework/registry/dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- Other `.DWX` symbols — the card's R3 row only establishes EURUSD.DWX availability and does not authorize a wider portable basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 framework `OnTick` gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Expected trade frequency | Card frontmatter does not specify; M5 intraday cadence inferred from the strategy period and trade-count estimate. |
| Typical hold time | Card frontmatter does not specify; expected to be intraday to short multi-hour because exits are EMA(50) breaks on M5. |
| Expected drawdown profile | Card frontmatter does not specify; fixed 30-pip stop cap and 2R partial are expected to bound single-trade risk. |
| Regime preference | Card frontmatter does not specify; rule mechanically prefers EMA-aligned momentum continuation. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 42530cb3-0265-534a-89cc-150f80733ff5
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", System #9; all R1-R4 PASS per `artifacts/cards_approved/QM5_11550_carter-t-m5-ema50-100-macd-partial.md`
**R1-R4 verdict (Q00):** all PASS per approved frontmatter.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | e1c370ae-3ce0-4b4c-81ea-32608963a2f8 |
