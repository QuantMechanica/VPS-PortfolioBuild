---
ea_id: QM5_10047
slug: ff-wick-system-h1
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "michaellobry, Statistics combined with system. Profitable? What do you think, ForexFactory, 2018-05-31, https://www.forexfactory.com/thread/771822-statistics-combined-with-system-profitable-what-do-you"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/candle-wick-direction]]"
  - "[[concepts/statistical-candle-edge]]"
indicators:
  - "[[indicators/candle-wick]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, EURJPY.DWX]
period: H1
expected_trade_frequency: "Source rule fires every H1 candle; after session/spread filters estimate 700-1400 trades/year/symbol."
expected_trades_per_year_per_symbol: 900
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL/handle present; R2 H1 wick entry plus TP/SL/time exit gives ~900 trades/year/symbol; R3 DWX FX OHLC-testable; R4 fixed ML-free 1-position rules"
---

# ForexFactory Wick System H1

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: michaellobry, "Statistics combined with system. Profitable? What do you think", ForexFactory, 2018, URL https://www.forexfactory.com/thread/771822-statistics-combined-with-system-profitable-what-do-you.
- Author / handle: `michaellobry`.
- Source location: first post defines Wick System 1.00, timeframe M1-D1 with H1 example, entry at the close of each prior candle, buy when lower wick exceeds upper wick, sell when lower wick is smaller than upper wick, and 50 pip TP/SL.

## Mechanik

### Entry
- Evaluate at every H1 bar open using the just-closed H1 candle.
- Compute:
  - `upper_wick = High[1] - max(Open[1], Close[1])`.
  - `lower_wick = min(Open[1], Close[1]) - Low[1]`.
- Long:
  - `lower_wick > upper_wick`.
  - Prior bar range >= 0.25 * ATR(14,H1).
  - Enter long at new H1 open.
- Short:
  - `upper_wick > lower_wick`.
  - Prior bar range >= 0.25 * ATR(14,H1).
  - Enter short at new H1 open.
- Skip exact wick ties.

### Exit
- Source TP = 50 pips.
- Exit at TP, SL, or after 12 H1 bars if neither fired.

### Stop Loss
- Source SL = 50 pips.
- Skip if spread > 10% of stop distance.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Trade only Monday-Thursday liquid sessions in baseline to avoid weekend roll and thin Friday close.
- P3 can test raw all-hours source variant.

## Concepts
- [[concepts/candle-wick-direction]] - primary
- [[concepts/statistical-candle-edge]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL plus named handle `michaellobry`. |
| R2 Mechanical | PASS | Wick comparison, entry cadence, TP, and SL are explicit. |
| R3 DWX-testbar | PASS | Uses only OHLC wick geometry and pip exits on DWX FX pairs. |
| R4 No ML | PASS | Fixed rules, one position, no ML/grid/martingale/adaptive parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, EURJPY.DWX.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10018_ff-bb-shadow-reversal-h1]] - wick beyond Bollinger band plus confirmation; this card uses pure relative wick direction every H1 bar.
- [[strategies/QM5_9959_ff-daily-wick-hilo-d1]] - daily wick/level family; this card is H1 continuous wick-comparison.

## Lessons Learned
- TBD during pipeline run.

