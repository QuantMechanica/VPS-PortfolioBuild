---
ea_id: QM5_10507
slug: mql5-ao-lightning
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Evgeniy Kravchenko, AO Lightning, MQL5 CodeBase, published 2018-06-16, https://www.mql5.com/en/code/20672"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/ao-momentum]]"
  - "[[concepts/opposite-signal-exit]]"
indicators: [Awesome Oscillator]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "AO histogram two-bar color/slope signals on H1 with opposite-signal group close; V5 one-position gating estimate is 120-260 trades/year/symbol."
expected_trades_per_year_per_symbol: 170
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL/title/author/date; R2 PASS deterministic AO color/slope entries and opposite-signal exit with ~170 trades/year/symbol; R3 PASS portable to DWX FX/metals/indices; R4 PASS fixed non-ML one-position bounded-risk rules."
---

# MQL5 AO Lightning Histogram Reversal

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Evgeniy Kravchenko, "AO Lightning", MQL5 CodeBase, published 2018-06-16, URL https://www.mql5.com/en/code/20672.
- Source location: page states the EA uses an internally calculated Awesome Oscillator, opens orders at each bar, closes by opposite signal, and defines buy/sell signals from AO histogram color and relative heights of two columns.

## Mechanik

### Entry
- Evaluate once per new H1 bar.
- Compute AO histogram from configurable fast/slow SMA periods.
- Long:
  - AO histogram moves down and changes to red.
  - The second AO column is higher than the first AO column, matching the source buy condition.
  - No active position for this symbol/magic.
- Short:
  - AO histogram moves up and changes to green.
  - The second AO column is lower than the first AO column, matching the source sell condition.
  - No active position for this symbol/magic.

### Exit
- Close on opposite AO Lightning signal.
- Source allows multiple orders; V5 baseline enforces one active position.
- P2 baseline adds hard exits: SL = 1.5 * ATR(14), TP = 1.5R.

### Stop Loss
- ATR-normalized fixed hard stop.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic; source `Orders` input fixed to 1.
- Skip high-impact news windows when QM news filter is active.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL with title, named author, and publish date. |
| R2 Mechanical | PASS | AO color/slope conditions and opposite-signal close are explicit enough for deterministic implementation. |
| R3 DWX-testbar | PASS | Awesome Oscillator and fixed exits are portable to DWX FX, metals, and index CFDs. |
| R4 No ML | PASS | No ML, grid, or martingale; multi-order source input is fixed to one position for V5. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10481_mql5-exec-ao]] - Awesome Oscillator family.
- [[strategies/QM5_10498_mql5-aocci]] - AO plus CCI confirmation family.

## Lessons Learned
- TBD during pipeline run.
