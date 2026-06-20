# QM5_11719_tc-m5-s4-bb-midband-trend - Strategy Spec

**EA ID:** QM5_11719
**Slug:** `tc-m5-s4-bb-midband-trend`
**Source:** `40a4454c-64ff-5015-8538-9f7b32abc0e9` (see `sources/tc-20-forex-strategies-m5-367145560`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades a Bollinger Band trend-continuation pullback on M5. A long setup requires both Bollinger bands to slope upward over five closed bars, then the last closed candle must touch the middle band from above, close back above the middle band, and close bullish. A short setup mirrors this: both bands slope downward, the last closed candle touches the middle band from below, closes back below it, and closes bearish. The factory exit uses fixed 15-pip SL and fixed 15-pip TP; optional inputs allow the card's dynamic band SL/TP variant.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | >= 2 | Bollinger Band lookback period. |
| `strategy_bb_deviation` | 2.0 | > 0 | Bollinger Band standard-deviation multiplier. |
| `strategy_slope_lookback` | 5 | >= 1 | Closed-bar distance used for the BB slope test. |
| `strategy_require_candle` | true | true/false | Require bullish long candle or bearish short candle. |
| `strategy_use_band_sl` | false | true/false | Use dynamic opposite-band SL instead of fixed factory SL. |
| `strategy_sl_fixed_pips` | 15 | > 0 | Fixed SL distance in pips. |
| `strategy_use_band_tp` | false | true/false | Use dynamic outer-band TP instead of fixed factory TP. |
| `strategy_tp_fixed_pips` | 15 | > 0 | Fixed TP distance in pips. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed standard DWX FX instrument with M5 data.
- `GBPUSD.DWX` - card-listed standard DWX FX instrument with M5 data.
- `GBPJPY.DWX` - card-listed standard DWX FX instrument with M5 data.

**Explicitly NOT for:**
- Non-DWX symbols - the build and registry are for Darwinex `.DWX` backtest symbols only.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not valid for P2 registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `350` |
| Expected trade frequency | not explicitly specified in card frontmatter |
| Typical hold time | not explicitly specified in card frontmatter; intraday M5 SL/TP implies short holds |
| Expected drawdown profile | not explicitly specified in card frontmatter |
| Regime preference | trend-continuation pullback, inferred from card concepts |
| Win rate target (qualitative) | not explicitly specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `40a4454c-64ff-5015-8538-9f7b32abc0e9`
**Source type:** book
**Pointer:** `sources/tc-20-forex-strategies-m5-367145560`, Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", Strategy #4, 2014
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11719_tc-m5-s4-bb-midband-trend.md`

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
| v1 | 2026-06-20 | Initial build from card | e7cca238-848c-40fc-894b-03a07c73237c |
