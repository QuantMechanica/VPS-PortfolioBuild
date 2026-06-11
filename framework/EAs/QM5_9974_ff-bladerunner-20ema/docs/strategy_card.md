---
ea_id: QM5_9974
slug: ff-bladerunner-20ema
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "ruben-trader, Trading Strategy Bladerunner, ForexFactory, 2016, https://www.forexfactory.com/thread/604020-trading-strategy-bladerunner"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/trend-pullback]]"
  - "[[concepts/ema-retest]]"
  - "[[concepts/price-action-confirmation]]"
indicators:
  - "[[indicators/ema]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: M15
expected_trade_frequency: "EMA20 retest after trend-side rejection on M15; estimate 60-120 trades/year/symbol after session/news filters."
expected_trades_per_year_per_symbol: 80
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL/handle present; R2 deterministic EMA20 retest/confirmation entry and 2R/BE/opposite-signal exits with ~80 trades/year/symbol; R3 DWX FX/XAU testable; R4 fixed-rule non-ML one-position."
---

# ForexFactory Bladerunner 20 EMA Retest

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: ruben-trader, "Trading Strategy Bladerunner", ForexFactory, 2016, URL https://www.forexfactory.com/thread/604020-trading-strategy-bladerunner.
- Author / handle: `ruben-trader`.
- Source location: first post. The source defines trend side by 20 EMA, waits for a retest candle that touches and closes on the same side of the EMA, then uses the next candle as confirmation and places stop orders 2 pips beyond the confirmatory candle, with stop 2 pips beyond the signal candle and targets at 1R / 2R.

## Mechanik

### Entry
- Work on M15 baseline; P3 may sweep M5/M30.
- Define EMA20 = EMA(20, close).
- Long setup:
  - Close has been above EMA20 for at least 3 of the last 4 closed bars.
  - Signal candle touches or pierces EMA20 (`Low <= EMA20`) and closes back above EMA20.
  - Confirmatory candle closes above the signal candle high and above EMA20.
  - Place a buy stop at `confirmatory_high + 2 pips`; order expires at the next bar open.
- Short setup mirrors: price below EMA20, signal candle touches EMA20 and closes below it, confirmatory candle closes below signal low, sell stop at `confirmatory_low - 2 pips`.

### Exit
- Baseline one-position implementation:
  - Take profit at 2R.
  - Move stop to breakeven after +1R.
  - Close on opposite valid Bladerunner setup before TP/SL.
- P3 may test virtual partial management: 50% virtual exit at 1R and remainder at 2R while preserving one broker position.

### Stop Loss
- Long: `signal_low - 2 pips`.
- Short: `signal_high + 2 pips`.
- Enforce minimum stop distance `max(raw_stop, 0.5 * ATR(14,M15))` if broker minimums or spread make the source stop unusably tight.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- No new entry from 45 minutes before to 15 minutes after high-impact calendar events.
- Session filter: London + New York liquid windows only for M15.
- Spread <= 8% of stop distance.
- One active position per magic-symbol.

## Concepts
- [[concepts/trend-pullback]] - primary
- [[concepts/ema-retest]] - secondary
- [[concepts/price-action-confirmation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL plus named handle `ruben-trader`. |
| R2 Mechanical | PASS | EMA side, retest candle, confirmatory candle, stop, and 1R/2R targets are deterministic after the confluence language is reduced to EMA-side rules. |
| R3 DWX-testbar | PASS | Uses OHLC and EMA on FX majors and XAUUSD. |
| R4 No ML | PASS | Fixed EMA period and pip/R thresholds, no ML/grid/martingale, one position per magic. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9721_ff-dance-ema-touch-h1]] - also an EMA-touch family card; this card requires signal/confirmatory candle sequencing around EMA20.
- [[strategies/QM5_9969_ff-ema34-204-touch-m5]] - first-touch-after-cross state machine; this card is repeated EMA20 polarity retest.

## Lessons Learned
- TBD during pipeline run.

