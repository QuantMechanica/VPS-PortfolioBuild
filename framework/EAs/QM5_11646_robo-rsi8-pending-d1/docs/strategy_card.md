---
ea_id: QM5_11646
slug: robo-rsi8-pending-d1
type: strategy
source_id: ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
sources:
  - "[[sources/362359657-robo-forex-strategy]]"
concepts:
  - "[[concepts/rsi]]"
  - "[[concepts/pending-order]]"
  - "[[concepts/momentum-breakout]]"
indicators:
  - RSI(8)
period: D1
source_citation: "RoboForex Educational Team, 'Forex Strategy Collection', ~2015. Strategy: 'RSI Pending', page 115."
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id (ed246754) with RoboForex institutional PDF attribution at page 115."
r2_mechanical: PASS
r2_reasoning: "RSI(8) threshold triggers a pending stop order placed at a fixed offset from bar open, auto-cancelled at bar close — fully deterministic."
r3_data_available: PASS
r3_reasoning: "D1 EURUSD, GBPUSD, AUDUSD, USDJPY, USDCAD DWX bars are available."
r4_ml_forbidden: PASS
r4_reasoning: "Standard RSI indicator with fixed rules; no ML, no martingale, one-position compatible."
pipeline_phase: G0
last_updated: 2026-06-01
target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX, USDCAD.DWX]
expected_trades_per_year_per_symbol: 25
card_body_incomplete: true
card_body_missing: "source_citation,exit,target_symbols"
g0_approval_reasoning: "R1 single source_id with RoboForex PDF/page attribution; R2 deterministic RSI(8) D1 pending-stop entries with SL/TP/cancel exits and plausible >=2 trades/year/symbol FX cadence; R3 testable on DWX FX symbols; R4 deterministic non-ML one-position compatible."
---

## Quelle

RoboForex Educational Team, *Forex Strategy Collection* (2015). URL/local PDF: `362359657-Robo-forex-strategy.pdf`, page 115. Strategy: "RSI Pending".

Target symbols: EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX, USDCAD.DWX.

## Mechanik

**Konzept**: RSI(8) identifies momentum extremes on D1. Instead of entering at market, a pending stop order is placed 20 pips above (for buy) or below (for sell) the current bar's open price. This filters out fakeouts: the pending order only fills if price actually breaks out in the RSI-indicated direction.

**Entry (Long)**:
1. RSI(8) > 70 — overbought momentum (upside breakout expected)
2. Place BUY STOP order 20 pips above current D1 open price
→ Order valid for the current D1 bar; cancel if not filled by bar close

**Entry (Short)**:
1. RSI(8) < 30 — oversold momentum (downside breakout expected)
2. Place SELL STOP order 20 pips below current D1 open price
→ Order valid for the current D1 bar; cancel if not filled by bar close

**Stop Loss**: 2×ATR(14) factory default; measured from order fill price

**Take Profit**: 4×ATR(14) factory default

**Exit**: Close via Stop Loss or Take Profit; cancel unfilled pending order at D1 bar close.

**Note**: Factory implementation uses BUY STOP / SELL STOP pending orders. The 20-pip offset must be scaled by instrument (20 pips = 0.0020 for 5-decimal pairs, 0.20 for JPY pairs).

**Position Sizing**: RISK_FIXED = $1000 (backtest) / RISK_PERCENT = 0.5% (live).

## Implementation Notes for Codex (P1)

- RSI(8): `iRSI(symbol, D1, 8, PRICE_CLOSE, 0)` — current bar (bar 0) for real-time RSI check
- Pending offset: `20 * _Point * (Digits == 3 || Digits == 5 ? 10 : 1)` — JPY/non-JPY scaling
- BUY STOP: `OrderSend(symbol, OP_BUYSTOP, lots, Ask + offset, ...)` placed at bar open
- SELL STOP: `OrderSend(symbol, OP_SELLSTOP, lots, Bid - offset, ...)` placed at bar open
- Cancel logic: delete pending order on next bar open if unfilled
- RSI > 70 condition checked at D1 open (bar 0 not yet closed); use bar 1 for confirmed signal or bar 0 for live signal

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Institutional publisher (RoboForex) |
| R2 Mechanical | PASS | Fully deterministic; RSI threshold + fixed offset pending order |
| R3 Data Available | PASS | D1 DWX available |
| R4 ML Forbidden | PASS | Standard indicators only |

## Pipeline-Verlauf

| Phase | Status | Datum |
|-------|--------|-------|
| G0 | PENDING | 2026-05-24 |
