---
ea_id: QM5_10941
slug: grimes-keltner-pb
type: strategy
source_id: fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
source_citation: "Adam H. Grimes, Keltner Statistics, undated library page, https://adamhgrimes.com/library/indicators/keltner-statistics/"
sources:
  - "[[sources/adam-grimes-blog]]"
concepts:
  - "[[concepts/keltner-pullback]]"
  - "[[concepts/trend-continuation]]"
indicators:
  - "[[indicators/keltner-channel]]"
  - "[[indicators/atr]]"
  - "[[indicators/ema]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, XTIUSD.DWX]
period: D1
expected_trade_frequency: "Keltner-band trend thrust followed by moving-average pullback; conservative estimate 12-28 trades/year/symbol."
expected_trades_per_year_per_symbol: 18
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 cited Grimes Keltner URL; R2 deterministic D1 Keltner thrust/pullback entry with exits/stops and plausible 12-28 trades/year/symbol; R3 DWX forex/metals/oil testable; R4 fixed no-ML one-position rules."
---

# Grimes Keltner Pullback Continuation

## Quelle
- Source: [[sources/adam-grimes-blog]]
- Citation: Adam H. Grimes, "Keltner Statistics", undated library page, accessed 2026, URL https://adamhgrimes.com/library/indicators/keltner-statistics/
- Source location: Grimes describes Keltner channels using EMA(20) and 2.25 ATR bands, then outlines a pullback test: after a move beyond the upper or lower band, enter in the trend direction when price touches the previous day's moving average.

## Mechanik

### Entry
- Evaluate on D1 close.
- Keltner channel:
  - Mid = EMA(20, close).
  - Upper = Mid + 2.25 * ATR(20).
  - Lower = Mid - 2.25 * ATR(20).
- Long setup:
  - Within the last 10 D1 bars, close was above the upper Keltner band.
  - EMA(20) slope over the last 5 bars is positive.
  - No close below EMA(20) since the upper-band thrust.
  - Enter long at next open after the first D1 bar whose low touches or crosses the prior completed bar's EMA(20).
- Short setup mirrors the rule after a close below the lower Keltner band.

### Exit
- Target = retest of the entry-side Keltner band or 2.0R, whichever is closer.
- Exit if D1 closes on the opposite side of EMA(20) against the trade.
- Time exit after 12 D1 bars.

### Stop Loss
- Long stop = min(pullback low, entry - 2.0 * ATR(20)).
- Short stop = max(pullback high, entry + 2.0 * ATR(20)).
- Reject setup if stop distance exceeds 3.0 * ATR(20).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default percent risk if approved.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Require ATR(20) >= 0.7 * ATR(100) to avoid dead markets.
- Do not enter if the pullback touch occurs more than 10 D1 bars after the initial band close.

## Concepts
- [[concepts/keltner-pullback]] - primary
- [[concepts/trend-continuation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author/institutional blog library page and full URL are cited. |
| R2 Mechanical | PASS | Source provides Keltner parameters and a structured pullback entry; card fixes stops, exits, and stale-signal handling. |
| R3 DWX-testbar | PASS | D1 OHLC, EMA, ATR, and Keltner mechanics are testable on DWX forex, metals, and oil CFDs. |
| R4 No ML | PASS | Fixed deterministic rules with one active position; no ML/adaptive/grid/martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, XTIUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10917_grimes-freebar]] - both use Keltner context; this card trades the documented moving-average pullback after a band thrust.
- [[strategies/QM5_10931_grimes-band-snap]] - opposite family; that card fades overextension, this one buys the trend pullback.

## Lessons Learned
- TBD during pipeline run.
