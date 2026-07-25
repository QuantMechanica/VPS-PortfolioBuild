---
card_schema_version: 2
ea_id: QM5_20161
slug: xauxag-ols-rv
type: strategy
strategy_id: SCHWEIKERT-XAUXAG-OLS-2026_S01
variant_id: SCHWEIKERT-XAUXAG-OLS-2026_S01
source_id: SCHWEIKERT-XAUXAG-RATIO-2026
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20161_xauxag-ols-rv_card.md
execution_contract_status: DRAFT
created: 2026-07-25
created_by: Research+Development
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka"
strategy_mechanic: rolling-ols-log-gold-silver-residual-zscore-reversion-two-leg-basket
source_citation: "Schweikert (2018), Journal of Banking & Finance 88; Yaya, Vo and Olayinka (2021), Resources Policy 72."
sources: ["[[sources/SCHWEIKERT-XAUXAG-RATIO-2026]]"]
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, mean-reversion, low-frequency]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
markets: [commodities, precious_metals]
single_symbol_only: false
logical_symbol: QM5_20161_XAUUSD_XAGUSD_OLS_D1
symbol: QM5_20161_XAUUSD_XAGUSD_OLS_D1
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 5-15 completed packages/year; Q02 must prove or retire density."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 20.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, rolling_hedge_stability, relative_value_neutrality, low_frequency, risk_mode_dual, cfd_basis, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission explicitly authorized a gold/silver ratio-reversion basket. R1 PASS two peer-reviewed publisher records in the durable approved source packet; R2 PASS fixed rolling OLS residual z-score rules; R3 PASS registered XAUUSD.DWX and XAGUSD.DWX D1; R4 PASS native MT5 data only, no ML or banned indicators. This rolling hedge-ratio residual is not the fixed-beta log ratio in QM5_20157."
---

# QM5_20161 XAU/XAG Rolling-OLS Residual Reversion

## Hypothesis and source traceability

Gold and silver have a source-supported but time-varying long-run relationship.
The governed packet `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`
records two peer-reviewed sources. Schweikert (2018) specifically warns that a
constant cointegrating vector can fail; this variant therefore estimates the
hedge ratio on a rolling window and trades the standardized regression residual.
The lookback, thresholds, stops, and CFD mapping are transparent QM hypotheses.

## Non-duplicate decision

`QM5_20157_xau-xag-ratio` fixes beta at 1.0 and standardizes the raw log ratio.
This card estimates `log(XAU) = alpha + beta*log(XAG) + residual` on every
completed D1 bar, bounds beta before use, and sizes the XAG risk leg by the
frozen entry beta. It is a distinct adaptive-hedge relative-value exposure.

## Entry

1. Host one logical D1 basket on `XAUUSD.DWX`; trade both registered legs.
2. From 120 completed observations, estimate OLS alpha and beta of log XAU on
   log XAG. Fail closed if variance is zero or beta is outside `[0.25, 2.50]`.
3. Compute residuals using that alpha/beta, then the latest residual z-score
   using sample standard deviation.
4. At `z > 2.25`, sell XAU and buy XAG; at `z < -2.25`, buy XAU and sell XAG.
5. Freeze the entry beta for sizing. Split `RISK_FIXED` between XAU weight 1
   and XAG weight `abs(beta)`. Give each leg a `2.5*ATR(20,D1)` hard stop.
6. No entry with either leg open. If only one order succeeds, close the orphan.

## Exit and management

- Close both legs when `abs(z) < 0.50`, after 60 calendar days, or when the
  rolling beta leaves `[0.25,2.50]`.
- Close an orphan leg immediately.
- Framework Friday close and kill switch remain authoritative.
- No TP, trailing, break-even, partial close, scale-in, grid, martingale, ML,
  external feed, or discretionary rule is authorized.

## Parameters to test

- `strategy_ols_lookback_d1=120`
- `strategy_entry_z=2.25`
- `strategy_exit_z=0.50`
- `strategy_beta_min=0.25`
- `strategy_beta_max=2.50`
- `strategy_atr_period_d1=20`
- `strategy_atr_sl_mult=2.50`
- `strategy_max_hold_days=60`
- `strategy_deviation_points=20`

## Risk, acceptance, and framework alignment

Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Q02 must show at least five completed two-leg packages
per year after warm-up. Zero/orphan execution is an implementation defect;
below-frequency is RETIRE. Later gates alone decide costs, robustness, and book
correlation. No-trade owns symbol/history/basket guards; entry owns rolling OLS
and atomic open; management is empty beyond hard stops; close owns convergence,
beta-instability, time-stop, orphan repair, Friday close, and kill switch.
