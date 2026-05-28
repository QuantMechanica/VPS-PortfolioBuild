---
ea_id: QM5_10043
slug: ff-50macd-4h
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "the_guvnor, 50 +/- MACD 4hour, ForexFactory, 2007-06-10, https://www.forexfactory.com/thread/33362-50-macd-4hour"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/momentum-breakout]]"
  - "[[concepts/fixed-risk-reward]]"
indicators:
  - "[[indicators/macd]]"
target_symbols: [GBPUSD.DWX, EURUSD.DWX, USDJPY.DWX, EURJPY.DWX]
period: H4
expected_trade_frequency: "H4 MACD-delta threshold checked four times per active trading day; conservative filtered estimate 30-60 trades/year/symbol."
expected_trades_per_year_per_symbol: 44
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-20
g0_approval_reasoning: "R1 linked ForexFactory source; R2 mechanical H4 MACD threshold entry/exits with plausible 30-60 trades/year/symbol; R3 DWX FX pairs testable; R4 fixed non-ML one-position rules."
---

# ForexFactory 50+/- MACD 4H

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: the_guvnor, "50 +/- MACD 4hour", ForexFactory, 2007, URL https://www.forexfactory.com/thread/33362-50-macd-4hour.
- Author / handle: `the_guvnor`.
- Source location: first post defines GBP/USD H4, MACD(5,13,1), entry checks at 08:00/12:00/16:00/20:00 GMT/BST, a +/-50 MACD-signal difference trigger, and two fixed target/stop variants.

## Mechanik

### Entry
- Evaluate only at the four source decision times: 08:00, 12:00, 16:00, 20:00 GMT/BST.
- Compute MACD(5,13,1) main value on H4 closes.
- Long:
  - `MACD_main[1] - MACD_main[3] >= 50 points`, where `[1]` is the just-closed H4 bar and `[3]` is two H4 bars earlier.
  - Enter long at market at the decision time.
- Short mirrors with `MACD_main[1] - MACD_main[3] <= -50 points`.

### Exit
- Baseline uses the source's second position management compressed into one V5 position:
  - Initial TP = 45 pips.
  - Move stop to breakeven after +30 pips.
- Exit on opposite MACD threshold if it appears before TP/SL.

### Stop Loss
- Source fixed SL = 30 pips.
- Skip if spread > 15% of stop distance.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- One entry check per scheduled H4 decision time.
- Skip if the prior H4 bar range is below 0.25 * ATR(14,H4), to avoid flat MACD noise.

## Concepts
- [[concepts/momentum-breakout]] - primary
- [[concepts/fixed-risk-reward]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL plus named handle `the_guvnor`. |
| R2 Mechanical | PASS | MACD period, H4 decision times, threshold, SL, TP, and breakeven rule are explicit. |
| R3 DWX-testbar | PASS | Uses H4 OHLC-derived MACD and pip exits on DWX FX pairs. |
| R4 No ML | PASS | Fixed thresholds, one position, no ML/grid/martingale/adaptive parameters. |

## R3
Primary P2 basket: GBPUSD.DWX, EURUSD.DWX, USDJPY.DWX, EURJPY.DWX.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9951_ff-macd-bias-ema48-m15]] - MACD plus EMA bias on M15; this card is pure H4 MACD-delta threshold.
- [[strategies/QM5_14630_4h-macd]] - if present in wiki, compare trigger overlap; this card is the explicit FF 50-point variant.

## Lessons Learned
- TBD during pipeline run.

