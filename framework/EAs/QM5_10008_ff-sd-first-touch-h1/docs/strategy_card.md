---
ea_id: QM5_10008
slug: ff-sd-first-touch-h1
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "thomaas, Price Action made simple with Supply and Demand levels, ForexFactory, 2013-10-16, https://www.forexfactory.com/thread/452780-price-action-made-simple-with-supply-and-demand"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/supply-demand-retest]]"
  - "[[concepts/price-action-mean-reversion]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/swing-zone]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "Fresh H1 supply/demand first-touch zones should be selective; estimate 25-60 trades/year/symbol after impulse/base filters."
expected_trades_per_year_per_symbol: 40
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present with full ForexFactory URL and named handle thomaas."
r2_mechanical: PASS
r2_reasoning: "Card specifies deterministic base-zone (2-6 candles, ATR height), impulse-departure thresholds, freshness check, first-touch entry, ATR-scaled SL, and 2R/3R TP — sufficient for Codex to implement mechanically."
r3_data_available: PASS
r3_reasoning: "EURUSD/GBPUSD/USDJPY/XAUUSD.DWX are standard DWX H1 OHLC instruments."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed ATR-zone rules, single pending order per magic, no ML/adaptive/grid/martingale."
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS FF URL+handle; R2 PASS card gives deterministic H1 zone/impulse/freshness first-touch rules with ~40 trades/year/symbol; R3 PASS FX/XAU DWX OHLC testable; R4 PASS no ML/grid/martingale, one position."
---

# ForexFactory Supply Demand First-Touch H1

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: thomaas, "Price Action made simple with Supply and Demand levels", ForexFactory, 2013, URL https://www.forexfactory.com/thread/452780-price-action-made-simple-with-supply-and-demand.
- Author / handle: `thomaas`.
- Source location: first post. The source describes Drop-Base-Drop, Drop-Base-Rally, Rally-Base-Rally, and Rally-Base-Drop supply/demand levels, prefers fresh strong levels, enters when price returns to the level, places SL beyond the level, and targets 1:2 or 1:3 R:R with pending orders.

## Mechanik

### Entry
- Work on H1.
- Define a base zone mechanically:
  - 2-6 consecutive H1 candles where total zone height is <= 1.0 * ATR(14,H1).
  - Zone high = max high of base candles; zone low = min low of base candles.
- Define impulse departure:
  - For demand: within the next 3 H1 candles after the base, price rallies at least 1.5 * ATR(14,H1) from zone high and at least 2 of those candles close bullish.
  - For supply: within the next 3 H1 candles after the base, price drops at least 1.5 * ATR(14,H1) from zone low and at least 2 of those candles close bearish.
- Freshness:
  - Zone has not been touched after the impulse before the entry setup.
- Long demand entry:
  - Place buy limit at zone high on the first return to a fresh demand zone.
- Short supply entry:
  - Place sell limit at zone low on the first return to a fresh supply zone.

### Exit
- Baseline TP = 2.0R.
- P3 variant: TP = 3.0R, matching the source's 1:2 / 1:3 management range.
- Time stop: cancel unfilled pending orders after 20 H1 bars; close live trade after 30 H1 bars if neither TP nor SL has fired.

### Stop Loss
- Long SL = zone low - 0.15 * ATR(14,H1).
- Short SL = zone high + 0.15 * ATR(14,H1).
- Skip if zone height > 2.0 * ATR(14,H1) or SL distance < broker minimum plus spread.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- First touch only; once a zone is touched, retire it.
- Prefer RBD/DBR reversal zones in baseline; RBR/DBD continuation zones are P3 ablation.
- One active position per symbol/magic.

## Concepts
- [[concepts/supply-demand-retest]] - primary
- [[concepts/price-action-mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL plus named handle `thomaas`. |
| R2 Mechanical | UNKNOWN | Source is price-action discretionary, but this card formalizes base size, impulse departure, freshness, first-touch entry, stop, and 2R/3R target. Reviewer should adjudicate whether this reduction is acceptable. |
| R3 DWX-testbar | PASS | Uses H1 OHLC and ATR-derived zones on DWX FX/metals. |
| R4 No ML | PASS | Fixed zone rules and one pending order; no ML, adaptive learning, grid, martingale, or scale-in. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9301_mql5-sd-retest]] - MQL5 supply/demand retest; this card is the ForexFactory first-touch formulation with explicit base/impulse/freshness constraints.
- [[strategies/QM5_9955_ff-rectangle-sweep-m1]] - short-lived M15 rectangle sweep; this card uses H1 base-and-impulse supply/demand zones.

## Lessons Learned
- TBD during pipeline run.

