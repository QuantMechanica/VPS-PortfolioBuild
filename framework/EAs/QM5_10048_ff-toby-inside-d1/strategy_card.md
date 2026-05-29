---
ea_id: QM5_10048
slug: ff-toby-inside-d1
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "toby123, Toby's 600 seconds breakout system, ForexFactory, 2012-02-07, https://www.forexfactory.com/thread/341009-tobys-600-seconds-breakout-system"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/inside-bar-breakout]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/sma]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, EURJPY.DWX]
period: D1
expected_trade_frequency: "Daily inside-bar breakout gated by SMA(21) slope; conservative estimate 12-30 trades/year/symbol after inside-bar and trend filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 FF URL+handle; R2 mechanical D1 inside-bar/SMA entry with SL/TP exits and ~20 trades/year/symbol; R3 DWX FX testable; R4 fixed no-ML one-position."
---

# ForexFactory Toby Inside-Bar D1 Breakout

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: toby123, "Toby's 600 seconds breakout system", ForexFactory, 2012, URL https://www.forexfactory.com/thread/341009-tobys-600-seconds-breakout-system.
- Author / handle: `toby123`.
- Source location: first post defines D1 timeframe, SMA(21) direction filter, inside-bar setup, stop-entry 5 pips plus spread beyond the inside bar, pair-specific stops, and TP = 2 x stop.

## Mechanik

### Entry
- Evaluate once per completed D1 bar.
- Compute SMA(21) on D1 closes.
- Define an inside bar when `High[1] < High[2]` and `Low[1] > Low[2]`.
- Long:
  - SMA(21) slope is positive: `SMA21[1] > SMA21[2]`.
  - Prior completed candle is an inside bar.
  - Place a buy-stop at `High[1] + 5 pips + spread`.
- Short:
  - SMA(21) slope is negative: `SMA21[1] < SMA21[2]`.
  - Prior completed candle is an inside bar.
  - Place a sell-stop at `Low[1] - 5 pips - spread`.
- Cancel the pending order if the SMA(21) slope flips before fill.

### Exit
- TP = 2 x source pair stop.
- Exit if opposite pending setup appears after entry and before TP/SL.

### Stop Loss
- Source pair stops:
  - EURUSD, USDCHF, NZDUSD, AUDUSD, USDJPY: 50 pips.
  - GBPUSD, USDCAD: 60 pips.
  - EURJPY: 90 pips.
  - GBPJPY: 100 pips.
- For non-listed DWX symbols, baseline stop = max(50 pips, 1.25 x ATR(14,D1)).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- One pending order per symbol/magic.
- Skip if spread > 12% of configured stop.

## Concepts
- [[concepts/inside-bar-breakout]] - primary
- [[concepts/trend-following]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL plus named handle `toby123`. |
| R2 Mechanical | PASS | Timeframe, SMA trend condition, inside-bar setup, entry buffer, stop table, TP multiplier, and cancellation rule are explicit. |
| R3 DWX-testbar | PASS | Uses D1 OHLC and SMA on DWX FX pairs. |
| R4 No ML | PASS | Fixed rules, one position, no ML/grid/martingale/adaptive parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, EURJPY.DWX.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1011_lien-inside-day-breakout]] - published inside-day breakout lineage; this FF card adds SMA(21) slope gating and source-specific fixed stop table.
- [[strategies/QM5_9709_bandy-nr7-inside-day-breakout]] - volatility-compression inside-day variant; this card is simple inside bar plus SMA slope.

## Lessons Learned
- TBD during pipeline run.

