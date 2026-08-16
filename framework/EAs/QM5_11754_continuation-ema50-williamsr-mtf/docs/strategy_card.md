---
ea_id: QM5_11754
slug: continuation-ema50-williamsr-mtf
type: strategy
source_id: 8fc38d7b-ef60-57f3-97f3-24eab132b1d9
sources:
  - "[[sources/6-simple-strategies-trading-forex]]"
concepts:
  - "[[concepts/ema-trend-filter]]"
  - "[[concepts/williams-percent-r]]"
  - "[[concepts/mtf-trend-filter]]"
  - "[[concepts/pullback-entry]]"
  - "[[concepts/trailing-stop]]"
  - "[[concepts/trend-following]]"
indicators:
  - EMA(50) on D1
  - SMA(5) on H4
  - Williams %R on H4
period: H4
source_citation: "Cecil Robles, 'The Continuation Method', in 6 Simple Strategies for Trading Forex, tradingpub.com, ~2015."
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-24
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, USDCAD.DWX]
expected_trades_per_year_per_symbol: 30
card_body_incomplete: true
card_body_missing: "source_citation,target_symbols"
g0_approval_reasoning: "R1 PASS single source_id/source attribution; R2 PASS mechanical EMA/WilliamsR H4 continuation with plausible ~30/y/symbol cadence; R3 PASS DWX FX D1/H4 testable; R4 PASS deterministic non-ML 1-position compatible"
---

## Quelle

Cecil Robles, *The Continuation Method*, in *6 Simple Strategies for Trading Forex* (tradingpub.com), ~2015. Source URL/local PDF: `459341651-6-Simple-Strategies-for-Trading-Forex-pdf.pdf`, pages 35–54.

## Mechanik

**Konzept**: Multi-timeframe trend following. D1 EMA(50) defines the macro trend; H4 EMA(50) identifies the pullback; Williams %R on H4 times the re-entry. Trail stop using SMA(5) after 2:1 RR achieved. Source describes multiple TF combinations — factory implements D1+H4.

**Phase 1 — D1 Trend**:
- D1 EMA(50) sloping UP and price above it (or recently above after bars of confirmation) → bullish macro bias
- D1 EMA(50) sloping DOWN, price below → bearish

**Phase 2 — H4 Pullback Detection**:
- In a bullish macro trend: H4 bar closes BELOW H4 EMA(50) — pullback against the trend
- In a bearish macro trend: H4 bar closes ABOVE H4 EMA(50)

**Phase 3 — Williams %R Entry Signal**:
- Long: Williams %R(H4) drops below -80 (oversold during pullback) THEN rises back ABOVE -80
- Short: Williams %R rises above -20 (overbought during pullback rally) THEN falls back BELOW -20
- Signal bar: the H4 bar on which WR crosses back through the threshold level
- Enter LONG at open of bar after the WR signal bar (H4 timeframe)

**Stop Loss**: Signal bar Low (for long) or High (for short).

**Exit / Trailing Stop**:
- Primary: trail stop using SMA(5) on H4 AFTER 2:1 reward-to-risk achieved (price has moved 2× the initial SL distance from entry)
- Trail mechanism: once 2:1 reached, move SL to low of the last 2 closes below SMA(5) on H4 for longs
- Hard TP: 4–7×ATR(14) on H4

**Position Sizing**: RISK_FIXED = $1000 (backtest) / RISK_PERCENT = 0.5% (live).

**Target symbol(s)**: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, USDCAD.DWX.

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | FAIL | tradingpub.com compilation contributor, no verifiable track record |
| R2 Mechanical | PASS | EMA50 position + WR level cross + SMA5 trail — all numerically testable |
| R3 Data Available | PASS | D1+H4 DWX data available |
| R4 ML Forbidden | PASS | Standard indicators only |

## Implementation Notes for Codex (P1)

- D1 EMA(50): `iMA(symbol, D1, 50, 0, MODE_EMA, PRICE_CLOSE, 0)` — check slope: `EMA50_D1[0] > EMA50_D1[1]` (rising)
- H4 EMA(50): `iMA(symbol, H4, 50, 0, MODE_EMA, PRICE_CLOSE, 0)` — pullback: `Close[0] < EMA50_H4[0]` in uptrend
- Williams %R: `iWPR(symbol, H4, 14, 0)` — MT5 built-in; range -100 to 0; <-80 = oversold, >-20 = overbought
- WR cross back above -80 (for long): `WR[1] <= -80 AND WR[0] > -80`
- D1 trend check: `Close_D1[0] > EMA50_D1[0]` on H4 bar (use D1 close from yesterday: `iClose(symbol, D1, 1)`)
- H4 pullback active: `Close_H4[0] < EMA50_H4[0]` — confirm pullback is in progress
- Entry: all conditions in sequence → LONG at next H4 bar open
- SL: `Low[1] - 1 * _Point * 10` (H4 signal bar low, shift=1 after entry)
- Trail: implement state machine: state=WATCHING until 2×risk profit achieved; state=TRAILING after that; on each bar check SMA(5) and last 2 closes for trailing stop update
- SMA(5) trail: `iMA(symbol, H4, 5, 0, MODE_SMA, PRICE_CLOSE, 0)` — move SL to lowest 2-bar close below SMA5

## Pipeline-Verlauf

| Phase | Status | Datum |
|-------|--------|-------|
| G0 | PENDING | 2026-05-24 |
