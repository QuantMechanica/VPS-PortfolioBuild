---
ea_id: QM5_10491
slug: mql5-bullbear
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Collector idea, Vladimir Karputov (barabashkakvn) code, MySystem, MQL5 CodeBase, published 2018-10-25, https://www.mql5.com/en/code/22016"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/bulls-bears-power]]"
  - "[[concepts/momentum-slope]]"
indicators: [Bulls Power, Bears Power]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: M15
expected_trade_frequency: "Bulls/Bears Power two-bar slope system on M15; conservative estimate 80-160 trades/year/symbol after one-position gating."
expected_trades_per_year_per_symbol: 100
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 MQL5 CodeBase citation/link; R2 new-bar Bulls/Bears average slope rules with opposite/time/ATR exits and ~100 trades/year/symbol; R3 portable to DWX FX/metals; R4 fixed indicators, no ML/grid/martingale, one-position baseline."
---

# MQL5 MySystem Bulls Bears Power Slope

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Collector idea, Vladimir Karputov (barabashkakvn) code, "MySystem", MQL5 CodeBase, published 2018-10-25, URL https://www.mql5.com/en/code/22016.
- Source location: page states the EA works on new bars, uses iBullsPower and iBearsPower, opens only when no EA position exists, and defines buy/sell using the average of the two indicators across current and previous bars. Source example is EURUSD M15.

## Mechanik

### Entry
- Evaluate only when a new bar appears.
- Compute Bulls Power and Bears Power.
- Set `prev = (bears[1] + bulls[1]) / 2`.
- Set `curr = (bears[0] + bulls[0]) / 2`.
- Long:
  - `prev < curr`.
  - `curr < 0`.
  - No active position for this symbol/magic.
- Short:
  - `prev > curr`.
  - `curr > 0`.
  - No active position for this symbol/magic.

### Exit
- Close on opposite Bulls/Bears average signal.
- Protective SL baseline = 1.5 * ATR(14,M15).
- TP baseline = 2.0R.
- Time stop after 64 M15 bars.

### Stop Loss
- ATR stop, normalized by symbol tick size and broker stop level.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic, matching the source no-position check.
- Skip high-impact news windows when QM news filter is active.
- Spread filter required because source timeframe is M15.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL with title, idea author, code author, and publish date. |
| R2 Mechanical | PASS | Source gives exact formulas and inequality checks for buy and sell. |
| R3 DWX-testbar | PASS | Bulls Power and Bears Power are standard indicators available from OHLC data. |
| R4 No ML | PASS | Fixed indicator formula, no ML, no grid/martingale, and one-position-per-magic baseline. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10481_mql5-exec-ao]] - oscillator bend family; this card uses Bulls/Bears Power average slope.

## Lessons Learned
- TBD during pipeline run.
