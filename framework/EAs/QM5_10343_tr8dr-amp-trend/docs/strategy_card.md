---
ea_id: QM5_10343
slug: tr8dr-amp-trend
type: strategy
source_id: 83405355-f9f5-502c-970f-2908dbeff99c
source_citation: "Tr8dr, Labeling Momentum & Trends, 2020-07-11, https://tr8dr.github.io/labeling/"
sources:
  - "[[sources/tr8dr-github-io]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum]]"
  - "[[concepts/amplitude-threshold]]"
indicators:
  - "[[indicators/amplitude-based-labeler]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, NDX.DWX]
period: M30
expected_trade_frequency: "Intraday amplitude threshold with inactivity exit; conservative estimate 45 trades/year/symbol after liquid-session and spread filters."
expected_trades_per_year_per_symbol: 45
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 source URL present; R2 mechanical amplitude threshold entry plus inactivity/opposite-signal exits with ~45 trades/year/symbol; R3 OHLC/spread rules testable on DWX FX/metals/indices; R4 fixed rules, no ML/grid/martingale."
---

# Tr8dr Amplitude Threshold Trend Continuation

## Quelle
- Source: [[sources/tr8dr-github-io]]
- URL: https://tr8dr.github.io/labeling/
- Author / handle: `Tr8dr`, self-described quant / developer in the New York area.
- Date: 2020-07-11.
- Location: "Top-Down Approach" defines momentum/trend sections by minimum amplitude and inactivity; examples use `AmplitudeBasedLabeler(minamp = 20, Tinactive = 10/30)`.

## Mechanik

### Entry
- Evaluate on each completed M30 bar.
- Maintain a rolling swing anchor:
  - Up-move candidate starts from the lowest close since the last neutral state.
  - Down-move candidate starts from the highest close since the last neutral state.
- Long when close has advanced at least `MinAmpBps` from the up-move anchor and no long position is active.
- Short when close has declined at least `MinAmpBps` from the down-move anchor and no short position is active.
- Baseline `MinAmpBps = 20` for FX/indices, `MinAmpBps = 35` for XAUUSD.
- Enter only after the threshold is crossed on a completed bar; do not use future labels.

### Exit
- Track highest close since long entry and lowest close since short entry.
- Exit long when no new high close has occurred for `TinactiveBars`.
- Exit short when no new low close has occurred for `TinactiveBars`.
- Also exit on opposite amplitude signal.
- Baseline `TinactiveBars = 10` M30 bars.

### Stop Loss
- Initial SL = `1.2 * ATR(14, M30)`.
- Trail long stop to `highest_close - 1.2 * ATR(14, M30)`.
- Trail short stop to `lowest_close + 1.2 * ATR(14, M30)`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Trade only during liquid session windows.
- Skip entry when spread is greater than 2.5x rolling median spread.
- One active position per symbol/magic.

## Concepts
- [[concepts/trend-following]] - primary.
- [[concepts/momentum]] - secondary.
- [[concepts/amplitude-threshold]] - source labeling mechanism converted to an online trigger.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full source URL plus author handle `Tr8dr`. |
| R2 Mechanical | PASS | Minimum amplitude and inactivity concepts are explicit; this card converts them into non-lookahead entry/exit rules. |
| R3 DWX-testbar | PASS | Uses only OHLC and spread on DWX FX/metals/indices. |
| R4 No ML | PASS | Fixed amplitude, inactivity, and ATR parameters; no ML, adaptive online parameters, grid, or martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, NDX.DWX. SP500.DWX is optional only if reviewers want a backtest-only index variant.

## Author Claims
- Source says the author wanted a simple algorithm that detects moves with minimum amplitude and maximum noise/inactivity.
- Source says the approach performed well compared with more complicated statistical approaches developed by the author.

## Parameters To Test
- `MinAmpBps`: 10, 20, 35, 50.
- `TinactiveBars`: 6, 10, 20, 30.
- Period: M15, M30, H1.
- ATR stop multiplier: 1.0, 1.2, 1.6.

## Initial Risk Profile
Breakout/trend-continuation profile with whipsaw risk after threshold crossings. The conversion from offline labeler to online entry is intentionally delayed to avoid lookahead.

## Pipeline-Verlauf
- G0: PENDING.

