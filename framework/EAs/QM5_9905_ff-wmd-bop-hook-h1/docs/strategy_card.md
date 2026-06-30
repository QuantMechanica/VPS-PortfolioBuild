---
ea_id: QM5_9905
slug: ff-wmd-bop-hook-h1
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "wmd, Trading with Deadly Accuracy, ForexFactory, 2009-2017, https://www.forexfactory.com/thread/206723-trading-with-deadly-accuracy"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/support-resistance]]"
  - "[[concepts/breakout-retest]]"
  - "[[concepts/price-action-hook]]"
indicators:
  - "[[indicators/swing-points]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "Medium; H1 BOP/hook retest geometry should produce roughly 25-60 trades/year/symbol after level-quality filters."
expected_trades_per_year_per_symbol: 40
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; ForexFactory thread URL and handle 'wmd' provide full lineage."
r2_mechanical: PASS
r2_reasoning: "Level construction, break, retest hook-close, stop, and exit rules are all explicit and deterministic via OHLC/ATR/fractal swings."
r3_data_available: PASS
r3_reasoning: "All four target symbols (EURUSD/GBPUSD/USDJPY/XAUUSD) are live DWX instruments testable on OHLC+ATR alone."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed level rules and thresholds, no ML, no adaptive parameters, one position per magic."
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 linked ForexFactory source; R2 deterministic H1 S/R breakout-retest hook with exits and ~40 trades/year/symbol; R3 DWX FX/XAU testable; R4 fixed-rule no ML/grid/martingale."
---

# ForexFactory WMD BOP Hook H1

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: wmd, "Trading with Deadly Accuracy", ForexFactory, 2009-2017, URL https://www.forexfactory.com/thread/206723-trading-with-deadly-accuracy.
- Thread: "Trading with Deadly Accuracy".
- Author / handle: `wmd`.
- URL: https://www.forexfactory.com/thread/206723-trading-with-deadly-accuracy
- First-post pattern overview: https://www.forexfactory.com/thread/206723-trading-with-deadly-accuracy
- Hook reference: https://www.forexfactory.com/thread/post/3268478
- BOP/TL reference: https://www.forexfactory.com/showthread.php?p=4276072

## Mechanik

### Entry
- Use completed H1 bars.
- Build deterministic horizontal S/R levels:
  - a level exists where at least two swing highs or lows occurred within the last 160 H1 bars;
  - swing points use a 3-left/3-right fractal rule;
  - touches must be within `0.35 * ATR(14,H1)`;
  - discard levels less than 1.2 ATR from current price at setup start.
- Long BOP/hook setup:
  - price closes above a resistance level by at least `0.25 * ATR`.
  - within the next 10 bars price returns to the broken level from above.
  - retest low is within `0.25 * ATR` of the level and closes back above the level.
  - retest bar range is at least 0.6 ATR and closes in the upper 35% of the range.
  - distance to next higher S/R level is at least 2.0R.
- Enter long at next H1 open. Short setup mirrors after support break and retest from below.

### Exit
- Primary TP: next opposing S/R level or 2.5R, whichever is closer.
- Exit if H1 closes back through the broken level against the trade.
- Time stop: 18 H1 bars.

### Stop Loss
- Long SL below the retest swing low minus `0.25 * ATR(14,H1)`.
- Short SL above the retest swing high plus `0.25 * ATR(14,H1)`.
- Reject if stop distance is below 0.5 ATR or above 2.4 ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default `RISK_PERCENT` after approval.

### Zusaetzliche Filter
- Prefer London and early New York entries; skip late-Friday entries.
- Skip if spread exceeds 15% of ATR(14,H1).
- One active position per magic-symbol.

## Concepts
- [[concepts/support-resistance]] - primary
- [[concepts/breakout-retest]] - secondary
- [[concepts/price-action-hook]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory thread URL plus named handle `wmd`; linked hook and BOP/TL references provide attribution. |
| R2 Mechanical | UNKNOWN | The source is visual price action; this card makes level construction, break, retest, hook close, stop and exits deterministic. G0 should decide whether the codification preserves enough of the source thesis. |
| R3 DWX-testbar | PASS | Uses OHLC/fractal swing points and ATR only, directly testable on DWX FX/metals. |
| R4 No ML | PASS | Fixed level rules and thresholds; no ML, adaptive parameters, grid, martingale, or multi-position logic. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9583_ff-brv-sr-fade]] - S/R fade; this card is breakout-retest continuation.
- [[strategies/QM5_9725_ff-roadmap-tl-retest-m5]] - trendline retest; this card uses horizontal S/R BOP/hook geometry on H1.

## Lessons Learned
- TBD during pipeline run.
