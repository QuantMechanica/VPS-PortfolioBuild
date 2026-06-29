---
ea_id: QM5_12809
slug: eia-jetfuel-brk
type: strategy
source_id: EIA-JETFUEL-SEASON-2026
source_citation: "U.S. Energy Information Administration, Jet fuel made up a record share of U.S. refinery output in 2024, Today in Energy, March 24, 2025, https://www.eia.gov/todayinenergy/detail.php?id=64786; U.S. jet fuel consumption growth slows after air travel recovers from pandemic slowdown, Today in Energy, August 26, 2025, https://www.eia.gov/todayinenergy/detail.php?id=66004; U.S. jet fuel production rises after prices doubled in March, Today in Energy, June 8, 2026, https://www.eia.gov/todayinenergy/detail.php?id=67764"
sources:
  - "[[sources/EIA-JETFUEL-SEASON-2026]]"
concepts:
  - "[[concepts/jet-fuel-refinery-yield]]"
  - "[[concepts/summer-air-travel-demand]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, structural-demand, channel-breakout, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12809_XTI_JETFUEL_BRK_D1
period: D1
expected_trade_frequency: "Summer-window D1 WTI breakout sleeve; estimate 5-12 trades/year after trend, spread, and date filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
expected_pf: 1.12
expected_dd_pct: 18.0
g0_approval_reasoning: "R1 PASS official EIA jet-fuel refinery-output, consumption, and production sources; R2 PASS deterministic D1 summer-window breakout with SMA trend gate, ATR stop, channel/date/time exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# WTI Jet Fuel Summer Breakout

## Source

- Source: [[sources/EIA-JETFUEL-SEASON-2026]]
- Primary citation: U.S. Energy Information Administration, "Jet fuel made up a
  record share of U.S. refinery output in 2024", Today in Energy, March 24,
  2025, https://www.eia.gov/todayinenergy/detail.php?id=64786.
- Demand context: U.S. Energy Information Administration, "U.S. jet fuel
  consumption growth slows after air travel recovers from pandemic slowdown",
  Today in Energy, August 26, 2025,
  https://www.eia.gov/todayinenergy/detail.php?id=66004.
- Current refinery-margin context: U.S. Energy Information Administration,
  "U.S. jet fuel production rises after prices doubled in March", Today in
  Energy, June 8, 2026,
  https://www.eia.gov/todayinenergy/detail.php?id=67764.

## Hypothesis

EIA analysis documents jet fuel as a material refinery-yield and air-travel
demand channel, with recent EIA work also showing refiners shifting output when
jet fuel prices and crack spreads become attractive. The QM expression is not
to forecast jet fuel data directly. It asks whether summer air-travel demand
creates a recurring low-frequency WTI continuation impulse that is visible in
`XTIUSD.DWX` price during the May 15 through August 31 window.

The mechanical expression is long-only: buy D1 upside breakouts during the jet
fuel summer window only when crude is already above its 100-day D1 trend SMA.
Exit when the seasonal window ends, trend breaks, the short Donchian exit low
breaks, or a time stop is reached.

This is deliberately different from existing gasoline, distillate, WPSR,
refinery-maintenance, hurricane, OPEC, roll, weekday, month-premium, 52-week
anchor, long-horizon momentum, oil-ratio, XNG, XAU/XAG, and commodity-RSI
sleeves already in the registry.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 5-12 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, broker calendar, broker spread, ATR, and
  SMA only. No futures curve, EIA feed, refinery feed, airline feed, inventory
  feed, CSV, API, analyst forecast, or ML model.

## Rules

Entry rules:

- Evaluate only on a new D1 bar.
- Host chart must be `XTIUSD.DWX` on D1 and magic slot 0.
- Prior completed D1 bar date must be within May 15 through August 31.
- Prior completed D1 close must be above SMA(`strategy_trend_period`).
- Prior completed D1 close must break above the highest high of the prior
  `strategy_entry_channel` completed D1 bars, excluding the signal bar.
- Entry direction is long only: BUY `XTIUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

Exit rules:

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close if the prior completed D1 date leaves the May 15 through August 31
  window.
- Close if the prior completed D1 close falls below the trend SMA.
- Close if the prior completed D1 close breaks below the lowest low of the
  prior `strategy_exit_channel` completed D1 bars.
- Also close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Risk

- expected_pf: 1.12.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 5-12 trades/year.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA energy analysis with dated public URLs.
- [x] R2 mechanical: fixed summer window, D1 breakout, SMA trend gate, ATR stop,
  and deterministic channel/date/time exits.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: jet-fuel summer demand breakout is not existing gasoline,
  distillate, WPSR, refinery-maintenance, hurricane, OPEC, roll, weekday,
  month, ratio, XNG, XAU/XAG, RSI, or long-horizon momentum logic.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial structural WTI jet-fuel summer breakout card | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-30 | APPROVED | this card |
