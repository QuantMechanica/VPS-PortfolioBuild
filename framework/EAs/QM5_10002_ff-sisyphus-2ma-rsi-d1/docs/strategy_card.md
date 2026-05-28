---
ea_id: QM5_10002
slug: ff-sisyphus-2ma-rsi-d1
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "Sis.yphus, A Proven Simple Strategy (2MAs, 1 RSI), ForexFactory, 2016, https://www.forexfactory.com/thread/574065-a-proven-simple-strategy-2mas-1-rsi"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/trend-pullback]]"
  - "[[concepts/rsi2-mean-reversion]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/rsi]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX]
period: D1
expected_trade_frequency: "Daily RSI(2) pullback in 200MA trend; source examples across USD majors. Estimate 12-35 trades/year/symbol."
expected_trades_per_year_per_symbol: 24
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS: ForexFactory URL/handle cited; R2 PASS: fixed EMA200/EMA5/RSI2 entries and EMA5/time-stop exits with 12-35 trades/year/symbol; R3 PASS: USD majors on DWX; R4 PASS: fixed rules, one position, no ML/grid/martingale."
---

# ForexFactory Sis.yphus 2MA RSI D1 Pullback

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: Sis.yphus, "A Proven Simple Strategy (2MAs, 1 RSI)", ForexFactory, 2016, URL https://www.forexfactory.com/thread/574065-a-proven-simple-strategy-2mas-1-rsi.
- Author / handle: `Sis.yphus`.
- Source location: first post defines Daily charts, 200 MA trend filter, 5 MA pullback filter, RSI(2) below 5 / above 95 entries, no hard SL/TP in the source, and exits at the close of the candle that touches the 5 MA or immediately on touch.

## Mechanik

### Entry
- On D1 completed bars, compute EMA(200), EMA(5), and RSI(2).
- Long at the next D1 open when:
  - Close[1] is above EMA(200)[1].
  - Close[1] is below EMA(5)[1].
  - RSI(2)[1] is below 5.
- Short at the next D1 open when:
  - Close[1] is below EMA(200)[1].
  - Close[1] is above EMA(5)[1].
  - RSI(2)[1] is above 95.

### Exit
- Baseline source exit option: close a long at the close of the first D1 candle that touches or closes above EMA(5).
- Close a short at the close of the first D1 candle that touches or closes below EMA(5).
- Time stop: 15 D1 bars.

### Stop Loss
- Source states no hard SL/TP. V5 baseline adds protective SL at `2.5 * ATR(14,D1)` from entry and skips entries if the stop exceeds the symbol's 90th percentile ATR distance.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per magic-symbol.
- No new entries on Friday daily close if broker rollover would hold through weekend gap.

## Concepts
- [[concepts/trend-pullback]] - primary
- [[concepts/rsi2-mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL and named handle `Sis.yphus`. |
| R2 Mechanical | PASS | Entry and exit rules are explicit; protective stop is a V5 risk wrapper because the source intentionally uses signal exits. |
| R3 DWX-testbar | PASS | Source examples are USD majors available on DWX. |
| R4 No ML | PASS | Fixed MA/RSI parameters, one position, no ML, grid, martingale, or online adaptation. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9992_ff-rsi-cci-4555]] - intraday oscillator threshold; this card is Daily RSI(2) pullback inside a 200MA trend.
- [[strategies/QM5_1316_tom-fps-stochastic-h1]] - trend-filtered oscillator pullback; different oscillator, timeframe, and exit.

## Lessons Learned
- TBD during pipeline run.

