---
ea_id: QM5_10292
slug: cinar-williamsr
type: strategy
source_id: 1b906e79-c619-5a61-90db-ee19ac95a19f
sources:
  - "[[sources/github-topic-algorithmic-trading]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/oscillator-threshold]]"
  - "[[concepts/range-position]]"
indicators:
  - "[[indicators/williams-r]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; public cinar/indicator GitHub repo with exact strategy and indicator file URLs is verifiable.
r2_mechanical: PASS
r2_reasoning: Williams %R period 14, formula, and -80/-20 threshold stop-and-reverse actions are deterministic in source code.
r3_data_available: PASS
r3_reasoning: Uses OHLC-derived range oscillator on D1; portable to any DWX FX, metals, or index CFD.
r4_ml_forbidden: PASS
r4_reasoning: Fixed period and thresholds; no ML, adaptive parameters, grid, or martingale.
pipeline_phase: G0
expected_trades_per_year_per_symbol: 30
last_updated: 2026-05-21
card_body_incomplete: true
card_body_missing: "source_citation,period"
g0_approval_reasoning: "R1 source URLs present; R2 deterministic Williams %R thresholds and stop-and-reverse with ~30 trades/year/symbol; R3 OHLC rules portable to DWX CFDs; R4 fixed-rule ML-free one-position design."
---

# Cinar Williams R Reversal

## Quelle
- Source: [[sources/github-topic-algorithmic-trading]]
- Topic URL: https://github.com/topics/algorithmic-trading
- Repository: `cinar/indicator`, author/handle `cinar` / Onur Cinar
- Source citation: 2026 URL, public `cinar/indicator` repository and exact strategy file below.
- Repo URL: https://github.com/cinar/indicator
- Strategy file: https://github.com/cinar/indicator/blob/master/strategy/momentum/williams_r_strategy.go
- Indicator file: https://github.com/cinar/indicator/blob/master/momentum/williams_r.go

## Mechanik

### Entry
- Timeframe: D1 daily bars for first V5 port.
- Compute Williams %R with source default period 14:
  - `WR = (HighestHigh(14) - Close) / (HighestHigh(14) - LowestLow(14)) * -100`.
- Open long when `WR <= -80`.
- Open short when `WR >= -20`.
- Hold when `-80 < WR < -20`.

### Exit
- Stop-and-reverse:
  - Close long and open short when `WR >= -20`.
  - Close short and open long when `WR <= -80`.
- Hold through the neutral zone unless the V5 catastrophic stop is hit.

### Stop Loss
- Source has no explicit hard stop. V5 build should add default catastrophic `2.0 * ATR(14)` stop.

### Position Sizing
- One net position at a time. V5 implementation should enforce one position per magic and no pyramiding.

### Zusaetzliche Filter
- Port to liquid DWX range or swing instruments: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, DAX.DWX, NDX.DWX, WS30.DWX.
- If only `SP500.DWX` passes, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Concepts
- [[concepts/mean-reversion]] - buys near recent range lows and sells near recent range highs.
- [[concepts/oscillator-threshold]] - fixed -80/-20 thresholds.
- [[concepts/range-position]] - close location inside the 14-bar high-low range.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable GitHub topic URL plus public `cinar/indicator` repo, author handle, and exact strategy/indicator file URLs. |
| R2 Mechanical | PASS | Williams %R period, formula, and threshold actions are explicit in source code. |
| R3 Data Available | PASS | Uses OHLC-derived range oscillator and ports directly to DWX FX, metals, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed period and thresholds; no ML, adaptive parameters, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING, drafted from GitHub topic catalog Batch 8.

## Verwandte Strategien
- [[strategies/QM5_10289_cinar-cci]] - oscillator-threshold directional system.
- [[strategies/QM5_10274_ltz-boll-mr]] - range/mean-reversion family.

## Lessons Learned
- TBD
