---
ea_id: QM5_12576
slug: eia-wti-season
type: strategy
source_id: EIA-WTI-SEASON-2024
source_citation: "U.S. Energy Information Administration. Gasoline price fluctuations. Energy Explained. URL https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php"
sources:
  - "[[sources/EIA-WTI-SEASON-2024]]"
concepts:
  - "[[concepts/wti-seasonality]]"
  - "[[concepts/calendar-trend-filter]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/rate-of-change]]"
  - "[[indicators/atr]]"
target_symbols: [XTIUSD.DWX]
period: D1
expected_trade_frequency: "Monthly seasonal rebalance on XTIUSD.DWX with active windows in 6 calendar months and SMA/ROC price confirmation; estimate 3-6 trades/year."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS official EIA petroleum seasonality sources; R2 PASS deterministic monthly WTI calendar/SMA/ROC/ATR rules; R3 PASS XTIUSD.DWX is in the DWX symbol matrix; R4 PASS no ML/grid/martingale and one magic position."
expected_pf: 1.2
expected_dd_pct: 18.0
---

# EIA WTI Seasonal Demand Trend

## Source

- Source: [[sources/EIA-WTI-SEASON-2024]]
- Primary citation: U.S. Energy Information Administration, "Gasoline price fluctuations", Energy Explained, URL https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php.
- Supplement: U.S. Energy Information Administration, "Use of heating oil", Energy Explained, URL https://www.eia.gov/energyexplained/heating-oil/use-of-heating-oil.php.
- Supplement: U.S. Energy Information Administration, "Diesel fuel explained: factors affecting diesel prices", Energy Explained, URL https://www.eia.gov/energyexplained/diesel-fuel/factors-affecting-diesel-prices.php.

## Concept

Crude oil is not only a chart trend series; its refined-product demand has recurring calendar structure. The spring-to-late-summer driving season creates a gasoline demand/price window, while winter distillate/heating demand adds a smaller cold-season petroleum support window. This card converts that structural lineage into a low-frequency XTIUSD.DWX sleeve: trade only at monthly D1 rebalances, require price confirmation, and stay flat in shoulder months.

This is deliberately different from `QM5_12567_cum-rsi2-commodity`, which is a short-horizon cumulative RSI pullback port, and from the existing XNG EIA sleeve, which targets natural-gas heating/power seasonality rather than WTI refined-product seasonality.

## Markets And Timeframe

- Target symbol: XTIUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no EIA feed, inventory feed, futures curve, refinery feed, or external API.

## Entry Rules

- Evaluate only on the first new D1 bar of a calendar month.
- Long season months: May, June, July, August, December, January.
- Short season months: September and October.
- Neutral months: February, March, April, November.
- Compute the prior closed D1 close, SMA(84), and 21-bar close-to-close rate of change on XTIUSD.DWX.
- Entry Long: if the new month is a long season month, prior D1 close is above SMA(84), and 21-bar ROC is positive, BUY XTIUSD.DWX at market.
- Entry Short: if the new month is a short season month, prior D1 close is below SMA(84), and 21-bar ROC is negative, SELL XTIUSD.DWX at market.
- No entry in neutral months.
- No entry if an open position already exists for the EA magic.

## Exit Rules

- Stop loss: fixed hard SL at ATR(20) * 3.5 from entry.
- Exit Long if the active month is no longer long-season eligible.
- Exit Short if the active month is no longer short-season eligible.
- Exit Long if the prior D1 close falls below SMA(84).
- Exit Short if the prior D1 close rises above SMA(84).
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XTIUSD.DWX on D1.
- Skip entries when current spread exceeds 1000 points.
- Skip entries when SMA(84), ROC(21), or ATR(20) is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1; the card uses the hard ATR stop and daily/monthly close rules.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_trend_period
  default: 84
  sweep_range: [63, 84, 126, 168]
- name: strategy_momentum_period
  default: 21
  sweep_range: [10, 21, 42]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.5
  sweep_range: [2.5, 3.5, 4.5, 5.5]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from the EIA sources. The sources are used only for official structural seasonality lineage.

## Initial Risk Profile

- expected_pf: 1.20
- expected_dd_pct: 18
- expected_trade_frequency: approximately 4 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA petroleum product seasonality and inventory-cycle URLs.
- [x] R2 mechanical: fixed calendar windows, SMA/ROC confirmation, ATR stop, and deterministic exits.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] No duplicate of QM5_12567: this is not RSI pullback logic.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, spread cap.
- trade_entry: monthly seasonal direction plus SMA(84) and ROC(21) confirmation.
- trade_management: none beyond the entry stop.
- trade_close: season-window end or SMA confirmation failure.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-26 | initial structural WTI sleeve build | G0 | DRAFT |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | DRAFT | this card |
