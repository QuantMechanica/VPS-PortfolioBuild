---
ea_id: QM5_11838
slug: robo-two-pairs-ema-macd-h4
type: strategy
source_id: ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
sources:
  - "[[sources/362359657-robo-forex-strategy]]"
concepts:
  - "[[concepts/ema-fan]]"
  - "[[concepts/macd]]"
  - "[[concepts/trend-following]]"
indicators:
  - EMA(5)
  - EMA(15)
  - EMA(50)
  - EMA(100)
  - MACD(12,26,9)
period: H4
source_citation: "RoboForex Educational Team, 'Forex Strategy Collection', ~2015. Strategy: 'Two Pairs EMA + MACD', page 92."
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id (ed246754) linking to RoboForex PDF with page reference; one source attribution present.
r2_mechanical: PASS
r2_reasoning: Four-EMA cascade alignment (5>15>50>100) plus MACD confirmation for entry, with ATR SL/TP and EMA cross reversal exit — all deterministically implementable in MQL5.
r3_data_available: PASS
r3_reasoning: Targets EURUSD/GBPUSD H4 DWX symbols (primary pairs per source intent), both available in the factory.
r4_ml_forbidden: PASS
r4_reasoning: Four EMAs and MACD with fixed parameters; deterministic, no ML, no adaptive PnL logic, 1-position-per-magic compatible.
pipeline_phase: G0
last_updated: 2026-05-24
target_symbols: EURUSD,GBPUSD
expected_trades_per_year_per_symbol: 40
card_body_incomplete: true
card_body_missing: "source_citation,target_symbols"
g0_approval_reasoning: "R1 PASS single source_id/source citation; R2 PASS deterministic H4 EMA cascade plus MACD entries and EMA/ATR exits with plausible >=2 trades/year/symbol; R3 PASS DWX FX H4 testable; R4 PASS non-ML fixed indicators one-position compatible."
---

## Quelle

RoboForex Educational Team, *Forex Strategy Collection* (~2015). Source PDF: `362359657-Robo-forex-strategy.pdf`, page 92. Strategy: "Two Pairs EMA + MACD". URL/local source record: [[sources/362359657-robo-forex-strategy]].

**Note**: Source strategy originally described for two specific pairs. Factory tests on full universe first.

## Mechanik

**Konzept**: Four EMAs (5, 15, 50, 100) create a multi-layered trend filter. EMA(5,15) are fast trend signals; EMA(50,100) are macro trend anchors. MACD(12,26,9) provides entry timing. Full alignment of fast and slow MA structure required.

**Entry (Long)**:
1. EMA(5) > EMA(15) > EMA(50) > EMA(100) — full bullish EMA cascade
2. MACD(12,26,9) main line > 0 or crosses signal line upward
→ Buy at market

**Entry (Short)**:
1. EMA(5) < EMA(15) < EMA(50) < EMA(100) — full bearish EMA cascade
2. MACD(12,26,9) main line < 0 or crosses signal line downward
→ Sell at market

**Stop Loss**: 2×ATR(14) factory default; source: below EMA(50) for longs

**Take Profit**: 4×ATR(14) factory default; exit on EMA(5)/EMA(15) cross reversal

**Position Sizing**: RISK_FIXED = $1000 (backtest) / RISK_PERCENT = 0.5% (live).

**Target symbols**: EURUSD.DWX, GBPUSD.DWX.

## Implementation Notes for Codex (P1)

- EMA(5): `iMA(symbol, H4, 5, 0, MODE_EMA, PRICE_CLOSE, 1)`
- EMA(15): `iMA(symbol, H4, 15, 0, MODE_EMA, PRICE_CLOSE, 1)`
- EMA(50): `iMA(symbol, H4, 50, 0, MODE_EMA, PRICE_CLOSE, 1)`
- EMA(100): `iMA(symbol, H4, 100, 0, MODE_EMA, PRICE_CLOSE, 1)`
- MACD(12,26,9) main: `iMACD(symbol, H4, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 1)`
- Full cascade long: `ema5[1] > ema15[1] AND ema15[1] > ema50[1] AND ema50[1] > ema100[1]`

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Institutional publisher (RoboForex) |
| R2 Mechanical | PASS | Standard EMA cascade + MACD; deterministic |
| R3 Data Available | PASS | H4 DWX available |
| R4 ML Forbidden | PASS | Standard indicators only |

## Pipeline-Verlauf

| Phase | Status | Datum |
|-------|--------|-------|
| G0 | PENDING | 2026-05-24 |
