---
ea_id: QM5_1244
slug: mql5-ma-trail
type: strategy
source_id: a120af9a-fb72-526c-bb80-d1d098a617b5
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 36
universe:
  - EURUSD
  - GBPUSD
  - USDJPY
  - AUDUSD
  - USDCAD
  - NZDUSD
  - XAUUSD
  - XTIUSD
  - NDX
  - WS30
  - GDAXI
  - UK100
period: H1
g0_approval_reasoning: "MQL5 Articles examples include concrete Expert Advisor patterns with moving-average signals and trailing stops. This card turns that into deterministic H1 close-cross rules with ATR safety stop; no ML."
---

# QM5_1244 MQL5 Moving Average Trail

## Quelle

- Source: `sources/mql5-articles-examples`
- Primary URL: `mql5.com/en/articles/cat/2`
- Extracted idea: MQL5 EA example category using indicator signal modules and trailing-stop management.

## Mechanik

H1 moving-average signal with close-based trailing stop.

### Entry

- Long setup on H1 close:
  - `Close[1] <= SMA(50)[1]`.
  - `Close > SMA(50)`.
  - `SMA(50) > SMA(200)`.
  - Enter long at next H1 open.
- Short setup on H1 close:
  - `Close[1] >= SMA(50)[1]`.
  - `Close < SMA(50)`.
  - `SMA(50) < SMA(200)`.
  - Enter short at next H1 open.

### Exit

- Long exit if H1 closes below `SMA(50)` after entry.
- Short exit if H1 closes above `SMA(50)` after entry.
- Time stop: `MaxHoldBars=96` H1 bars.

### Stop Loss

- Initial stop at `2.0 * ATR(14,H1)`.
- Trailing stop:
  - Long: after `+1.0R`, set stop to `max(current_stop, SMA(50) - 0.5 * ATR(14))`.
  - Short: after `+1.0R`, set stop to `min(current_stop, SMA(50) + 0.5 * ATR(14))`.
- Take profit at `2.5R`.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25`.
- One position per symbol/magic.

### Zusatzliche Filter

- Minimum history: `260` H1 bars.
- Skip when `Abs(SMA(50)-SMA(200)) < 0.3 * ATR(14)`.
- Spread filter: skip if spread exceeds `2.0 * MedianSpread(20D, entry hour)`.

## R1-R4 Bewertung

| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Source-Link | PASS | MQL5 Articles examples are concrete EA implementation sources. |
| R2 Mechanical | PASS | Fixed SMA cross, trend filter, ATR stop, and trailing rule. |
| R3 DWX-testbar | PASS | H1 OHLC supports SMA/ATR and execution logic. |
| R4 No ML | PASS | No ML or optimisation dependency. |

## Pipeline-Verlauf

- G0: 2026-05-18 - drafted from pending MQL5 Articles source.
