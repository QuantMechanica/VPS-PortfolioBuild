# QM5_1219 Carver EWMAC Acceleration

## Scope

- Strategy Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1219_carver-accel.md`
- EA: `framework/EAs/QM5_1219_carver-accel/QM5_1219_carver-accel.mq5`
- Framework: QuantMechanica V5
- Build phase only: no backtests or pipeline phases executed.

## Card Mapping

### No-Trade

- Framework defaults handle kill switch, news, Friday close, and session gating.
- EA adds card-specific guards:
  - D1 only.
  - Current symbol must be one of the approved DWX universe members.
  - Active chart must use the registered `qm_magic_slot_offset` for that symbol.
  - Minimum parameter sanity checks.
  - Optional spread cap, implemented as current spread less than `strategy_spread_mult * Strategy_MedianSpreadPoints(20D proxy)`.

### Entry

- Uses closed D1 bar only.
- `Lslow = 4 * Lfast`.
- EWMAC is `(EMA(Close, Lfast) - EMA(Close, Lslow)) / StdDev(Close changes, 25)`.
- Acceleration is `ewmac_t - ewmac_(t-Lfast)`.
- Forecast is `strategy_forecast_scalar * raw_accel`, capped to `[-strategy_forecast_cap, +strategy_forecast_cap]`.
- Long when forecast exceeds `strategy_entry_forecast`.
- Short when forecast is below `-strategy_entry_forecast`.
- One position per symbol/magic.
- No same-bar re-entry after a strategy exit.

### Trade Management

- No trailing or partial management added.
- Emergency stop is set at entry using `strategy_stop_atr_mult * ATR(20, D1)`.

### Exit

- Long exits when forecast falls below `0`.
- Short exits when forecast rises above `0`.
- Exit is evaluated on closed D1 bars.

## Inputs

- Baseline variant: `strategy_fast_period=32`, implied slow period `128`, `strategy_entry_forecast=2.0`, `strategy_stop_atr_mult=2.5`.
- P3 sweep variants represented in set files:
  - `fast16_slow64`
  - `fast32_slow128`
  - `fast64_slow256`
  - `atr20`, `atr25`, `atr30`

## Magic Registry

| Slot | Symbol |
| ---: | --- |
| 0 | EURUSD.DWX |
| 1 | GBPUSD.DWX |
| 2 | USDJPY.DWX |
| 3 | GER40.DWX |
| 4 | NDX.DWX |
| 5 | WS30.DWX |
| 6 | XAUUSD.DWX |
| 7 | XTIUSD.DWX |

Magic formula: `1219 * 10000 + symbol_slot`.

## Live Caveats

- The approved card states no T6 caveat for this universe.
- Symbols remain `.DWX` in build artifacts; deploy packaging owns any live suffix stripping.
- `XTIUSD.DWX` is enabled by default but can be disabled with `strategy_allow_xtiusd=false`.
