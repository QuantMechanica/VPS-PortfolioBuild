---
ea_id: QM5_10015
slug: ff-bb-stoch-h1
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "StingrayEA, Bollinger Band & Stochastic, ForexFactory, 2014-09-28, https://www.forexfactory.com/thread/506226-bollinger-band-stochastic"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/bollinger-reversal]]"
  - "[[concepts/stochastic-confirmation]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/stochastic]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "H1 Bollinger pierce plus stochastic confirmation; estimate 35-75 trades/year/symbol."
expected_trades_per_year_per_symbol: 50
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL/handle present; R2 deterministic H1 Bollinger/Stochastic entry plus SL/TP/trail exits with ~50 trades/year/symbol; R3 DWX FX/XAU testable; R4 fixed non-ML one-position rules."
---

# ForexFactory Bollinger Stochastic H1 Reversal

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: StingrayEA, "Bollinger Band & Stochastic", ForexFactory, 2014, URL https://www.forexfactory.com/thread/506226-bollinger-band-stochastic.
- Author / handle: `StingrayEA`.
- Source location: first post defines Bollinger Bands(20,2,0), Stochastic(14,3,3), H1, any currency, buy/sell after prior candle crosses the Bollinger band with stochastic main/signal agreement, current candle direction, TP 50, trailing stop 15, SL 50.

## Mechanik

### Entry
- Work on H1 closed bars.
- Compute Bollinger Bands(20,2) and Stochastic(14,3,3).
- Long baseline:
  - Bar [2] closed below the lower Bollinger Band or had low below lower band and close back inside.
  - On bar [1], current closed candle is bullish.
  - Stochastic `%K[1] > %D[1]` and `%K[1] < 80`.
  - Enter long at bar [0] open.
- Short baseline:
  - Bar [2] closed above upper Bollinger Band or had high above upper band and close back inside.
  - Bar [1] is bearish.
  - Stochastic `%K[1] < %D[1]` and `%K[1] > 20`.
  - Enter short at bar [0] open.

### Exit
- TP = 50 pips on FX majors; XAUUSD uses 1.0 * ATR(14,H1) as the 50-pip analog.
- Trail stop by 15 pips after trade reaches +20 pips.
- Exit on opposite Bollinger/Stochastic signal.

### Stop Loss
- Source SL = 50 pips on FX majors.
- XAUUSD SL = 1.0 * ATR(14,H1), capped by P3 sweep.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Spread <= 10% of stop distance.

## Concepts
- [[concepts/bollinger-reversal]] - primary
- [[concepts/stochastic-confirmation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL plus named handle `StingrayEA`. |
| R2 Mechanical | PASS | BB pierce/re-entry, stochastic relation, candle direction, SL/TP/trail are closed-form. |
| R3 DWX-testbar | PASS | Uses H1 OHLC, Bollinger Bands, Stochastic, and ATR on DWX FX/metals. |
| R4 No ML | PASS | Fixed periods/thresholds, one position, no ML/grid/martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9929_ff-bb-rsi-stoch-m30]] - BB/RSI/Stoch pullback with H4 trend filter; this card is the simpler source-defined H1 BB+Stoch reversal with fixed pip exits.
- [[strategies/QM5_9202_mql5-bb-stoch-mtf]] - MQL5 BB/Stoch MTF variant; this card is single-timeframe ForexFactory H1.

## Lessons Learned
- TBD during pipeline run.

