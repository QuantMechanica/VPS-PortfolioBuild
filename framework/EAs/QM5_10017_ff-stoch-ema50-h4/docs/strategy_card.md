---
ea_id: QM5_10017
slug: ff-stoch-ema50-h4
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "GazFx, Trend Continuation Strategy, ForexFactory, 2018-10-21, https://www.forexfactory.com/thread/837301-trend-continuation-strategy"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/stochastic-pullback]]"
  - "[[concepts/trend-continuation]]"
indicators:
  - "[[indicators/stochastic]]"
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H4
expected_trade_frequency: "H4 stochastic pullback entries gated by EMA50 slope; estimate 20-45 trades/year/symbol."
expected_trades_per_year_per_symbol: 32
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 linked ForexFactory source; R2 mechanical H4 stochastic EMA50 entry/exit with 32 trades/year/symbol estimate; R3 DWX FX/metals testable; R4 fixed non-ML one-position rules."
---

# ForexFactory Stochastic EMA50 H4 Trend Continuation

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: GazFx, "Trend Continuation Strategy", ForexFactory, 2018, URL https://www.forexfactory.com/thread/837301-trend-continuation-strategy.
- Author / handle: `GazFx`.
- Source location: first post defines Stochastic(5,3,3 close/close) crosses at or below 20 for buys and at or above 80 for sells, confirmation by EMA50 close slope, previous low/high stop with 10 pip H4 buffer, TP = 3R, and trailing stop equal to entry stop.

## Mechanik

### Entry
- Work on H4 closed bars.
- Compute Stochastic(5,3,3, Close/Close) and EMA(50, close).
- EMA slope:
  - Up if EMA50[1] > EMA50[4] by at least 0.1 * ATR(14,H4).
  - Down if EMA50[1] < EMA50[4] by at least 0.1 * ATR(14,H4).
- Long:
  - `%K[1]` crosses above `%D[1]`.
  - `%K[1] <= 20` or `%D[1] <= 20` at cross.
  - EMA50 slope is up.
  - Enter long at next H4 open.
- Short mirrors with `%K` crossing below `%D` at/above 80 and EMA50 slope down.

### Exit
- TP = 3.0R, per source.
- Trail stop by 1.0R once price reaches +1.0R.
- Exit on opposite stochastic cross if no TP/SL.
- Time stop: 18 H4 bars.

### Stop Loss
- Long SL = previous 5-bar low - 10 pips.
- Short SL = previous 5-bar high + 10 pips.
- Skip if SL distance exceeds 3.0 * ATR(14,H4) or is below broker minimum.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Ignore entries if EMA50 slope magnitude is below threshold ("flat and trending sideways" in source).
- One active position per symbol/magic.

## Concepts
- [[concepts/stochastic-pullback]] - primary
- [[concepts/trend-continuation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL plus named handle `GazFx`. |
| R2 Mechanical | PASS | Stochastic cross, EMA slope, previous high/low stop, 3R TP, and trailing stop are deterministic. |
| R3 DWX-testbar | PASS | Uses H4 OHLC-derived Stochastic, EMA, and ATR on DWX FX/metals. |
| R4 No ML | PASS | Fixed indicators/thresholds, one position, no ML/grid/martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1228_hopwood-stochastic-cross-h1]] - H1 stochastic with EMA200 price bias; this card uses H4 stochastic extreme cross plus EMA50 slope and 3R management.
- [[strategies/QM5_1271_hopwood-cup-of-coffee-m15]] - stochastic pullback family; this card is slower H4 and source-defined 3R continuation.

## Lessons Learned
- TBD during pipeline run.

