---
ea_id: QM5_9506
slug: carver-starter
type: strategy
source_id: 1a059d6d-84fa-5d0c-94c5-86dd0481637c
sources:
  - "[[sources/carver-leveraged-trading]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/volatility-targeting]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/realized-volatility]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; Carver 'Leveraged Trading' (Harriman House 2019, ISBN 9780857197214) with publisher URL and official companion spreadsheet provide adequate lineage."
r2_mechanical: PASS
r2_reasoning: "SMA(16)/SMA(64) crossover entry, signal-reversal exit, and ATR-based stop distance are fully deterministic on D1 closed bars."
r3_data_available: PASS
r3_reasoning: "D1 OHLC strategy testable on DWX FX pairs (EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD), XAUUSD, NDX.DWX, and WS30.DWX."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed SMA periods (16, 64) and ATR(25) lookback; stop size adapts to price history not PnL; 1-position-per-magic; no ML, grid, or martingale."
pipeline_phase: G0
last_updated: 2026-05-19
expected_trades_per_year_per_symbol: 12
strategy_type_flags:
  - trend-filter-ma
  - signal-reversal-exit
  - atr-hard-stop
  - symmetric-long-short
universe:
  - EURUSD
  - GBPUSD
  - USDJPY
  - AUDUSD
  - USDCAD
  - XAUUSD
  - NDX
  - WS30
period: D1
card_body_incomplete: true
card_body_missing: "target_symbols"
g0_approval_reasoning: "R1 PASS book/ISBN/resource links; R2 PASS deterministic SMA entry/exit with stops and 12 trades/year/symbol; R3 PASS D1 DWX FX/metals/indices testable; R4 PASS no ML/grid/martingale."
---

# QM5_9506 Carver Starter SMA

## Quelle
- Source: [[sources/carver-leveraged-trading]]
- Primary reference: Robert Carver, "Leveraged Trading", Harriman House, 2019, ISBN 9780857197214.
- Companion source: Robert Carver, "Momentum rule calculations" spreadsheet, linked from https://www.systematicmoney.org/leveraged-trading-resources for chapter 6 and chapter 8.
- Public publisher reference: https://harriman-house.com/authors/robert-carver/leveraged-trading/9780857197214/

## Mechanik

Daily starter-system trend follower. This is the binary SMA version rather than the already-approved EWMAC forecast card.

Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, XAUUSD.DWX, NDX.DWX, WS30.DWX.

### Entry
- Compute `FastSMA = SMA(Close,16)` and `SlowSMA = SMA(Close,64)` on D1.
- Long setup: `FastSMA > SlowSMA` and prior bar `FastSMA <= SlowSMA`; enter long at next D1 open.
- Short setup: `FastSMA < SlowSMA` and prior bar `FastSMA >= SlowSMA`; enter short at next D1 open.
- One open position per symbol/magic.

### Exit
- Long exit when `FastSMA < SlowSMA`.
- Short exit when `FastSMA > SlowSMA`.
- Time stop: close after `MaxHoldBars=252` if neither reversal nor stop has fired.

### Stop Loss
- Estimate annualised price risk from D1 returns over `RiskLookback=256`.
- Initial stop distance: `0.50 * AnnualisedStdDevPrice`.
- Minimum stop: `2.0 * ATR(25,D1)`; maximum stop: `8.0 * ATR(25,D1)`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade using the stop distance.
- Live: `RISK_PERCENT = 0.25`.
- No pyramiding; no grid; no portfolio leverage optimiser.

### Zusatzliche Filter
- Minimum history: 300 D1 bars.
- Skip entry if spread is above `2.0 * MedianSpread(60D, entry hour)`.
- Skip entry if `ATR(25) <= 0`.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Book is identified by author, title, publisher page, ISBN, and official companion spreadsheet. |
| R2 Mechanical | PASS | SMA crossover entry and reversal exit are deterministic; stop and sizing are fixed. |
| R3 DWX-testbar | PASS | Uses D1 OHLC and spreads available on DWX FX, metals, and indices. |
| R4 No ML | PASS | No ML, adaptive parameters, grid, martingale, or multi-position logic. |

## Pipeline-Verlauf
- G0: 2026-05-19 - drafted from active Carver Leveraged Trading source.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
