---
ea_id: QM5_10000
slug: ff-tasayc-cci-breakout
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "Forexcube, TASAYC System / CCI channel breakout rules, ForexFactory, 2011, https://www.forexfactory.com/thread/325369-tasayc-system"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/momentum-breakout]]"
  - "[[concepts/cci-breakout]]"
indicators:
  - "[[indicators/cci]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "CCI(20) new-extreme breakout on H1; relatively selective. Estimate 35-70 trades/year/symbol."
expected_trades_per_year_per_symbol: 50
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS: ForexFactory source URL and handle; R2 PASS: deterministic H1 CCI prior-extreme breakout with SL/1R/2R exits and ~50 trades/year/symbol; R3 PASS: CCI/OHLC testable on DWX FX/metals; R4 PASS: fixed parameters, one position, no ML/grid/martingale."
---

# ForexFactory TASAYC CCI Breakout

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: Forexcube, "TASAYC System", ForexFactory, 2011, URL https://www.forexfactory.com/thread/325369-tasayc-system.
- Author / handle: `Forexcube`.
- Source location: first-post index and page-1 material quote "Channel Breakouts With The CCI" rules: CCI(20), record the prior +100/-100 peak after it leaves the zone, enter when a later CCI excursion exceeds that prior peak, stop at the signal candle extreme, half exit at 1R, final exit at 2R.

## Mechanik

### Entry
- Compute CCI(20) on H1 completed bars.
- Long setup:
  - Detect the most recent completed CCI excursion above +100, then a return below +100.
  - Store the maximum CCI value from that excursion as `prior_peak`.
  - Enter long at the close of a later bar when CCI is above +100 and exceeds `prior_peak`.
- Short setup:
  - Detect the most recent completed CCI excursion below -100, then a return above -100.
  - Store the minimum CCI value from that excursion as `prior_trough`.
  - Enter short at the close of a later bar when CCI is below -100 and is lower than `prior_trough`.

### Exit
- Virtual partial equivalent for one-position framework:
  - Move SL to breakeven after price reaches +1R.
  - TP at +2R.
- Time stop: 36 H1 bars.
- Emergency exit if CCI crosses back through 0 before +1R is reached.

### Stop Loss
- Long SL: low of the signal candle minus `0.1 * ATR(14,H1)`.
- Short SL: high of the signal candle plus `0.1 * ATR(14,H1)`.
- Skip if signal-candle range exceeds `2.5 * ATR(14,H1)`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per magic-symbol.
- No new entries within 2 H1 bars of high-impact news for the traded currency.

## Concepts
- [[concepts/momentum-breakout]] - primary
- [[concepts/cci-breakout]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL and named handle `Forexcube`; thread quotes explicit CCI rules. |
| R2 Mechanical | PASS | CCI thresholds, stored prior extreme, candle-extreme stop, and 1R/2R exits are deterministic. |
| R3 DWX-testbar | PASS | Uses CCI and OHLC on DWX FX/metals. |
| R4 No ML | PASS | Fixed CCI/ATR parameters, one position, no ML, grid, martingale, or adaptive learning. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9992_ff-rsi-cci-4555]] - oscillator confirmation around midlines; this card trades new CCI extremes beyond a prior +100/-100 excursion.
- [[strategies/QM5_2079_williams-ultimate-oscillator-h4]] - momentum oscillator breakout family; different oscillator and threshold memory.

## Lessons Learned
- TBD during pipeline run.
