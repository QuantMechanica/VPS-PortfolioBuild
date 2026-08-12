---
ea_id: QM5_11731
slug: tc-m5-s20-ema3-bb-macd
type: strategy
source_id: 40a4454c-64ff-5015-8538-9f7b32abc0e9
sources:
  - "[[sources/tc-m5-20-forex-strategies]]"
concepts:
  - "[[concepts/ema-crossover]]"
  - "[[concepts/bollinger-bands]]"
  - "[[concepts/macd-momentum]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/scalping]]"
indicators:
  - EMA(3)
  - BB(20, 3)
  - MACD(12,26,9)
period: M5
source_citation: "Thomas Carter, '20 Forex Trading Strategies (5 Minute Time Frame)', 2013. Strategy #20."
g0_status: APPROVED
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-24
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX]
expected_trades_per_year_per_symbol: 250
g0_approval_reasoning: "R1 PASS one source_id/source attribution; R2 PASS mechanical EMA3/BB mid cross + MACD zero-window with fixed exits, M5 cadence plausibly >2/year/symbol; R3 PASS DWX FX M5 testable; R4 PASS deterministic no ML."
r1_reasoning: "existing card attribution is canonical source lineage; R1 is informational and non-gating (2026-07-23)."
---

## Quelle

Thomas Carter, *20 Forex Trading Strategies (5 Minute Time Frame)*, Strategy #20, 2013. Source URL/local PDF: `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`.

Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX.

## Mechanik

**Konzept**: EMA(3) crossing the Bollinger Band middle line (SMA20) as the primary signal, confirmed by MACD approaching/crossing the zero line. The BB middle line acts as the dynamic support/resistance level; MACD zero-line proximity filters for momentum alignment.

**Entry (Long)**:
1. EMA(3) crosses ABOVE the BB middle band (SMA20): `EMA3[1] <= BB_mid[1] AND EMA3[0] > BB_mid[0]`
2. MACD(12,26,9) main line is crossing zero upward OR approaching zero from below (within 3 bars of crossing)
3. Enter at next bar open after confirmation

**Entry (Short)**:
1. EMA(3) crosses BELOW BB middle band: `EMA3[1] >= BB_mid[1] AND EMA3[0] < BB_mid[0]`
2. MACD main line crossing zero downward OR approaching from above (within 3 bars)
3. Enter at next bar open

**Stop Loss**: 10–15 pips. Factory default: 12 pips.

**Take Profit**: 10–15 pips. Factory default: 12 pips (symmetric 1:1 risk/reward).

**Exit**: Exit on fixed take profit, fixed stop loss, or opposite EMA3/BB middle-band cross if it occurs before TP/SL.

**Position Sizing**: RISK_FIXED = $1000 (backtest) / RISK_PERCENT = 0.5% (live).

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | FAIL | Anonymous collection strategy, no verifiable track record |
| R2 Mechanical | PASS | EMA3/BB-mid cross + MACD zero-proximity — fully mechanical with defined N-bar window |
| R3 Data Available | PASS | M5 DWX data available |
| R4 ML Forbidden | PASS | Standard indicators only |

## Implementation Notes for Codex (P1)

- EMA(3): `iMA(symbol, M5, 3, 0, MODE_EMA, PRICE_CLOSE, shift)`
- BB middle (SMA20): `iBands(symbol, M5, 20, 3, 0, PRICE_CLOSE, MODE_MAIN, shift)` — MODE_MAIN returns middle band
- BB is parameterized with 3 standard deviations (wider bands) — middle band is still SMA(20)
- MACD main: `iMACD(symbol, M5, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, shift)`
- MACD "approaching zero" condition: scan bars 0..2 for zero-cross: any of `MACD[i] > 0 AND MACD[i+1] <= 0` (for long) within 3-bar window
- Cross detection: check shift=1 vs shift=0 (bar 0 = last closed bar at tick)
- SL: `12 * _Point` below entry for long; `12 * _Point` above for short
- TP: `12 * _Point` above entry for long; `12 * _Point` below for short
- Note: 1:1 RR with frequent signals — expect high trade count; commission drag is significant at M5; Q04 commission gate will stress-test viability

## Pipeline-Verlauf

| Phase | Status | Datum |
|-------|--------|-------|
| G0 | PENDING | 2026-05-24 |
