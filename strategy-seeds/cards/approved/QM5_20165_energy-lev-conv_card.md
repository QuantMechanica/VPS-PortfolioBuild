---
ea_id: QM5_20165
slug: energy-lev-conv
type: strategy
strategy_id: KRISTOUFEK-ENERGY-LEV-2014_S03
source_id: KRISTOUFEK-ENERGY-LEV-2014
source_citation: "Kristoufek, L. (2014). Leverage effect in energy futures. Energy Economics 45, 1-9. DOI 10.1016/j.eneco.2014.06.009."
source_citations:
  - type: peer_reviewed_paper
    citation: "Kristoufek, L. (2014). Leverage effect in energy futures. Energy Economics 45, 1-9."
    location: "Complete paper; Tables 4-5 and conclusion."
    quality_tier: A
    role: primary
sources: ["[[sources/KRISTOUFEK-ENERGY-LEV-2014]]"]
concepts: ["[[concepts/energy-leverage-divergence]]", "[[concepts/market-neutral-convergence]]"]
indicators: ["[[indicators/log-return-zscore]]", "[[indicators/atr]]"]
strategy_type_flags: [market-neutral-basket, structural-shock, convergence, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
markets: [XTIUSD.DWX, XNGUSD.DWX]
timeframes: [D1]
logical_symbol: QM5_20165_ENERGY_LEV_CONV_D1
single_symbol_only: false
period: D1
expected_trade_frequency: "Joint WTI-down/XNG-up D1 leverage-divergence convergence; estimate 5-12 paired packages/year before Q02."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-26
expected_pf: 1.10
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual]
review_focus: "Event-conditioned market-neutral energy convergence, a different driver from the index/metal book and QM5_12567 RSI pullback."
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-26: R1 PASS peer-reviewed Energy Economics source fully read in the governed source packet; R2 PASS deterministic joint-sign one-day standardized shock, paired convergence entry, mean/time exits and ATR stops; R3 PASS XTIUSD.DWX/XNGUSD.DWX; R4 PASS no ML/grid/martingale/external runtime data."
---

# Energy Leverage-Divergence Convergence

## Source And Hypothesis

Kristoufek (2014) documents a conventional leverage effect for WTI (negative
returns associated with higher volatility) and the opposite sign for natural
gas (positive returns associated with higher volatility). The paper does not
claim cross-market convergence. QM tests the transparent structural
hypothesis that an unusually large same-day WTI-down/XNG-up divergence is a
temporary energy relative-value shock.

The complete bounded extraction is
`strategy-seeds/sources/KRISTOUFEK-ENERGY-LEV-2014/source.md`. No source
performance number is imported.

## Markets And Frequency

- Logical basket: `QM5_20165_ENERGY_LEV_CONV_D1`.
- Host: `XTIUSD.DWX` D1; second traded leg: `XNGUSD.DWX`.
- Expected frequency: 5-12 paired packages/year; Q02 must retire it if the
  realized rate is below five packages/year.
- Backtest only with `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Entry Rules

On each completed D1 bar:

1. Calculate one-day log returns for XTI and XNG.
2. Calculate `shock = xti_return - beta * xng_return`.
3. Standardize shock over the prior 120 completed D1 observations.
4. Enter only if XTI return is negative, XNG return is positive, and shock
   z-score is below `-2.0`.
5. Buy XTI and sell XNG as one equal-risk package. Reject the complete package
   if either spread cap, history, ATR, sizing, news, or framework guard fails.

## Exit And Risk Rules

- Close both legs when `abs(shock_z) < 0.3`.
- Close both legs after ten calendar days or on framework Friday close.
- Close an orphan leg immediately.
- Each leg has a frozen `3.0 * ATR(20)` D1 hard stop.
- One package only; no pyramiding, grid, martingale, partial close, trailing
  stop, external feed, futures curve, or ML.

## Parameters To Test

- `strategy_return_lookback_d1`: locked `1`.
- `strategy_z_lookback_d1`: default `120`, declared range `[80, 120, 160]`.
- `strategy_beta`: default `1.0`, declared range `[0.75, 1.0, 1.25]`.
- `strategy_entry_z`: default `2.0`, declared range `[1.75, 2.0, 2.25]`.
- `strategy_exit_z`: default `0.3`, declared range `[0.2, 0.3, 0.5]`.
- `strategy_atr_sl_mult`: default `3.0`, declared range `[2.5, 3.0, 4.0]`.
- `strategy_max_hold_days`: default `10`, declared range `[5, 10, 15]`.

## Non-Duplicate Boundary

- `QM5_12840_xti-xng-rspread` trades either sign of a rolling 20-day return
  spread. This card requires a one-day joint WTI-negative/XNG-positive
  leverage event, has one fixed convergence direction, and ignores all
  ordinary spread deviations.
- `QM5_12578_eia-oilgas-ratio` trades an absolute price-ratio level.
- XTI/XNG momentum, carry, seasonal switch, rank and generic volatility
  baskets use different state variables and rebalance logic.
- `QM5_12567_cum-rsi2-commodity` is a single-symbol two-day oscillator
  pullback, not a hedged energy shock package.

## Kill Criteria

Retire if Q02 produces fewer than five complete packages/year, if either leg
cannot be synchronized, if orphan incidence is nonzero after cleanup, if PF is
below 1.0 after costs, or if later portfolio evidence rejects orthogonality.

## Framework Alignment

- no_trade: host/timeframe, parameter, history, spread and framework guards.
- trade_entry: joint-sign standardized D1 shock and paired basket open.
- trade_management: state refresh and orphan cleanup.
- trade_close: mean exit, ten-day maximum hold, Friday close and ATR stops.

## Safety Boundary

This card authorizes build and non-live Q02 only. It does not authorize a live
setfile, T_Live access, AutoTrading, a deploy manifest, portfolio admission, or
portfolio-gate changes.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-26 | initial event-conditioned energy convergence build | Q02 | PENDING |
