---
ea_id: QM5_1242
slug: connors-double7
type: strategy
source_id: ef14a5d7-e3f1-52be-910a-3ca6b736a152
sources:
  - "[[sources/connors-research-short-term-bulletins]]"
concepts:
  - "[[concepts/short-term-mean-reversion]]"
  - "[[concepts/n-day-low-entry]]"
  - "[[concepts/trend-filter]]"
indicators:
  - "[[indicators/sma200]]"
  - "[[indicators/rolling-high-low]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 24
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
period: D1
g0_approval_reasoning: "Connors Research short-term systems include the published Double Seven mean-reversion pattern. This card makes it symmetric and multi-asset testable with SMA200 regime, 7-day extreme entry/exit, ATR stop; no ML."
---

# QM5_1242 Connors Double Seven

## Quelle
- Source: [[sources/connors-research-short-term-bulletins]]
- Primary URL: store.tradingmarkets.com
- Extracted idea: Connors-style Double Seven rule family: trade pullbacks to 7-day lows in an uptrend and exit on 7-day highs.

## Mechanik

D1 short-term mean-reversion system.

### Entry
- Long setup on D1 close:
  - `Close > SMA(200)`.
  - `Close <= LowestLow(7)`.
  - No open position for this symbol/magic.
  - Enter long at next D1 open.
- Short setup on D1 close, optional `EnableShorts=true`:
  - `Close < SMA(200)`.
  - `Close >= HighestHigh(7)`.
  - No open position for this symbol/magic.
  - Enter short at next D1 open.

### Exit
- Long exit at next D1 open when `Close >= HighestHigh(7)`.
- Short exit at next D1 open when `Close <= LowestLow(7)`.
- Time stop: `MaxHoldBars=12` D1 bars.

### Stop Loss
- Initial stop at `3.0 * ATR(14,D1)`.
- Optional hard stop at `2.0R`; default enabled.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25`.
- One position per symbol/magic; no averaging down.

### Zusatzliche Filter
- Minimum history: `220` D1 bars.
- Skip if D1 range exceeds `3.0 * MedianTR(100)`.
- Spread filter: skip if spread exceeds `2.0 * MedianSpread(60D, entry hour)`.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Connors/TradingMarkets source is a direct short-term strategy bulletin source; Double Seven is a published mechanical family. |
| R2 Mechanical | PASS | Fixed 7-day high/low and SMA200 regime rules. |
| R3 DWX-testbar | PASS | D1 OHLC/SMA/ATR are available. |
| R4 No ML | PASS | No ML or optimiser dependency. |

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from pending Connors Research source.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*

