---
ea_id: QM5_1243
slug: carver-ewmac-lev
type: strategy
source_id: 1a059d6d-84fa-5d0c-94c5-86dd0481637c
sources:
  - "[[sources/carver-leveraged-trading]]"
concepts:
  - "[[concepts/ewmac-trend]]"
  - "[[concepts/volatility-targeting]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
  - "[[indicators/realized-volatility]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 22
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
g0_approval_reasoning: "Robert Carver's leveraged-trading framework uses mechanical trend forecasts with volatility-aware sizing. This card implements the EWMAC forecast as a single-symbol D1 rule with capped ATR risk; no ML or portfolio optimiser required."
---

# QM5_1243 Carver Leveraged EWMAC

## Quelle
- Source: [[sources/carver-leveraged-trading]]
- Primary reference: Robert Carver, "Leveraged Trading".
- Extracted idea: exponentially weighted moving-average crossover trend forecast, traded with volatility-normalised risk.

## Mechanik

D1 medium-term trend strategy. Enter when EWMAC forecast crosses an actionable threshold.

### Entry
- Compute `FastEMA=16`, `SlowEMA=64`.
- Compute `RawForecast = (FastEMA - SlowEMA) / ATR(25,D1)`.
- Long setup on D1 close:
  - `RawForecast >= 1.0`.
  - Previous bar `RawForecast < 1.0`.
  - `Close > SMA(100)`.
  - Enter long at next D1 open.
- Short setup on D1 close:
  - `RawForecast <= -1.0`.
  - Previous bar `RawForecast > -1.0`.
  - `Close < SMA(100)`.
  - Enter short at next D1 open.

### Exit
- Long exit when `RawForecast <= 0.0` or `Close < SlowEMA`.
- Short exit when `RawForecast >= 0.0` or `Close > SlowEMA`.
- Time stop: `MaxHoldBars=160` D1 bars.

### Stop Loss
- Initial stop at `3.0 * ATR(25,D1)`.
- Trail to `SlowEMA - 1.0 * ATR(25)` for longs and `SlowEMA + 1.0 * ATR(25)` for shorts once profit exceeds `1.5R`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade using ATR stop distance.
- Live: `RISK_PERCENT = 0.25` per symbol.
- One position per symbol/magic; no cross-symbol volatility target or leverage optimiser in baseline.

### Zusatzliche Filter
- Minimum history: `260` D1 bars.
- Skip entry if `ATR(25) < MedianATR(252) * 0.50`.
- Spread filter: skip if spread exceeds `2.0 * MedianSpread(60D, entry hour)`.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Carver source is explicitly systematic and mechanical; EWMAC is a core rule family. |
| R2 Mechanical | PASS | Fixed EMA lengths, forecast thresholds, exits, ATR stop. |
| R3 DWX-testbar | PASS | D1 OHLC supports all required indicators. |
| R4 No ML | PASS | No ML; volatility normalisation is deterministic. |

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from pending Carver Leveraged Trading source.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
