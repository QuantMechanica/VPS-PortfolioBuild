---
ea_id: QM5_10074
slug: gh-santi-adxma
type: strategy
source_id: 3b3ec48a-0755-5187-9331-afb36e174175
sources:
  - "[[sources/github-mql5-stars-20]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/trend-strength-filter]]"
indicators:
  - "[[indicators/moving-average]]"
  - "[[indicators/adx]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 80
last_updated: 2026-05-19
g0_approval_reasoning: "R1 linked GitHub source/author; R2 mechanical EMA+ADX+DI entry and SL/TP exit with ~80 trades/year/symbol; R3 OHLC indicators portable to DWX; R4 fixed rules no ML/grid/martingale one-position."
---

# GitHub Santiago ADX EMA Trend Filter

## Quelle
- Source: [[sources/github-mql5-stars-20]]
- Page / Timestamp: `santiago-cruzlopez/MQL5`, `1_Expert_Advisors_EA/019_ADX_EA.mq5`, https://github.com/santiago-cruzlopez/MQL5/blob/master/1_Expert_Advisors_EA/019_ADX_EA.mq5
- Source-code author/institution: Santiago Cruz, https://www.mql5.com/en/users/algo-trader/
- Source citation URL 2026: https://github.com/santiago-cruzlopez/MQL5/blob/master/1_Expert_Advisors_EA/019_ADX_EA.mq5
- Target symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX.
- Period: H1 baseline.

## Mechanik

### Entry
- Process only once per newly opened bar.
- Calculate EMA 8 on close and ADX 8 with +DI and -DI.
- Buy when EMA is rising across the last three samples, previous closed bar is above EMA, ADX is above 22, and +DI is above -DI.
- Sell when EMA is falling across the last three samples, previous closed bar is below EMA, ADX is above 22, and -DI is above +DI.
- V5 constraint: one active position per symbol/magic; do not open a second same-direction position.

### Exit
- Source exits via attached fixed stop loss and take profit.
- No opposite-signal close is specified in the source.

### Stop Loss
- Source default stop loss: 30 pips, digit-normalized.

### Position Sizing
- Source default volume: fixed lot 0.1.
- V5 baseline: fixed risk $1,000 for P2.

### Zusatzliche Filter
- ADX minimum 22 is mandatory trend-strength filter.
- Optional spread/session/news filters may be added by V5 framework defaults, not as source edge logic.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/trend-strength-filter]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full GitHub file URL and named source-code author Santiago Cruz are cited. |
| R2 Mechanical | PASS | EMA slope, price/EMA relation, ADX threshold, DI direction, SL, and TP are deterministic. |
| R3 Data Available | PASS | EMA and ADX use OHLC-derived data available on DWX forex, metals, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed parameters, no ML, no martingale, no grid; V5 enforces one active position per magic. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10076_gh-santi-cci2ma]] - same source repository, different confirmation indicators.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
