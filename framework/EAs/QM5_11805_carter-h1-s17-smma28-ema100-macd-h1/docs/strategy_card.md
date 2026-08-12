---
ea_id: QM5_11805
slug: carter-h1-s17-smma28-ema100-macd-h1
type: strategy
source_id: 529382f8-fbd1-5c17-ba62-fbe56990ebcd
indicators:
  - SMMA(28)
  - EMA(100)
  - MACD(30,60,30)
period: H1
pair: EURUSD
source_citation: "Thomas Carter, '20 Forex Trading Strategies (1 Hour Time Frame)', Scribd ~2014. Strategy S17. Source PDF: 376863900-20-Forex-Trading-Strategies-Collection.pdf."
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-26
target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX]
expected_trades_per_year_per_symbol: 30
g0_approval_reasoning: "R1 single Carter Scribd/PDF source_id attribution; R2 mechanical H1 SMMA/EMA trend filter plus MACD zero-cross entries and SL/TP/reversal exits with plausible ~30 trades/year/symbol; R3 EURUSD/GBPUSD/AUDUSD DWX testable; R4 deterministic non-ML one-position compatible."
---

## Quelle

Thomas Carter, *20 Forex Trading Strategies (1 Hour Time Frame)* (Scribd, ~2014). URL/local PDF: `376863900-20-Forex-Trading-Strategies-Collection.pdf`, Strategy S17.

source_citation: Thomas Carter, '20 Forex Trading Strategies (1 Hour Time Frame)', Scribd ~2014. Strategy S17.

## Mechanik

**Konzept**: Slow-trend system. EMA(100) defines primary trend direction. SMMA(28) above/below EMA(100) provides medium-term trend filter. MACD(30,60,30) histogram crossing zero triggers entry within the trending context.

**Entry (Long)**:
1. SMMA(28) > EMA(100) — medium-term above long-term trend (bullish structure)
2. MACD(30,60,30) histogram crosses above 0
→ Buy at market

**Entry (Short)**:
1. SMMA(28) < EMA(100) — bearish structure
2. MACD(30,60,30) histogram crosses below 0
→ Sell at market

**Stop Loss**: 50 pips (source); factory: 2×ATR(14)

**Take Profit**: 70–100 pips (source); factory: 4×ATR(14)

**Position Sizing**: RISK_FIXED = $1000 (backtest) / RISK_PERCENT = 0.5% (live).

## Exit

Exit at 70–100-pip TP or 50-pip SL. Also exit when SMMA(28)/EMA(100) relationship reverses.

## Target Symbols

Target symbols: EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX.

## Implementation Notes for Codex (P1)

- SMMA(28): `iMA(symbol, H1, 28, 0, MODE_SMMA, PRICE_CLOSE, 1)`
- EMA(100): `iMA(symbol, H1, 100, 0, MODE_EMA, PRICE_CLOSE, 1)`
- MACD(30,60,30): `iMACD(symbol, H1, 30, 60, 30, PRICE_CLOSE, MODE_MAIN, 1)` for histogram
- MACD cross: `macd_hist[2] < 0 AND macd_hist[1] > 0` for long

## Pipeline-Verlauf

| Phase | Status | Datum |
|-------|--------|-------|
| G0 | PENDING | 2026-05-24 |
