---
ea_id: QM5_1238
slug: tv-vwap-rsi-cont
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/vwap-continuation]]"
  - "[[concepts/rsi-filter]]"
  - "[[concepts/intraday-pullback]]"
indicators:
  - "[[indicators/session-vwap]]"
  - "[[indicators/rsi]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 85
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
period: M15
g0_approval_reasoning: "TradingView popular strategy pages include VWAP/RSI confirmation systems. This card defines a deterministic M15 VWAP pullback-continuation rule with ATR stop and fixed session constraints; no ML."
---

# QM5_1238 TradingView VWAP RSI Continuation

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Primary URL: https://www.tradingview.com/scripts/?sort=popular
- Extracted idea: popular VWAP + RSI confirmation strategies that require price to hold relative to session VWAP and momentum to confirm continuation.

## Mechanik

M15 intraday continuation. Trade pullbacks to session VWAP in the direction of the session bias.

### Entry
- Compute session VWAP from broker-day open; reset daily.
- Long setup on M15 close:
  - `Close > SessionVWAP`.
  - Previous bar low touched or crossed below `SessionVWAP + 0.15 * ATR(14,M15)`.
  - Current close is bullish: `Close > Open`.
  - `RSI(14) between 50 and 70`.
  - Enter long at next M15 open.
- Short setup on M15 close:
  - `Close < SessionVWAP`.
  - Previous bar high touched or crossed above `SessionVWAP - 0.15 * ATR(14,M15)`.
  - Current close is bearish: `Close < Open`.
  - `RSI(14) between 30 and 50`.
  - Enter short at next M15 open.

### Exit
- Take profit at `1.5R`.
- Exit long if M15 closes below SessionVWAP.
- Exit short if M15 closes above SessionVWAP.
- Time stop: close after `MaxHoldBars=16` M15 bars or before Friday close.

### Stop Loss
- Initial stop at `1.2 * ATR(14,M15)` from entry.
- Move stop to breakeven after `+1.0R`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25`.
- One active position per symbol/magic per session.

### Zusatzliche Filter
- Trade only 07:00-17:00 London time.
- Minimum session range before entry: `SessionHigh - SessionLow >= 0.6 * ATR(14,H1)`.
- Spread filter: skip if spread exceeds `2.0 * MedianSpread(20D, entry hour)`.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Source is TradingView popular script catalog; VWAP/RSI strategy family is public and mechanical. |
| R2 Mechanical | PASS | VWAP, RSI thresholds, ATR stop and fixed exits. |
| R3 DWX-testbar | PASS | M15 OHLC and derived VWAP/RSI/ATR are available. |
| R4 No ML | PASS | Rule-based indicator strategy. |

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from pending TradingView popular scripts source.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
