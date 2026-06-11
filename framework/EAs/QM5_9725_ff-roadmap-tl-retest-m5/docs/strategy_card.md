---
ea_id: QM5_9725
slug: ff-roadmap-tl-retest-m5
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "LauraT, Roadmap - A Way To Read Markets, ForexFactory, 2020-2024, https://www.forexfactory.com/thread/993524-roadmap-a-way-to-read-markets"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/trendline-break]]"
  - "[[concepts/retest-entry]]"
  - "[[concepts/intraday-momentum]]"
indicators:
  - "[[indicators/ema-channel]]"
  - "[[indicators/rsi]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX]
period: M5
expected_trade_frequency: "Medium-high; M5 deterministic trendline break-and-retest Roadmap entries should produce roughly 60-130 trades/year/symbol after compression and session filters."
expected_trades_per_year_per_symbol: 80
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 linked FF source; R2 deterministic M5 trendline break/retest entry+exit with ~80 trades/year/symbol; R3 DWX FX/metals/NDX testable; R4 fixed non-ML one-position rules."
---

# ForexFactory Roadmap Trendline Retest M5

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: LauraT, "Roadmap - A Way To Read Markets", ForexFactory, 2020-2024, URL https://www.forexfactory.com/thread/993524-roadmap-a-way-to-read-markets.
- Thread: "Roadmap - A Way To Read Markets".
- Author / handle: `LauraT`.
- URL: https://www.forexfactory.com/thread/993524-roadmap-a-way-to-read-markets
- Trendline break reference: https://www.forexfactory.com/thread/993524-roadmap-a-way-to-read-markets?page=204
- Channel break/retest reference: https://www.forexfactory.com/thread/993524-roadmap-a-way-to-read-markets?page=289
- Daily-open/SMA failure reference: https://www.forexfactory.com/thread/post/14737658

## Mechanik

### Entry
- Use completed M5 bars during London and early New York.
- Build Roadmap channel with EMA(8, high), EMA(8, close), EMA(8, low) and SMA(200).
- Build deterministic counter-trendline:
  - for a long, connect the two most recent descending swing highs in the last 48 M5 bars, each swing high using a 2-left/2-right fractal rule;
  - line endpoints must be at least 8 bars apart and slope must be negative;
  - short setup mirrors with ascending swing lows.
- Long entry:
  - close breaks above the bearish counter-trendline;
  - within the next 6 bars price retests the broken line within `0.20 * ATR(14,M5)`;
  - retest bar closes bullish and above EMA(8, close);
  - close is above daily open and above SMA(200), or RSI(14,M5) is above 55 with SMA(200) slope positive.
- Enter long at next bar open. Short setup mirrors below daily open/SMA(200) with RSI below 45.

### Exit
- Primary TP: nearest of ADR high/low, prior session high/low, or 1.8R.
- Exit on close back through the broken trendline.
- Time stop: 24 M5 bars.

### Stop Loss
- Long SL below retest swing low minus `0.25 * ATR(14,M5)`.
- Short SL above retest swing high plus `0.25 * ATR(14,M5)`.
- Reject if initial stop distance is less than 0.6 ATR or greater than 2.0 ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default `RISK_PERCENT` after approval.

### Zusaetzliche Filter
- Do not trade compressed triangle side-door exits: if the two trendlines converge to an apex within the next 8 bars and channel width is below 0.45 ATR, skip.
- Skip if spread exceeds 12% of ATR(14,M5).
- One active position per magic-symbol.

## Concepts
- [[concepts/trendline-break]] - primary
- [[concepts/retest-entry]] - secondary
- [[concepts/intraday-momentum]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory Roadmap URLs plus named handle `LauraT`. |
| R2 Mechanical | PASS | Trendline anchors, break/retest tolerance, Roadmap channel, RSI/SMA gates, SL and exits are deterministic. |
| R3 DWX-testbar | PASS | Uses OHLC, EMA/SMA, RSI, ATR and daily/session levels available on DWX FX/metals/indices. |
| R4 No ML | PASS | Fixed swing rules and thresholds; no adaptive online parameters, ML, grid, martingale, or multi-position logic. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9700_ff-roadmap-channel-m15]] - Roadmap EMA-channel cross; this card is M5 counter-trendline break-and-retest.
- [[strategies/QM5_1443_demark-td-lines-h4]] - trendline breakout family; this card uses Roadmap intraday retest and daily-open/SMA context.

## Lessons Learned
- TBD during pipeline run.
