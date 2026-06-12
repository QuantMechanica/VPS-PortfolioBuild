---
ea_id: QM5_10272
slug: ltz-turtle20
type: strategy
source_id: 1b906e79-c619-5a61-90db-ee19ac95a19f
sources:
  - "[[sources/github-topic-algorithmic-trading]]"
concepts:
  - "[[concepts/donchian-breakout]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present with verifiable GitHub repository URL and named author handle letianzj."
r2_mechanical: PASS
r2_reasoning: "Donchian20 entry, 10-day-low exit, and ATR stop are fully deterministic; pyramiding disabled for V5 initial single-entry build."
r3_data_available: PASS
r3_reasoning: "Ports to SP500.DWX, NDX.DWX, WS30.DWX, XAUUSD.DWX; SP500.DWX live-routing caveat noted."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed channel and ATR parameters; pyramiding either disabled or slot-allocated per V5 build note; no ML, no martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 10
last_updated: 2026-05-21
g0_approval_reasoning: "R1 source URLs present; R2 deterministic Donchian/ATR Turtle rules with ~10 trades/year/symbol; R3 portable to SP500.DWX/NDX/WS30/XAUUSD; R4 no ML, pyramiding disabled or slot-allocated for HR14."
---

# Letian Wang Turtle 20-Day Donchian

## Quelle
- Source: [[sources/github-topic-algorithmic-trading]]
- Topic URL: https://github.com/topics/algorithmic-trading
- Repository: `letianzj/QuantResearch`, author/handle Letian Wang (`letianzj`)
- File: https://github.com/letianzj/QuantResearch/blob/master/backtest/turtle.py
- Alternate Backtrader file: https://github.com/letianzj/QuantResearch/blob/master/backtest/bt/turtle.py
- Citation check: 2026 URL-backed GitHub source files above.

## Mechanik

### Entry
- Use D1 daily bars by default.
- Compute `don_high = highest(High, 20)` excluding the current bar.
- Compute ATR from 14 bars of true range.
- If flat and `Close > don_high`, open long.

### Exit
- Compute `don_low = lowest(Low, 10)` excluding the current bar.
- Exit long if `Close < don_low`.
- Exit long if `Close < entry_price - 2 * ATR(14)`.

### Stop Loss
- Source stop is `entry_price - 2 * ATR(14)`.

### Position Sizing
- Source sizes one unit as `1% of account / ATR` and allows pyramiding every `0.5 * ATR` up to three adds.
- V5-safe initial build should use one position per magic. If CEO wants source-faithful pyramiding, allocate explicit add-slot magics; otherwise build the single-entry/no-adds variant first.

### Zusaetzliche Filter
- Long-only source implementation. No short-side rule in this file.

## Concepts
- [[concepts/donchian-breakout]] - primary
- [[concepts/trend-following]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable GitHub topic URL plus `letianzj/QuantResearch` turtle source files and cited Richard Dennis Turtle rules references inside the file. |
| R2 Mechanical | PASS | Donchian entry, 10-day-low exit, and ATR stop are deterministic. |
| R3 Data Available | PASS | Source tests SPX. Port to SP500.DWX for backtest and NDX.DWX/WS30.DWX/XAUUSD.DWX for trend-following validation. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. |
| R4 ML Forbidden | PASS | No ML. Pyramiding must be either disabled for V5 initial build or implemented with explicit slot allocation. |

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING, drafted from GitHub topic catalog Batch 2.

## Verwandte Strategien
- [[strategies/lien-20day-breakout]] - also Donchian-family, but Lien requires a failed-pullback re-break filter; this Turtle variant enters on the raw 20-day high.

## Lessons Learned
- TBD
