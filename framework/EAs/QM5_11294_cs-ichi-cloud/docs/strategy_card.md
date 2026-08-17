---
ea_id: QM5_11294
slug: cs-ichi-cloud
type: strategy
source_id: 72f9fcfa-6c75-5544-80c4-31e15c9817ab
sources:
  - "[[sources/github-topic-algorithmic-trading-python]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/ichimoku]]"
indicators:
  - "[[indicators/ichimoku]]"
period: H4
source_citation: "Abenezer Mamo / CryptoSignal contributors, app/analyzers/indicators/ichimoku.py, https://github.com/CryptoSignal/Crypto-Signal/blob/master/app/analyzers/indicators/ichimoku.py"
g0_status: APPROVED
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 8
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GDAXI.DWX, NDX.DWX]
last_updated: 2026-07-26
card_body_incomplete: true
card_body_missing: "legacy_contract_repair"
g0_rejection_reason: "SUPERSEDED: source-only rejection recovered under OWNER R1 policy on 2026-07-23; original retained in cards_rejected."
status: draft
r1_reasoning: "Existing attribution retained; R1 is informational and non-gating under OWNER policy 2026-07-23."
r2_reasoning: "Fixed-period Ichimoku (9/26/52) cloud-state entry/exit with explicit long/short/flat transition logic on completed bars is fully deterministic."
r3_reasoning: "Strategy uses standard OHLC data, testable on target_symbols EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GDAXI.DWX, NDX.DWX."
r4_reasoning: "Fixed Ichimoku arithmetic and cloud-state comparison only; no ML/online-learning/adaptive-PnL sizing; one position per magic."
legacy_contract_repair: true
g0_recovery_reason: "Source-only rejection recovered; fresh semantic R2-R4 G0 review required."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_11294_cs-ichi-cloud.md"
g0_approval_reasoning: "R1 lineage recorded; R2 deterministic H4 Ichimoku cloud-state entries/exits with conservative 8 trades/year; R3 OHLC-testable on listed .DWX symbols; R4 deterministic, ML-free, one-position compatible."
expected_pf: 1.2
expected_dd_pct: 20.0
---

# CryptoSignal Ichimoku Cloud State

## Quelle
- Source: [[sources/github-topic-algorithmic-trading-python]]
- Topic URL: https://github.com/topics/algorithmic-trading?l=python
- Repository: `CryptoSignal/Crypto-Signal`, founder named in topic metadata as Abenezer Mamo
- Repo URL: https://github.com/CryptoSignal/Crypto-Signal
- Config docs: https://github.com/CryptoSignal/Crypto-Signal/blob/master/docs/config.md
- Analyzer file: https://github.com/CryptoSignal/Crypto-Signal/blob/master/app/analyzers/indicators/ichimoku.py

## Mechanik

### Entry
- Timeframe: H4 bars for initial DWX port.
- Compute source Ichimoku periods: Tenkan-sen 9, Kijun-sen 26, Leading Span B 52.
- Compute `leading_span_a = (tenkansen + kijunsen) / 2`.
- Open long when `leading_span_a > leading_span_b` and close is above `leading_span_a`.
- Open short when `leading_span_a < leading_span_b` and close is below `leading_span_a`.

### Exit
- Close long when the bearish state appears: `leading_span_a < leading_span_b` and close is below `leading_span_a`.
- Close short when the bullish state appears.
- Reverse only after flat state on the next completed bar.

### Stop Loss
- Source is alert-oriented and has no native stop. V5 build should add default catastrophic `3.0 * ATR(14)` stop.

### Position Sizing
- V5 baseline uses fixed $1,000 risk and one position per magic.

### Zusaetzliche Filter
- Use completed bars only.
- Initial basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/ichimoku]] - cloud direction and price confirmation

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable GitHub topic URL plus repository, docs, and exact analyzer URL. |
| R2 Mechanical | PASS | Fixed Ichimoku periods and explicit hot/cold logic in source analyzer. |
| R3 Data Available | PASS | Uses OHLC high/low/close data available on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed indicator logic; no ML, online learning, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-23, PENDING, drafted from GitHub Python topic Batch 6.

## Verwandte Strategien
- [[strategies/QM5_11257_cs-rsi-mtf]] - same repository, RSI alert logic.

## Lessons Learned
- TBD
