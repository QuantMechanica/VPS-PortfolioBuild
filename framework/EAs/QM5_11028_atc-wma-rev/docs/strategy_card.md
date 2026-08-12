---
ea_id: QM5_11028
slug: atc-wma-rev
type: strategy
source_id: 9441393d-5ffc-5b43-87be-bd532110f204
source_citation: "Alexey Masterov, Interview with Alexey Masterov (ATC 2012), MQL5 Articles, 2013-01-08, https://www.mql5.com/en/articles/624"
sources:
  - "[[sources/mql5-automated-trading-championship]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/moving-average]]"
indicators:
  - "[[indicators/weighted-moving-average]]"
  - "[[indicators/moving-average]]"
target_symbols: [GBPJPY.DWX, GBPUSD.DWX, USDJPY.DWX, EURJPY.DWX]
period: H1
expected_trade_frequency: "Trend-following MA reversal signals on volatile JPY crosses; conservative estimate 25-70 trades/year/symbol."
expected_trades_per_year_per_symbol: 45
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single verifiable MQL5 article URL (mql5.com/en/articles/624) with named author Alexey Masterov — lineage complete."
r2_mechanical: PASS
r2_reasoning: "Fast/slow WMA crossover direction entry with opposite-signal reverse and bounded ATR SL/TP exits are fully mechanical; exact MA periods are acceptable sweep candidates."
r3_data_available: PASS
r3_reasoning: "Targets GBPJPY, GBPUSD, USDJPY, EURJPY — all available as .DWX FX crosses for H1 backtest."
r4_ml_forbidden: PASS
r4_reasoning: "MA periods and weights fixed before backtest, one active position per symbol/magic, no online adaptation."
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS MQL5 article URL; R2 PASS mechanical H1 WMA trend/reversal entries plus opposite-signal and bounded ATR SL/TP exits with plausible 25-70 trades/year/symbol; R3 PASS DWX FX crosses; R4 PASS fixed params no ML one-position-per-magic."
---

# Weighted Moving Average Reversal Trend

## Quelle
- Source: [[sources/mql5-automated-trading-championship]]
- URL: https://www.mql5.com/en/articles/624
- Author / institution: Alexey Masterov, MQL5 Articles / Automated Trading Championship 2012
- Date: 2013-01-08
- Location: interview discussion of the GBPJPY trend-following Championship robot

## Mechanik

### Entry
- Evaluate on completed H1 bars.
- Compute slow WMA(`slow_wma_period`) on the traded symbol.
- Compute fast WMA(`fast_wma_period`) on the traded symbol.
- Optional related-symbol confirmation:
  - for GBPJPY, confirm GBPUSD and USDJPY fast-vs-slow WMA direction with configured weights.
- Long:
  - traded-symbol fast WMA crosses above slow WMA, or close is above slow WMA and fast WMA slope is positive.
  - weighted related-symbol confirmation score >= `confirm_threshold`.
  - no active position for this symbol/magic.
- Short:
  - traded-symbol fast WMA crosses below slow WMA, or close is below slow WMA and fast WMA slope is negative.
  - weighted related-symbol confirmation score <= -`confirm_threshold`.
  - no active position for this symbol/magic.

### Exit
- Reverse on opposite entry signal: close current position, then open the opposite direction if all entry filters remain true.
- Fixed protective SL.
- Large TP as a trend-capture cap; source indicated a trend-following design rather than scalping.

### Stop Loss
- P2 baseline: SL = 2.5 * ATR(14) on H1.
- TP = 5.0 * ATR(14), or disabled in trend-only variant.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic; no Championship maximum-lot sizing.

### Zusaetzliche Filter
- Spread <= symbol median spread * 2.
- Optional session filter: trade only Monday-Friday outside the final hour before weekly close.
- No online parameter adaptation; all weights and MA periods are fixed before backtest.

## Concepts
- [[concepts/trend-following]] - follow persistent moves in volatile crosses.
- [[concepts/moving-average]] - directional state from fast/slow WMA relationship.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 article URL with named participant Alexey Masterov. |
| R2 Mechanical | UNKNOWN | Trend-following GBPJPY concept is explicit; exact MA periods/weights are not disclosed and must be defaulted/swept. |
| R3 DWX-testbar | PASS | Uses standard OHLC moving averages on FX crosses available or portable to DWX. |
| R4 No ML | PASS | Fixed MA periods/weights, bounded SL, one active position per magic. |

## R3
Primary P2 basket: GBPJPY.DWX, GBPUSD.DWX, USDJPY.DWX, EURJPY.DWX.

## Author Claims
- The interview states the robot was trend-following.
- It says GBPJPY was chosen because GBP and JPY were expected to produce reliable trends.
- It says the strategy was simple enough to succeed in the Championship context.

## Parameters To Test
- Timeframe: M30, H1, H4.
- Fast WMA period: 12, 24, 36.
- Slow WMA period: 72, 144, 216.
- Related-symbol weights: disabled, equal weights, GBPUSD 0.5 / USDJPY 0.5.
- Confirmation threshold: 0.0, 0.5, 1.0.
- SL ATR: 1.5, 2.5, 3.5.
- TP ATR: disabled, 4.0, 5.0, 7.0.

## Initial Risk Profile
JPY-cross trend systems can be profitable in directional volatility but vulnerable to large reversals and spread widening. Risk is bounded by ATR stop and fixed risk; the draft excludes aggressive Championship lot sizing.

## Pipeline-Verlauf
- G0: PENDING.
