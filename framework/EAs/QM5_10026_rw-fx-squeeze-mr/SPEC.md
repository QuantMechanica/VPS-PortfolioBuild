# QM5_10026_rw-fx-squeeze-mr - Strategy Spec

**EA ID:** QM5_10026
**Slug:** `rw-fx-squeeze-mr`
**Source:** `dcbac84f-6ecf-5d21-9630-50faa69306ec` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades H1 FX mean reversion after a volatility squeeze. On each closed H1 bar it computes Bollinger Band width and ranks the current width against the last 120 closed bars; a squeeze is active when that rank is at or below the configured squeeze percentile. A long setup is armed when the close is below the lower band during the squeeze and RSI(14) is below 30, then entered when a later close returns inside the lower band; shorts mirror this above the upper band with RSI above 70. Open trades exit at the Bollinger midline, after 24 H1 bars, or if Bollinger width expands above the expansion percentile.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | 2+ | Bollinger Band period used for entries, exits, and width ranking. |
| `strategy_bb_deviation` | 2.0 | >0 | Bollinger Band standard deviation multiplier. |
| `strategy_bb_width_lookback` | 120 | 2+ | Number of closed H1 bars used for Bollinger-width percentile rank. |
| `strategy_squeeze_percentile` | 20.0 | 0-100 | Maximum width percentile for squeeze setup eligibility. |
| `strategy_expand_percentile` | 80.0 | 0-100 | Width percentile that triggers early exit before midline touch. |
| `strategy_rsi_period` | 14 | 1+ | RSI period for oversold and overbought confirmation. |
| `strategy_rsi_long_threshold` | 30.0 | 0-100 | Long setup requires RSI below this value. |
| `strategy_rsi_short_threshold` | 70.0 | 0-100 | Short setup requires RSI above this value. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for spread filter and stop sizing. |
| `strategy_atr_sl_mult` | 1.5 | >0 | ATR multiple used as the minimum stop distance. |
| `strategy_extreme_lookback` | 24 | 1+ | Closed-bar lookback for the prior high or low used in structure stop distance. |
| `strategy_extreme_atr_buffer` | 0.25 | >=0 | ATR buffer added beyond the prior 24-bar extreme. |
| `strategy_time_stop_bars` | 24 | 1+ | Maximum hold time measured in H1 bars. |
| `strategy_max_spread_atr_frac` | 0.15 | >0 | Blocks new trading when spread exceeds this fraction of ATR(14). |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid DWX FX major.
- `GBPUSD.DWX` - card-listed liquid DWX FX major.
- `AUDUSD.DWX` - card-listed liquid DWX FX major.
- `USDJPY.DWX` - card-listed liquid DWX FX major.

**Explicitly NOT for:**
- Equity index, commodity, and non-card FX symbols - the approved card names only the four-symbol FX squeeze basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | H1 intraday mean-reversion hold, capped at 24 bars |
| Expected drawdown profile | Mean-reversion losses cluster when band breaks continue instead of reverting |
| Regime preference | Volatility contraction followed by Bollinger mean reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `dcbac84f-6ecf-5d21-9630-50faa69306ec`
**Source type:** blog index / research-code pointer
**Pointer:** Robot Wealth, "Index of Strategies", FX Squeeze Mean Reversion section, https://robotwealth.com/index-of-strategies/
**R1-R4 verdict (Q00):** all PASS per approved-card frontmatter; see `artifacts/cards_approved/QM5_10026_rw-fx-squeeze-mr.md`

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
| v1 | 2026-06-09 | Initial build from card | e18afbdc-07a6-4d63-b4ff-3e36407e10aa |
