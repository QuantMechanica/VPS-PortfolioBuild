---
ea_id: QM5_1241
slug: mql5-macd-signal
type: strategy
source_id: 3b3ec48a-0755-5187-9331-afb36e174175
sources:
  - "[[sources/github-mql5-stars20]]"
concepts:
  - "[[concepts/macd-cross]]"
  - "[[concepts/trend-filter]]"
  - "[[concepts/atr-risk]]"
indicators:
  - "[[indicators/macd]]"
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 40
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
g0_approval_reasoning: "High-star MQL5 repositories commonly include MACD Expert Advisor examples. This card uses a deterministic MACD main/signal cross with EMA trend filter and ATR stop; no ML."
---

# QM5_1241 MQL5 MACD Signal Cross

## Quelle
- Source: [[sources/github-mql5-stars20]]
- Primary URL: hxxps://github.com/search?q=language%3AMQL5+stars%3A%3E20&type=repositories
- Extracted idea: common MQL5 MACD Expert Advisor pattern using MACD signal crosses and bar-close execution.

## Mechanik

H1 MACD trend continuation strategy.

### Entry
- Compute MACD with `FastEMA=12`, `SlowEMA=26`, `SignalSMA=9`.
- Long setup on H1 close:
  - MACD main crosses above MACD signal.
  - MACD main is below `0.0025 * Close` to avoid very late entries.
  - `Close > EMA(200)`.
  - Enter long at next H1 open.
- Short setup on H1 close:
  - MACD main crosses below MACD signal.
  - MACD main is above `-0.0025 * Close`.
  - `Close < EMA(200)`.
  - Enter short at next H1 open.

### Exit
- Long exit when MACD main crosses below signal or `Close < EMA(50)`.
- Short exit when MACD main crosses above signal or `Close > EMA(50)`.
- Time stop: `MaxHoldBars=96` H1 bars.

### Stop Loss
- Initial stop at `2.0 * ATR(14,H1)`.
- Take profit at `2.0R`.
- Move stop to breakeven after `+1.0R`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25`.
- One position per symbol/magic.

### Zusatzliche Filter
- Minimum history: `260` H1 bars.
- Do not enter when `ATR(14) < MedianATR(240) * 0.45`.
- Spread filter: skip if spread exceeds `2.0 * MedianSpread(20D, entry hour)`.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Source points to high-star public MQL5 repositories; MACD EA examples are a common deterministic implementation class. |
| R2 Mechanical | PASS | Fixed MACD, EMA, ATR, and time-stop rules. |
| R3 DWX-testbar | PASS | H1 OHLC supports all indicators. |
| R4 No ML | PASS | No learned model or external ML library. |

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from pending GitHub MQL5 source.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
