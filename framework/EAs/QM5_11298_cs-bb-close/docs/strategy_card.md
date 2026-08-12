---
ea_id: QM5_11298
slug: cs-bb-close
type: strategy
source_id: 72f9fcfa-6c75-5544-80c4-31e15c9817ab
sources:
  - "[[sources/github-topic-algorithmic-trading-python]]"
concepts:
  - "[[concepts/volatility-breakout]]"
  - "[[concepts/bollinger-bands]]"
indicators:
  - "[[indicators/bollinger-bands]]"
period: H1
source_citation: "Abenezer Mamo / CryptoSignal contributors, app/analyzers/informants/bollinger_bands.py and app/analyzers/crossover.py, https://github.com/CryptoSignal/Crypto-Signal/blob/master/app/analyzers/informants/bollinger_bands.py"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; verifiable GitHub topic URL plus repository, Bollinger informant, and crossover analyzer URLs (CryptoSignal/Crypto-Signal)."
r2_mechanical: PASS
r2_reasoning: "Fixed BB(21,2) band-cross entry and midband exit are deterministic bar-close conditions."
r3_data_available: PASS
r3_reasoning: "H1 close-derived Bollinger Bands available on DWX FX majors and indices."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed-parameter Bollinger Bands; no ML, no adaptive logic, no grid or martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 45
last_updated: 2026-05-23
card_body_incomplete: true
card_body_missing: "source_citation,target_symbols"
g0_approval_reasoning: "R1 source URLs present; R2 mechanical H1 Bollinger band cross entry/midline exit with plausible >2 trades/year; R3 close-derived DWX symbols testable; R4 fixed rules, no ML/grid/martingale."
---

# CryptoSignal Bollinger Close Break

## Quelle
- Source: [[sources/github-topic-algorithmic-trading-python]]
- Topic URL: https://github.com/topics/algorithmic-trading?l=python
- Repository: `CryptoSignal/Crypto-Signal`
- 2026 URL citation: https://github.com/CryptoSignal/Crypto-Signal/blob/master/app/analyzers/informants/bollinger_bands.py
- Repo URL: https://github.com/CryptoSignal/Crypto-Signal
- Config docs: https://github.com/CryptoSignal/Crypto-Signal/blob/master/docs/config.md
- Bollinger informant: https://github.com/CryptoSignal/Crypto-Signal/blob/master/app/analyzers/informants/bollinger_bands.py
- Crossover analyzer: https://github.com/CryptoSignal/Crypto-Signal/blob/master/app/analyzers/crossover.py

## Mechanik

### Entry
- Timeframe: H1 bars.
- Compute source Bollinger Bands with `period_count = 21` and 2 standard deviations.
- Open long when close crosses above the upper band.
- Open short when close crosses below the lower band.

### Exit
- Close long when close crosses back below the middle band.
- Close short when close crosses back above the middle band.
- Reverse only after flat state on the next completed bar.

### Stop Loss
- Source is alert-oriented and has no native stop. V5 build should add default catastrophic `2.5 * ATR(14)` stop.

### Position Sizing
- V5 baseline uses fixed $1,000 risk and one position per magic.

### Zusaetzliche Filter
- Completed H1 bars only.
- Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, GER40.DWX.
- Optional P3 variant: mean-reversion mode entering short above upper band and long below lower band.

## Concepts
- [[concepts/volatility-breakout]] - primary
- [[concepts/bollinger-bands]] - source informant

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable GitHub topic URL plus repository, docs, Bollinger informant, and crossover analyzer URLs. |
| R2 Mechanical | PASS | Fixed Bollinger period/deviation and deterministic band-cross entry/exit. |
| R3 Data Available | PASS | Uses close-derived Bollinger bands available on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed-parameter band rules; no ML, adaptive logic, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-23, PENDING, drafted from GitHub Python topic Batch 6.

## Verwandte Strategien
- [[strategies/QM5_11270_qt-bb-w]] - Bollinger pattern-recognition family.

## Lessons Learned
- TBD
