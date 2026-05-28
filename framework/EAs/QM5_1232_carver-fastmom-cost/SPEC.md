# QM5_1232 Carver Cost-Conditioned Fast Momentum

## Scope

- Strategy Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1232_carver-fastmom-cost.md`
- EA: `framework/EAs/QM5_1232_carver-fastmom-cost/QM5_1232_carver-fastmom-cost.mq5`
- Framework: QuantMechanica V5
- Build phase only: no backtests or pipeline phases executed.

## Card Mapping

### No-Trade

- Framework defaults handle kill switch, news, Friday close, and lifecycle controls.
- EA adds card-specific guards:
  - D1 only.
  - Current symbol must be in the approved DWX universe.
  - Active chart must use the registered `qm_magic_slot_offset` for that symbol.
  - Parameter sanity checks.
  - Optional spread cap: current spread must be less than `strategy_spread_mult * Strategy_MedianSpreadPoints(20D proxy)`.

### Entry

- Evaluates only on the newly closed D1 bar.
- Estimates `cost_per_trade_sr = MedianSpreadPoints(20D) * Point / ATR(20,D1)`.
- Computes `max_forecast_turnover = MaxAnnualCostSR / max(cost_per_trade_sr, 0.0001)`.
- Candidate EWMAC variants are `2/8`, `4/16`, `8/32`, `16/64`, `32/128`, and `64/256`.
- Includes only variants whose expected turnover is below the speed limit and whose history is available.
- Equal-weights included forecasts and caps the combined forecast to `[-20,+20]`.
- Long when combined forecast is above `+4`; short when below `-4`.
- One position per symbol/magic, with same-bar re-entry blocked after strategy exits.

### Trade Management

- No trailing or partial management added.
- Emergency stop is placed at entry using `strategy_stop_atr_mult * ATR(20,D1)`.

### Exit

- Long exits when the combined forecast is `<= 0`.
- Short exits when the combined forecast is `>= 0`.
- Exit is evaluated on closed D1 bars.

## Inputs

- Baseline: `strategy_max_annual_cost_sr=0.13`, `strategy_entry_forecast=4.0`, `strategy_forecast_cap=20.0`.
- Variant expected turnovers:
  - `2/8 = 25`
  - `4/16 = 18`
  - `8/32 = 12`
  - `16/64 = 8`
  - `32/128 = 5`
  - `64/256 = 3`
- Stop variants represented in set files: `2.0`, `2.5`, `3.0` ATR.
- Risk: backtest uses `RISK_FIXED=1000`; live uses `RISK_PERCENT=0.5`.

## Magic Registry

| Slot | Symbol |
| ---: | --- |
| 0 | EURUSD.DWX |
| 1 | GBPUSD.DWX |
| 2 | USDJPY.DWX |
| 3 | AUDUSD.DWX |
| 4 | USDCAD.DWX |
| 5 | NZDUSD.DWX |
| 6 | GER40.DWX |
| 7 | UK100.DWX |
| 8 | NDX.DWX |
| 9 | WS30.DWX |
| 10 | XAUUSD.DWX |
| 11 | XTIUSD.DWX |

Magic formula: `1232 * 10000 + symbol_slot`.

## Notes

- MT5 does not expose a portable historical D1 spread series in this framework. The EA uses the same deterministic D1 range proxy used by nearby Carver EAs for median-spread estimation.
- Symbols remain `.DWX` in build artifacts; deploy packaging owns live suffix handling.
