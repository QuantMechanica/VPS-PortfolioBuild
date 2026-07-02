---
ea_id: QM5_9507
slug: carver-breakout
type: strategy
source_id: 1a059d6d-84fa-5d0c-94c5-86dd0481637c
sources:
  - "[[sources/carver-leveraged-trading]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; Carver 'Leveraged Trading' (Harriman House 2019) chapter 8 with official breakout spreadsheet and blog supplement provide adequate lineage."
r2_mechanical: PASS
r2_reasoning: "Donchian(80) breakout entry, Donchian(40) trail exit, ATR(25) hard stop and volatility filter are all deterministic on completed D1 bars."
r3_data_available: PASS
r3_reasoning: "D1 OHLC strategy testable on DWX FX pairs, XAUUSD, NDX.DWX, GDAXI.DWX, and UK100.DWX."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed Donchian and ATR lookbacks throughout; 1-position-per-magic; no ML, adaptive PnL parameters, grid, or martingale."
pipeline_phase: G0
last_updated: 2026-05-19
expected_trades_per_year_per_symbol: 18
strategy_type_flags:
  - donchian-breakout
  - donchian-trail
  - atr-hard-stop
  - symmetric-long-short
universe:
  - EURUSD
  - GBPUSD
  - USDJPY
  - AUDUSD
  - XAUUSD
  - NDX
  - GDAXI
  - UK100
period: D1
card_body_incomplete: true
card_body_missing: "source_citation,target_symbols"
g0_approval_reasoning: "R1 PASS Carver 2019 Harriman/resources linked; R2 PASS deterministic Donchian entry/exit with stops and 18 trades/year/symbol; R3 PASS D1 DWX OHLC/spread symbols testable; R4 PASS fixed rules no ML/grid/martingale."
---

# QM5_9507 Carver Breakout Forecast

## Quelle
- Source: [[sources/carver-leveraged-trading]]
- Primary reference: Robert Carver, "Leveraged Trading", Harriman House, 2019, chapter 8 breakout rule.
- Companion source: Robert Carver, "Breakout rule calculations" spreadsheet, linked from https://www.systematicmoney.org/leveraged-trading-resources.
- Supplement: https://qoppac.blogspot.com/2017/06/some-more-trading-rules.html

## Mechanik

Daily Donchian-style breakout rule using the book companion's breakout calculation as a standalone trend-following forecast.

Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, XAUUSD.DWX, NDX.DWX, GDAXI.DWX, UK100.DWX.

### Entry
- Compute `HighN = HighestHigh(80,D1)` and `LowN = LowestLow(80,D1)` using completed bars only.
- Long setup: D1 close breaks above prior `HighN`; enter long at next D1 open.
- Short setup: D1 close breaks below prior `LowN`; enter short at next D1 open.
- Optional P3 axis: `BreakoutLookback = 40, 80, 160`.

### Exit
- Long exit when D1 close falls below `LowestLow(40,D1)`.
- Short exit when D1 close rises above `HighestHigh(40,D1)`.
- Signal reversal exits and flips direction only after the existing position is closed.

### Stop Loss
- Initial catastrophic stop: `4.0 * ATR(25,D1)` from entry.
- Trail after `1.5R` unrealised profit using the opposite 40-day Donchian channel.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25`.
- One position per symbol/magic; no pyramiding.

### Zusatzliche Filter
- Minimum history: `2 * BreakoutLookback + 25` D1 bars.
- Entry allowed only if `ATR(25) >= MedianATR(252) * 0.40`.
- Spread filter: skip if spread exceeds `2.0 * MedianSpread(60D, entry hour)`.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Official Carver resource page links a breakout calculation sheet for Leveraged Trading. |
| R2 Mechanical | PASS | Prior-channel breakout entry, channel exit, and ATR hard stop are deterministic. |
| R3 DWX-testbar | PASS | Requires only D1 OHLC and spread data. |
| R4 No ML | PASS | Fixed lookbacks and fixed risk controls; no adaptive fitting. |

## Pipeline-Verlauf
- G0: 2026-05-19 - drafted from active Carver Leveraged Trading source.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
