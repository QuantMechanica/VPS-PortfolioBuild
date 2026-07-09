---
ea_id: QM5_9723
slug: ff-sonicr-scout-h1
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "sonicdeejay / traderathome, Sonic R. System Scout Trade, ForexFactory, 2012-2013, https://www.forexfactory.com/thread/114792-sonic-r-system"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/support-resistance]]"
  - "[[concepts/reversal]]"
  - "[[concepts/round-number-levels]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/round-number-levels]]"
  - "[[indicators/swing-points]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, EURJPY.DWX]
period: H1
expected_trade_frequency: "Medium; H1 support/resistance scout reversals at whole/half levels should produce roughly 25-55 trades/year/symbol after confluence filters."
expected_trades_per_year_per_symbol: 35
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id UUID present; full ForexFactory Sonic R thread URL and named handles (sonicdeejay, traderathome) satisfy lineage; additional page references are within the same thread."
r2_mechanical: PASS
r2_reasoning: "Deterministic S/R zones (whole/half numbers + 80-bar swing extremes), wick-percentage filter, run-size gate, 3.0R TP, ATR-based SL, 12-bar time stop — all codified as fixed inequalities."
r3_data_available: PASS
r3_reasoning: "Target symbols EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, EURJPY.DWX are natively testable on DWX MT5 data."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed parameters and deterministic zone-construction rules; single-entry fixed-risk per magic; no ML, adaptive parameters, or martingale."
pipeline_phase: G0
last_updated: 2026-05-19
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "R1 cites ForexFactory Sonic R thread URLs; R2 deterministic H1 S/R scout reversal rules, stops and exits with plausible ~35 trades/year/symbol; R3 testable on DWX FX pairs; R4 fixed single-position non-ML logic."
---

# ForexFactory Sonic R Scout S/R H1

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: sonicdeejay / traderathome, Sonic R. System Scout Trade, ForexFactory, 2012-2013, URL https://www.forexfactory.com/thread/114792-sonic-r-system
- Thread: "Sonic R. System".
- Author / handles: `sonicdeejay`, `traderathome`.
- URL: https://www.forexfactory.com/thread/114792-sonic-r-system
- Scout discussion: https://www.forexfactory.com/thread/114792-sonic-r-system?page=1340
- Original Scout concept summary: https://www.forexfactory.com/thread/114792-sonic-r-system?page=2344

## Mechanik

### Entry
- Use completed H1 bars.
- Build deterministic S/R zones from whole and half numbers plus recent swing extremes:
  - whole/half-number zone every 50 pips for FX majors or symbol-equivalent point step;
  - swing zone if the same high/low area was rejected at least twice in the last 80 H1 bars within `0.35 * ATR(14,H1)`.
- Long Scout setup:
  - price has completed a significant down run: close is below the 20-bar high by at least `2.0 * ATR(14,H1)`;
  - the current bar trades into a demand/support zone;
  - the bar closes back above the zone midpoint and has a lower wick >= 45% of total range;
  - distance from entry to next opposing whole/half-number or swing resistance is at least 2.5R.
- Enter long at next bar open. Short setup mirrors at supply/resistance with upper wick rejection.

### Exit
- Primary TP: next opposing S/R zone or 3.0R, whichever is closer.
- Exit early if H1 closes beyond the support/resistance zone against the trade.
- Time stop: 12 H1 bars.

### Stop Loss
- Long SL below the support-zone low minus `0.20 * ATR(14,H1)`.
- Short SL above the resistance-zone high plus `0.20 * ATR(14,H1)`.
- Reject trade if initial R is greater than 1.4 ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default `RISK_PERCENT` after approval.

### Zusaetzliche Filter
- One active position per magic-symbol.
- Do not add to losing trades; Scout is single-entry fixed-risk only.
- Skip high-impact news windows.

## Concepts
- [[concepts/support-resistance]] - primary
- [[concepts/reversal]] - secondary
- [[concepts/round-number-levels]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory Sonic R URLs plus named handles. |
| R2 Mechanical | PASS | S/R zones, rejection wick, run-size, RR target, SL and exits are codified as fixed inequalities. |
| R3 DWX-testbar | PASS | Uses OHLC, ATR and deterministic round-number/swing levels on DWX FX pairs. |
| R4 No ML | PASS | Single fixed-risk entry; no Scout averaging, adding to losers, grid, martingale, ML or adaptive parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, EURJPY.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9699_ff-sonicr-wave-h1]] - Sonic R Classic wave breakout; this card is the pre-classic Scout reversal at S/R with high reward/risk.
- [[strategies/QM5_9583_ff-brv-sr-fade]] - S/R fade family; this card specifically uses Sonic R whole/half-number and significant-run Scout rules.

## Lessons Learned
- TBD during pipeline run.
