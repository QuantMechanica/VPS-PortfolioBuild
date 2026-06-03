---
ea_id: QM5_10557
slug: mql5-trigger
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Exp_Trigger_Line, Nikolay Kositsin, MQL5 CodeBase, published 2017-01-19, https://www.mql5.com/en/code/16615"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/indicator-line-cross]]"
  - "[[concepts/cloud-color-trend]]"
indicators: [Trigger_Line]
target_symbols: [GBPUSD.DWX, EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX]
period: H4
expected_trade_frequency: "Closed-bar Trigger_Line cross plus cloud-color confirmation on H4 should be moderate; conservative estimate is 25-60 trades/year/symbol."
expected_trades_per_year_per_symbol: 40
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL/title/author/date; R2 PASS closed-bar Trigger_Line cross plus cloud color state with exits and 40 trades/year/symbol estimate; R3 PASS portable price-derived indicator on DWX FX/metals; R4 PASS no ML/grid/martingale and one-position baseline."
---

# MQL5 Trigger Line Cloud Cross

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Nikolay Kositsin, "Exp_Trigger_Line", MQL5 CodeBase, published 2017-01-19, URL https://www.mql5.com/en/code/16615.
- Source location: page states the EA is based on Trigger_Line signals; a signal forms on bar close when the main and signal lines cross and the indicator cloud color changes. Source test shown on GBPUSD H4.

## Mechanik

### Entry
- Compute the Trigger_Line custom indicator on the source timeframe.
- Long when Trigger_Line main crosses above signal on a closed bar and cloud color changes to the bullish color state.
- Short when Trigger_Line main crosses below signal on a closed bar and cloud color changes to the bearish color state.
- No existing position for this symbol/magic.

### Exit
- Close long on opposite bearish Trigger_Line cross/color change or hard stop/target.
- Close short on opposite bullish Trigger_Line cross/color change or hard stop/target.
- V5 Friday close, news, and kill-switch exits apply.

### Stop Loss
- Source tests did not use SL/TP.
- P2 baseline: ATR(14) 2.0 hard stop and 1.5R target.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Sweep H1/H4/H6, Trigger_Line indicator period/smoothing inputs after source-code confirmation, ATR stop multiplier, and optional ADX trend-strength floor.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL, title, author, and publish date. |
| R2 Mechanical | PASS | Main/signal cross plus cloud color change on closed bars is deterministic. |
| R3 DWX-testbar | PASS | Custom indicator uses chart price data and is portable to DWX FX, metals, oil, and index CFDs. |
| R4 No ML | PASS | No ML, grid, martingale, or adaptive sizing; one-position V5 baseline enforced. |

## R3
Primary P2 basket: GBPUSD.DWX, EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10556_mql5-3rvi]] - closed-bar line-cross family.

## Lessons Learned
- TBD during pipeline run.
