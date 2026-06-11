---
ea_id: QM5_9990
slug: ff-dual-candle-bb-rsi
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "sak.mandhai, Dual Candle Strategy, ForexFactory, 2020-06-13, https://www.forexfactory.com/thread/1005994-dual-candle-strategy"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/inside-bar-breakout]]"
  - "[[concepts/bollinger-regime-filter]]"
  - "[[concepts/rsi-filter]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/rsi]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX]
period: H4
expected_trade_frequency: "H4 two-candle inside-bar pattern with BB and RSI filters; conservative estimate 20-45 trades/year/symbol."
expected_trades_per_year_per_symbol: 32
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL/handle present; R2 deterministic inside-bar BB/RSI pending-stop rules with plausible 32 trades/year/symbol; R3 FX majors testable on DWX; R4 fixed-rule no ML/martingale one-position."
---

# ForexFactory Dual Candle BB RSI Breakout

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: sak.mandhai, "Dual Candle Strategy", ForexFactory, 2020, URL https://www.forexfactory.com/thread/1005994-dual-candle-strategy.
- Author / handle: `sak.mandhai`.
- Source location: first post and post #20. The source defines H4, a two-candle pattern where candle 2 is contained inside candle 1, Bollinger Band(20,2,Close), RSI(14), long setups between upper and middle bands with RSI above 50, short setups between lower and middle bands with RSI below 50, pending stop entries, and SL/TP calculated from the first candle high/low.

## Mechanik

### Entry
- Work on H4.
- Compute Bollinger Bands(20, 2.0, Close) and RSI(14).
- Define setup candles:
  - Candle A = Bar[2].
  - Candle B = Bar[1].
  - Candle B is inside Candle A: `High[1] <= High[2] AND Low[1] >= Low[2]`.
- Long setup:
  - Candle A is bullish: `Close[2] > Open[2]`.
  - Candle B is inside Candle A.
  - Both candle closes are between middle and upper Bollinger Bands.
  - `RSI(14)[1] > 50`.
  - Place buy stop at `High[2] + 1 pip` on Bar[0].
- Short setup mirrors:
  - Candle A is bearish.
  - Candle B is inside Candle A.
  - Both candle closes are between lower and middle Bollinger Bands.
  - `RSI(14)[1] < 50`.
  - Place sell stop at `Low[2] - 1 pip`.

### Exit
- Baseline target ladder from source examples:
  - TP1 = 1R.
  - TP2 = 2R.
  - TP3 = 3R.
- In one-position-per-magic implementation, use virtual scaling:
  - Move stop to breakeven at TP1.
  - Trail by 1R after TP2.
  - Close full position at TP3 or opposite setup.

### Stop Loss
- Long stop = `Low[2] - 1 pip`.
- Short stop = `High[2] + 1 pip`.
- Skip setup if stop distance is below broker minimum or above 3.0 * ATR(14,H4).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Pending order expires after 3 H4 bars.
- Skip if Bollinger Band width is below 0.8 * ATR(20,H4) to avoid compressed no-range candles.
- One active position per magic-symbol.

## Concepts
- [[concepts/inside-bar-breakout]] - primary
- [[concepts/bollinger-regime-filter]] - secondary
- [[concepts/rsi-filter]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL plus named handle `sak.mandhai`. |
| R2 Mechanical | PASS | Inside-candle, Bollinger-zone, RSI side, pending stop, first-candle stop, and R targets are deterministic. |
| R3 DWX-testbar | PASS | Uses H4 OHLC, Bollinger Bands, and RSI on DWX FX majors. |
| R4 No ML | PASS | Fixed indicators and thresholds, no grid/martingale/ML, virtual scale management preserves one broker position. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1341_inside-bar-breakout-h4]] - generic inside-bar breakout; this card adds Bollinger half-band location and RSI side filter from the FF source.
- [[strategies/QM5_9976_ff-ema-fibo-rsi-stoch]] - also RSI-filtered, but uses EMA/Fibonacci levels and stochastic confirmation, not inside bars.

## Lessons Learned
- TBD during pipeline run.

