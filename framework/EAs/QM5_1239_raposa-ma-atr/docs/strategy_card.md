---
ea_id: QM5_1239
slug: raposa-ma-atr
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-trade-python-backtesting]]"
concepts:
  - "[[concepts/moving-average-crossover]]"
  - "[[concepts/atr-stop]]"
  - "[[concepts/systematic-backtest]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 28
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
g0_approval_reasoning: "Raposa Trade backtesting tutorials are mechanical Python strategy examples. This card extracts a conservative EMA crossover with ATR stop and bar-close execution; no ML or optimisation dependency."
---

# QM5_1239 Raposa EMA Crossover ATR

## Quelle
- Source: [[sources/raposa-trade-python-backtesting]]
- Primary URL: hxxps://raposa.trade/blog/
- Extracted idea: Python backtesting tutorial pattern using indicator signals, bar-close rules, and explicit risk controls.

## Mechanik

H1 moving-average crossover system with volatility-normalised risk.

### Entry
- Long setup on H1 close:
  - `EMA(20)` crosses above `EMA(80)`.
  - `Close > EMA(200)`.
  - `ATR(14) > MedianATR(240) * 0.50`.
  - Enter long at next H1 open.
- Short setup on H1 close:
  - `EMA(20)` crosses below `EMA(80)`.
  - `Close < EMA(200)`.
  - `ATR(14) > MedianATR(240) * 0.50`.
  - Enter short at next H1 open.

### Exit
- Long exit when `EMA(20)` crosses below `EMA(80)`.
- Short exit when `EMA(20)` crosses above `EMA(80)`.
- Take profit: `2.0R`.
- Time stop: `MaxHoldBars=120` H1 bars.

### Stop Loss
- Initial stop at `2.0 * ATR(14,H1)`.
- Trail by `2.5 * ATR(14,H1)` after profit exceeds `1.5R`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25`.
- One position per symbol/magic.

### Zusatzliche Filter
- Minimum history: `260` H1 bars.
- Do not reverse on the same bar; exit first, wait one full H1 bar before opposite entry.
- Spread filter: skip if spread exceeds `2.0 * MedianSpread(20D, entry hour)`.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Raposa Trade source is a mechanical backtesting/tutorial archive; MA crossover is directly backtestable. |
| R2 Mechanical | PASS | Fixed EMA, ATR, TP, stop, and time rules. |
| R3 DWX-testbar | PASS | H1 OHLC supports all indicators. |
| R4 No ML | PASS | No ML libraries or learned model. |

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from pending Raposa Trade source.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*

