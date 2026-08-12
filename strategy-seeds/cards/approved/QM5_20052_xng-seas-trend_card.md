---
ea_id: QM5_20052
slug: xng-seas-trend
type: strategy
strategy_id: SUENAGA-MOP-XNG-2008-2012_S01
source_id: SUENAGA-XNG-SEASVOL-2008
status: APPROVED
created: 2026-07-23
created_by: Research+Development
last_updated: 2026-07-23
g0_status: APPROVED
source_citation: "Suenaga, Smith and Williams (2008), Journal of Futures Markets 28(5), DOI 10.1002/fut.20317; Moskowitz, Ooi and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: paper
    citation: "Suenaga, H., Smith, A. and Williams, J. C. (2008). Volatility Dynamics of NYMEX Natural Gas Futures Prices."
    location: "pp. 438-463; DOI https://doi.org/10.1002/fut.20317"
    quality_tier: A
    role: primary
  - type: paper
    citation: "Moskowitz, T. J., Ooi, Y. H. and Pedersen, L. H. (2012). Time Series Momentum."
    location: "Journal of Financial Economics 104(2), 228-250; DOI https://doi.org/10.1016/j.jfineco.2011.11.003"
    quality_tier: A
    role: mechanic
strategy_type_flags: [time-series-momentum, seasonal-regime-gate, atr-hard-stop, symmetric-long-short]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly entries only in May-September, November-January; no more than eight packages/year."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.0
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Falsify whether slow XNG trend is useful specifically inside the source-backed physical volatility seasons."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal]
hard_rules_at_risk: [enhancement_doctrine, cfd_futures_basis]
g0_approval_reasoning: "OWNER commodity-sleeve mission: two peer-reviewed sources; fixed calendar gate plus closed-bar 126-D1 log-return sign; registered XNG D1 data; no ML, external feed, grid, martingale, or pyramiding."
---

# QM5_20052 XNG Seasonal-Window Trend

## Hypothesis

Natural-gas storage and demand constraints concentrate volatility in early May through September and early November through mid-January. A slow own-price trend sign supplies direction only inside those windows, producing exposure distinct from the incumbent short-horizon cumulative-RSI2 reversion sleeve.

## Source Traceability

Suenaga, Smith and Williams establish seasonal natural-gas volatility, not directional returns. Moskowitz, Ooi and Pedersen supply the mechanical own-past-return trend rule. This card tests their interaction on the continuous Darwinex CFD and imports no source performance claim.

## Rules

The fixed entry, exit, risk, and no-trade rules below are the complete authorized mechanic.

## Entry Rules

On the first D1 bar of a broker month, trade only when the month is May-September or November-January. Compute `ln(Close[1] / Close[127])`. Buy above +2%; sell below -2%; otherwise remain flat. Use one position and magic slot 0.

## Exit Rules

Close at the next monthly rebalance, after 31 calendar days, or immediately outside the eligible months. Initial hard stop is 3.5 times D1 ATR(20). No profit target or pyramiding.

## Filters (No-Trade Module)

Require `XNGUSD.DWX`, D1, valid closed history and ATR, spread no greater than 1000 points, and the framework kill/news/Friday controls. The EA uses only MT5-native OHLC and broker calendar data.

## Trade Management Rules

Positions are not resized or trailed. The management hook enforces monthly, stale-position, and season-end exits.

## Parameters To Test

Q02 is locked to 126 D1 bars, 2% absolute return threshold, ATR(20), 3.5 ATR stop, 31-day maximum hold, and `RISK_FIXED=1000` with `RISK_PERCENT=0`.

## Non-Duplicate Boundary

- Not `QM5_12567`: no RSI, cumulative oversold/overbought state, or short pullback.
- Not `QM5_13110`: no previous-day-range breakout or weekly H4 trigger.
- Not unconditional XNG momentum: the two source volatility seasons are a binding entry and exit gate.
- Not XTI/XNG relative value: this is one-instrument absolute trend exposure.

## Initial Risk Profile

High. The seasonal-volatility paper does not establish directional trend profits, and the CFD is not a maturity-specific futures panel. Q02 must reject low density, poor payoff, or excessive drawdown.

## Strategy Allowability Check

- Structural, low-frequency, fixed-rule and closed-bar only.
- No banned/ML indicator, external runtime feed, grid, martingale, or discretionary input.
- Backtest risk is `RISK_FIXED`; no live setfile or deploy artifact exists.

## Framework Alignment

`Strategy_NoTradeFilter` validates symbol/timeframe/inputs; `Strategy_EntrySignal` implements the calendar and trend gate; `Strategy_ManageOpenPosition` enforces exits; `Strategy_ExitSignal` delegates to management and hard-stop handling.

## Risk

Research/backtest only. No T_Live, AutoTrading, deploy manifest, or portfolio-gate authorization.
