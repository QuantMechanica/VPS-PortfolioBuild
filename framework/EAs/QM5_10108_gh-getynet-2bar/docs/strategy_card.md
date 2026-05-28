---
ea_id: QM5_10108
slug: gh-getynet-2bar
type: strategy
source_id: 3b3ec48a-0755-5187-9331-afb36e174175
source_citation: "getYourNet.ch, 2BarReversal.mq5, GitHub repository peterthomet/MetaTrader-5-and-4-Tools, 2018, https://github.com/peterthomet/MetaTrader-5-and-4-Tools/blob/master/EA%20Snippets/Reversal/2BarReversal.mq5"
sources:
  - "[[sources/github-mql5-stars-20]]"
concepts:
  - "[[concepts/candlestick-reversal]]"
  - "[[concepts/session-open]]"
indicators:
  - "[[indicators/ohlc]]"
target_symbols: [GBPJPY.DWX, GBPUSD.DWX, EURUSD.DWX]
period: M15
expected_trade_frequency: "London-open two-bar reversal pattern, at most one entry/day/symbol and usually selective. Estimate 20-45 trades/year/symbol."
expected_trades_per_year_per_symbol: 30
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source GitHub URL present; R2 deterministic London-open two-bar reversal with ~30 trades/year/symbol; R3 testable on DWX FX symbols; R4 fixed-rule no ML/grid/martingale one-position."
---

# GitHub getYourNet Two-Bar London Reversal

## Quelle
- Source: [[sources/github-mql5-stars-20]]
- Citation: getYourNet.ch, `2BarReversal.mq5`, GitHub, 2018.
- URL: https://github.com/peterthomet/MetaTrader-5-and-4-Tools/blob/master/EA%20Snippets/Reversal/2BarReversal.mq5
- Source attribution: file header `Copyright 2018, getYourNet.ch`; namespace string `London Open EA`.

## Mechanik

### Entry
- Run on completed M15 bars with DWX broker-time normalization for the configured `OpenHour = 9`.
- Source default basket enables GBPJPY; V5 should test one symbol per EA run and one active position per magic.
- Build a recent 7-bar window around the London-open setup.
- Long setup:
  - The lowest low in the copied 7-bar window is at bar index 5.
  - Bar 4 is bearish (`open > close`).
  - Bar 5 high is lower than bar 4 high.
  - Bar 6 high is greater than bar 4 high.
  - If `PinBarOppositeBody = true`, also require bar 5 bullish (`open < close`); default false.
- Short setup:
  - The highest high in the copied 7-bar window is at bar index 5.
  - Bar 4 is bullish (`open < close`).
  - Bar 5 low is higher than bar 4 low.
  - Bar 6 low is lower than bar 4 low.
  - If `PinBarOppositeBody = true`, also require bar 5 bearish (`open > close`); default false.
- Optional filters:
  - Skip if pattern range is below `RangeMinSize` or above `RangeMaxSize` when those inputs are non-zero.
  - Skip if accumulation points are below `MinAccumulationSize` when non-zero.
  - Skip if spread consumes more than `MaxSpreadRiskPercent = 5` percent of the risk distance.

### Exit
- Source attaches a fixed pattern-derived TP and SL at entry.
- Long TP: bar 4 high plus one pattern body/range unit, source formula `current[4].high + (current[4].high - current[5].open)`.
- Short TP: bar 4 low minus one pattern body/range unit, source formula `current[4].low - (current[5].open - current[4].low)`.
- No separate close signal is implemented; position exits via SL/TP.

### Stop Loss
- Long SL: minimum of bar 5 open and bar 5 close.
- Short SL: maximum of bar 5 open and bar 5 close.
- V5 should reject trades where the computed SL distance is below broker stop level or above a configurable max ATR multiple.

### Position Sizing
- P2 baseline uses V5 default fixed risk $1,000.
- Source risk input is `RiskPerTrade = 2`; source fixed lot calculation is not used for P2 baseline.

### Zusaetzliche Filter
- V5 excludes the source's unused hedge-related inputs (`HedgeCycles`, `VolumeMultiply`, `hedgeprice`) and implements the selected first-entry pattern only.
- One active position per symbol/magic; no basket/multi-symbol simultaneous deployment in initial build.
- Normalize `OpenHour` to DWX broker time and expose it as a parameter.

## Concepts
- [[concepts/candlestick-reversal]] - primary
- [[concepts/session-open]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full GitHub file URL and named getYourNet.ch attribution. |
| R2 Mechanical | PASS | Candle-index pattern, range filters, spread/risk filter, SL, and TP are deterministic. |
| R3 DWX-testbar | PASS | Uses OHLC, session time, spread, and market orders available on DWX FX symbols. |
| R4 No ML | PASS | Selected V5 implementation has fixed rules, one position, no ML, no grid, and no active martingale/hedge cycle. |

## R3
Primary P2 basket: GBPJPY.DWX, GBPUSD.DWX, EURUSD.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10055_gh-allegro]] - candle/session momentum setup; this card is a London-open two-bar reversal.
- [[strategies/QM5_10075_gh-santi-pa2]] - two-bar price-action reversal family with different exit logic.

## Lessons Learned
- TBD during pipeline run.

