---
ea_id: QM5_11593
slug: robo-midnight-hammer-adx-d1
type: strategy
source_id: ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
sources:
  - "[[sources/362359657-robo-forex-strategy]]"
concepts:
  - "[[concepts/adx-di]]"
  - "[[concepts/candle-pattern]]"
  - "[[concepts/trend-filter]]"
indicators:
  - ADX(14)
  - EMA(24)
period: D1
source_citation: "RoboForex Educational Team, 'Forex Strategy Collection', ~2015. Strategy: 'Midnight', pages 109-110."
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id (ed246754) with verifiable RoboForex Strategy Collection citation, pages 109-110."
r2_mechanical: PASS
r2_reasoning: "Deterministic D1 candle tail/body ratio checks plus ADX/DI threshold conditions; EOD or fixed 2R exit."
r3_data_available: PASS
r3_reasoning: "Six major FX pairs (EURUSD, GBPUSD, AUDUSD, USDJPY, NZDUSD, USDCAD) testable on DWX D1."
r4_ml_forbidden: PASS
r4_reasoning: "Standard price arithmetic and iADX indicator; no ML, adaptive parameters, grid, or martingale."
pipeline_phase: G0
last_updated: 2026-05-24
target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX, NZDUSD.DWX, USDCAD.DWX]
expected_trades_per_year_per_symbol: 30
g0_approval_reasoning: "R1 single source_id/source citation; R2 deterministic D1 hammer/shooting-star plus ADX/DI entry with stop/EOD or 2R exit and plausible >2/year/symbol cadence; R3 major FX DWX-testable; R4 deterministic ML-free 1-position compatible."
---

## Quelle

RoboForex Educational Team, *Forex Strategy Collection* (2015). Source PDF: `362359657-Robo-forex-strategy.pdf`, pages 109-110. Strategy: "Midnight". URL: https://roboforex.com/beginners/analytics/forex-forecast/technical-analysis/

## Mechanik

**Konzept**: D1 hammer/shooting-star candle pattern (tail 3x body, small upper tail) combined with ADX(14) trend strength and DI direction confirmation. Close within same day.

**Entry (Long)**:
1. Long shadow (bottom tail) = 3× or more the body size
2. Upper tail ≤ 50% of bottom tail
3. ADX(14) main line > 20
4. DI+ > DI- (bullish direction) AND DI+ > 20
5. DI- < 20
→ Buy at next D1 candle open

**Entry (Short)**:
1. Long shadow (top tail) = 3× or more the body size
2. Lower tail ≤ 50% of top tail
3. ADX(14) main line > 20
4. DI- > DI+ (bearish direction) AND DI- > 20
5. DI+ < 20
→ Sell at next D1 candle open

**Stop Loss**: Previous D1 low (for longs); previous D1 high (for shorts)

**Exit**: Close at end of the same D1 candle, or fixed TP at 2x SL distance in factory tests.

**Take Profit**: Source: close at end of the same daily candle. Factory: 2×SL distance as fixed TP; also test with EOD close.

**Note**: EMA(24) from source used only as context indicator (no specific entry condition defined). Not included in entry logic.

**Position Sizing**: RISK_FIXED = $1000 (backtest) / RISK_PERCENT = 0.5% (live).

**Target Symbols**: EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX, NZDUSD.DWX, USDCAD.DWX.

## Implementation Notes for Codex (P1)

- Bottom tail: `Open[1] - Low[1]` for bullish candle (Close > Open) or `Close[1] - Low[1]`
- Body size: `MathAbs(Close[1] - Open[1])`
- Tail-to-body ratio: `(Open[1] - Low[1]) >= 3 * MathAbs(Close[1] - Open[1])` for hammer
- ADX: `iADX(symbol, D1, 14, PRICE_CLOSE, MODE_MAIN, 1)` > 20
- DI+/DI-: `iADX(symbol, D1, 14, PRICE_CLOSE, MODE_PLUSDI, 1)` etc.

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Institutional publisher (RoboForex) |
| R2 Mechanical | PASS | Deterministic candle ratios + ADX |
| R3 Data Available | PASS | D1 DWX available |
| R4 ML Forbidden | PASS | Standard ADX + price ratios |

## Pipeline-Verlauf

| Phase | Status | Datum |
|-------|--------|-------|
| G0 | PENDING | 2026-05-24 |
