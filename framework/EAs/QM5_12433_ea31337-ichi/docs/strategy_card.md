---
ea_id: QM5_12433
slug: ea31337-ichi
type: strategy
source_id: 041e0d5c-bf76-501d-bee2-31c0f4a6e233
sources:
  - "[[sources/github-mql5-topic]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/cloud-breakout]]"
indicators:
  - "[[indicators/ichimoku]]"
g0_status: APPROVED
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
r2_reasoning: "Tenkan/Kijun cross with prior-state check, Chikou relation, Senkou cloud direction, and slope threshold are explicit entries; fixed SL/TP/time/opposite-cross exits complete the mechanical spec."
r3_reasoning: "Ichimoku is computed from standard OHLC; target symbols EURJPY.DWX, GBPJPY.DWX, GDAXI.DWX, NDX.DWX, XAUUSD.DWX all have DWX tester history."
r4_reasoning: "Deterministic Ichimoku cross/cloud rule, one position per symbol/magic, no ML, no adaptive PnL-based sizing, no martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 12
target_symbols: [EURJPY.DWX, GBPJPY.DWX, GDAXI.DWX, NDX.DWX, XAUUSD.DWX]
last_updated: 2026-07-26
card_body_incomplete: true
card_body_missing: "legacy_contract_repair"
g0_rejection_reason: "SUPERSEDED: source-only rejection recovered under OWNER R1 policy on 2026-07-23; original retained in cards_rejected."
status: draft
r1_reasoning: "Existing attribution retained; R1 is informational and non-gating under OWNER policy 2026-07-23."
legacy_contract_repair: true
g0_recovery_reason: "Source-only rejection recovered; fresh semantic R2-R4 G0 review required."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_12433_ea31337-ichi.md"
source_citation: ""
g0_approval_reasoning: "R1 lineage recorded; R2 explicit Ichimoku cross/cloud confluence and SL/TP/time/opposite-cross exits with conservative joint cadence; R3 uses DWX OHLC only; R4 deterministic one-position logic with no ML."
expected_pf: 1.2
expected_dd_pct: 18.0
---

# EA31337 Ichimoku Tenkan Kijun Cloud Breakout

## Quelle
- Source: [[sources/github-mql5-topic]]
- Primary URL: https://github.com/topics/mql5
- Exact repository: https://github.com/EA31337/Strategy-Ichimoku
- Exact source file: https://github.com/EA31337/Strategy-Ichimoku/blob/master/Stg_Ichimoku.mqh
- Parent strategy collection: https://github.com/EA31337/EA31337-strategies
- Author / institution: EA31337 Ltd / `EA31337`, GitHub repository `Strategy-Ichimoku`
- Location: `README.md` project description; `Stg_Ichimoku.mqh` user inputs and `SignalOpen()`.

## Mechanik

### Entry
Use Ichimoku Tenkan 30, Kijun 10, Senkou Span B 30, indicator shift 1. Source default `SignalOpenLevel=0.001`, max spread 4 pips, close loss/profit 80, close time `-30` bars.

Long:
- Ichimoku data is valid at the shifted bar.
- Tenkan-sen is above Kijun-sen on the signal bar.
- Tenkan-sen was below Kijun-sen two bars earlier.
- Chikou Span is below Tenkan-sen on the signal bar per source condition.
- Senkou Span A is above Senkou Span B.
- Tenkan-sen increases by at least the open level over three bars.
- Open one long.

Short:
- Ichimoku data is valid at the shifted bar.
- Tenkan-sen is below Kijun-sen on the signal bar.
- Tenkan-sen was above Kijun-sen two bars earlier.
- Chikou Span is above Tenkan-sen on the signal bar per source condition.
- Senkou Span A is below Senkou Span B.
- Tenkan-sen decreases by at least the open level over three bars.
- Open one short.

### Exit
- Source default close controls: close loss 80, close profit 80, and close time `-30` bars.
- V5 baseline: fixed SL/TP plus time exit after 30 bars; close earlier on opposite Tenkan/Kijun cross.

### Stop Loss
- Source default price stop method 1 with level 2.
- V5 baseline: cloud boundary or ATR/recent-swing stop if source stop method is not ported directly.

### Position Sizing
- Backtest: V5 default fixed risk $1,000 per trade.
- Live candidate: V5 default percent risk after pipeline approval.

### Zusaetzliche Filter
- One position per symbol/magic.
- Max spread source default: 4 pips.
- Prefer H1/H4 for initial testing because cloud logic is slower than the oscillator modules.
- Suggested first test universe: EURJPY.DWX, GBPJPY.DWX, DAX.DWX, NDX.DWX, XAUUSD.DWX.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/trend-following]] -- primary
- [[concepts/cloud-breakout]] -- secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Single source lineage via `source_id`; public GitHub topic plus exact EA31337 repository/file and named institution. |
| R2 Mechanical | PASS | Tenkan/Kijun cross, cloud direction, Chikou relation, threshold, stop/profit, and time exits are explicit. |
| R3 Data Available | PASS | Ichimoku is computed from DWX OHLC bars on Forex, metal, and index CFDs. |
| R4 ML Forbidden | PASS | Deterministic Ichimoku rule; no ML, online adaptation, martingale, or multi-position requirement. |

## Pipeline-Verlauf
- G0: 2026-05-26, PENDING, drafted from GitHub topic:mql5 top-starred repository mining.

## Verwandte Strategien
- [[strategies/QM5_12432_ea31337-adx]] -- same source family, trend-strength confirmation.

## Lessons Learned (waehrend Pipeline-Lauf)
- 2026-05-26: The source uses nonstandard Tenkan/Kijun defaults (30/10); Q01 should keep those defaults for baseline, not substitute classic 9/26/52.
