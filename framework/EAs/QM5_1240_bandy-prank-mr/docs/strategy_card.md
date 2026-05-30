---
ea_id: QM5_1240
slug: bandy-prank-mr
type: strategy
source_id: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
sources:
  - "[[sources/bandy-quantitative-technical-analysis]]"
concepts:
  - "[[concepts/percent-rank]]"
  - "[[concepts/short-term-mean-reversion]]"
  - "[[concepts/regime-filter]]"
indicators:
  - "[[indicators/percent-rank]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 32
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
g0_approval_reasoning: "Howard Bandy's quantitative TA material emphasizes objective indicator transforms and testable systems. This card extracts a percent-rank pullback mean-reversion rule with a long-term regime filter; no ML."
---

# QM5_1240 Bandy Percent-Rank Mean Reversion

## Quelle
- Source: [[sources/bandy-quantitative-technical-analysis]]
- Primary reference: Howard Bandy, "Quantitative Technical Analysis".
- Extracted idea: convert recent return into a bounded percentile oscillator, then trade extreme short-term pullbacks inside a broad trend regime.

## Mechanik

D1 mean-reversion system using percent rank of 3-day returns.

### Entry
- Compute `Ret3 = Close / Close[3] - 1`.
- Compute `PRank = PercentRank(Ret3, 100)` where 0 is the weakest 3-day return in the lookback and 100 is the strongest.
- Long setup on D1 close:
  - `Close > SMA(200)`.
  - `PRank <= 10`.
  - `Close > SMA(20) * 0.94` to avoid crash conditions.
  - Enter long at next D1 open.
- Short setup on D1 close, optional `EnableShorts=true`:
  - `Close < SMA(200)`.
  - `PRank >= 90`.
  - `Close < SMA(20) * 1.06`.
  - Enter short at next D1 open.

### Exit
- Long exit at next D1 open when `PRank >= 55` or `Close > SMA(5)`.
- Short exit at next D1 open when `PRank <= 45` or `Close < SMA(5)`.
- Time stop: `MaxHoldBars=8` D1 bars.

### Stop Loss
- Initial stop at `2.5 * ATR(14,D1)`.
- No trailing stop in baseline.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25`.
- One position per symbol/magic; no averaging.

### Zusatzliche Filter
- Minimum history: `260` D1 bars.
- Skip if current D1 true range exceeds `3.0 * MedianTR(100)`.
- Spread filter: skip if spread exceeds `2.0 * MedianSpread(60D, entry hour)`.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Bandy source is explicitly quantitative and mechanical; percent-rank oscillators are directly testable. |
| R2 Mechanical | PASS | Fixed lookbacks, thresholds, exits, and stops. |
| R3 DWX-testbar | PASS | D1 OHLC supports percent rank, SMA, ATR. |
| R4 No ML | PASS | Statistical transform only; no classifier or training. |

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from pending Bandy source.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
