---
ea_id: QM5_11852
slug: bb50-234-meanturn-m1
type: strategy
source_id: f0aafe89-74a4-54d6-a2ec-9d555e7b2eb3
indicators:
  - BB(50,2)
  - BB(50,3)
  - BB(50,4)
period: M1
source_citation: "Chelo (via Rita Lasker / Green Forex Group), 'Great GBP/JPY 1M Scalping Strategy', ~2012. Source PDF: 180977573-Forex-Gbpjpy-Scalping-Strategy.pdf. URL: http://www.ritalasker.com."
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id with PDF and URL to ritalasker.com satisfies lineage requirement; anonymous forum handle is permitted."
r2_mechanical: PASS
r2_reasoning: "BB50 deviation-band reversion entry with explicit midpoint threshold, ATR SL, SMA50 TP, and time-based exit are fully mechanical."
r3_data_available: PASS
r3_reasoning: "GBPJPY, EURJPY, USDJPY are directly available DWX forex instruments."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic Bollinger Band arithmetic; no ML, no PnL-adaptive parameters, 1-pos-per-magic compatible."
pipeline_phase: G0
last_updated: 2026-05-24
target_symbols: [GBPJPY.DWX, EURJPY.DWX, USDJPY.DWX]
expected_trades_per_year_per_symbol: 600
g0_approval_reasoning: "R1 PASS single source_id/PDF URL; R2 PASS mechanical BB50 deviation reversion entries with SMA/TP/ATR/time exits, ~600 M1 trades/year/symbol plausible; R3 PASS DWX JPY FX symbols; R4 PASS deterministic ML-free 1-pos compatible."
---

## Quelle

Chelo (via Rita Lasker / Green Forex Group), *Great GBP/JPY 1M Scalping Strategy* (~2012). Source PDF: `180977573-Forex-Gbpjpy-Scalping-Strategy.pdf`. URL: http://www.ritalasker.com.

source_citation: Chelo (via Rita Lasker / Green Forex Group), 'Great GBP/JPY 1M Scalping Strategy', ~2012. Source PDF: 180977573-Forex-Gbpjpy-Scalping-Strategy.pdf. URL: http://www.ritalasker.com.

## Mechanik

**Konzept**: Three Bollinger Bands all with period 50 but increasing deviation (2, 3, 4). Price oscillates between the bands. When price extends into the BB(50,3) or BB(50,4) zone, it tends to revert to the BB(50,1) midline (SMA50). Mean-reversion scalping for GBPJPY M1/M5/M15.

**Setup**: All 3 BB use period=50, applied to Close. Bands: Red=Dev2, Orange=Dev3, Yellow=Dev4.

**Entry (Sell)**:
1. Previous bar's close > BB(50,2) upper (Red band upper) — price has extended beyond 2-sigma
2. Previous bar's close >= midpoint of BB_upper(50,2) and BB_upper(50,3) — at least halfway to Orange
3. Current bar closes below BB(50,2) upper — retrace started
→ Sell at open of current bar (or on bar close confirmation)

**Entry (Buy)**:
1. Previous bar's close < BB(50,2) lower — extended beyond 2-sigma to downside
2. Previous bar's close <= midpoint of BB_lower(50,2) and BB_lower(50,3)
3. Current bar closes above BB(50,2) lower — retrace started
→ Buy at open of current bar

**Stop Loss**: 1×ATR(14) from entry (source: very tight; time-based also acceptable)

**Take Profit**: BB(50,1) midline (SMA50). Factory: 10 pips fixed.

**Position Sizing**: RISK_FIXED = $1000 (backtest) / RISK_PERCENT = 0.5% (live).

**Session filter**: London open through Tokyo close (07:00–13:00 GMT). Source: avoid news releases and quiet markets.

**Note**: M5 or M15 recommended over M1 for lower spread impact. Source primary pair: GBPJPY.

## Exit

Exit when price reaches SMA50 (BB midline) or hard TP at 10 pips. SL: 1×ATR(14) from entry. Time-based exit: close if no movement within 5 bars (M1) or 3 bars (M5).

## Target Symbols

Target symbols: GBPJPY.DWX, EURJPY.DWX, USDJPY.DWX.

## Implementation Notes for Codex (P1)

- BB(50,2) upper: `iBands(symbol, M1, 50, 2, 0, PRICE_CLOSE, MODE_UPPER, 1)`
- BB(50,3) upper: `iBands(symbol, M1, 50, 3, 0, PRICE_CLOSE, MODE_UPPER, 1)`
- BB(50,4) upper: `iBands(symbol, M1, 50, 4, 0, PRICE_CLOSE, MODE_UPPER, 1)`
- BB(50,1) middle: `iBands(symbol, M1, 50, 2, 0, PRICE_CLOSE, MODE_BASE, 1)` — SMA50
- Midpoint check: `Close[2] >= (bb2_upper[2] + bb3_upper[2]) / 2`
- Entry sell: `Close[2] > bb2_upper[2] AND Close[2] >= midpoint AND Close[1] < bb2_upper[1]`
- Entry buy: mirror at lower bands
- TP: `entry - (entry - bb_middle[1])` — exit when price touches SMA50

## Pipeline-Verlauf

| Phase | Status | Datum |
|-------|--------|-------|
| G0 | PENDING | 2026-05-24 |
