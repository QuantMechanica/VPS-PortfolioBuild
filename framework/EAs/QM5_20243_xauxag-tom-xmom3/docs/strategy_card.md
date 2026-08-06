---
card_schema_version: 2
type: strategy
strategy_id: VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026_S01
variant_id: VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026_S01
source_id: VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026
ea_id: QM5_20243
slug: xauxag-tom-xmom3
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20243_xauxag-tom-xmom3_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
source_citation: "van Hemert (2014), SSRN 2515900; Fuertes, Miffre, and Rallis (2010), Journal of Banking & Finance 34(10), 2530-2548."
strategy_mechanic: three-date-turn-of-month-cycle-frozen-three-completed-month-average-return-rank-xau-xag-two-leg-basket
strategy_type_flags: [commodity, precious-metals, turn-of-month, cross-sectional-momentum, market-neutral-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20243_XAU_XAG_TOM_XMOM3_D1
symbol: QM5_20243_XAU_XAG_TOM_XMOM3_D1
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 8-12 complete two-leg packages/year; retire below five/year."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
review_focus: "Falsify the XAU/XAG relative-momentum rank only in the source-backed TOM flow window; no neutrality or decorrelation claim transfers."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [tom_calendar_translation, cycle_frozen_signal, synchronized_month_ends, basket_atomicity, aggregate_fixed_risk, restart_attempt_state, magic_schema, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission plus decisions/2026-08-06_qm5_20243_xauxag_tom_xmom3_g0.md; R1-R4 PASS; expected fuzzy momentum siblings manually separated by the load-bearing TOM-only lifecycle."
---

# QM5_20243 XAU/XAG MOM-TOM Cross-Sectional Momentum

The canonical card is `strategy-seeds/cards/xauxag-tom-xmom3_card.md`.

## Hypothesis

Trade a three-month gold/silver relative-momentum package only during Van
Hemert's last-two/first-one turn-of-month flow window. Opposite legs and equal
stop-risk budgets reduce common directional exposure but do not establish
dollar, beta, volatility, factor, or portfolio neutrality.

## Rules

Map the last two calendar dates of month `t` and first date of `t+1` to one
cycle. Consume the cycle before fallible gates. For each metal, reconstruct
four synchronized completed month ends ending at `t-1` and average the three
simple monthly returns. Buy the higher-return leg and short the lower; consume
equality or invalid state flat. Use two registered magics, a shared
`RISK_FIXED` budget, and frozen `3.5 * ATR(20,D1)` stops without targets.

## 4. Entry Rules

- Exact XAU D1 host, EA 20243, slots 0/1, fixed inputs, and one consumed cycle.
- Require synchronized endpoints, strict rank, valid spreads/quotes/ATR/lots,
  and no owned or same-cycle exposure.
- Open XAU then XAG; immediately flatten any partial or invalid package.

## 5. Exit Rules

- Close outside the same TOM cycle, after six calendar days, or on any orphan,
  duplicate, wrong-magic, same-direction, or missing-stop state.
- Friday close is disabled. No target, trail, partial, grid, martingale,
  scale-in, pyramid, or signal flip is allowed.

## 6. Filters (No-Trade Module)

Fail closed on identity, input, cycle, attempt, history, synchronization,
spread, quote, ATR, stop, volume, magic, deal, or package failure. News is OFF;
runtime reads native MT5 state only.

## 7. Trade Management Rules

Maintain exactly one opposite-direction two-leg package and one attempt per
cycle. Validate the package every tick and preserve the original broker hard
stops.

## Parameters To Test

All Q02 strategy inputs are locked: TOM pre/post `2/1`, formation `3` months,
history `500` bars, ATR `20`, stop `3.5`, hold `6` days, spreads `1500/3000`,
and deviation `20`.

## Risk

Q02 uses one logical-basket setfile with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. Retire below five packages/year, on nonpositive
economics, lifecycle/risk breach, nondeterminism, or later correlation
rejection. No live, `T_Live`, AutoTrading, deploy, portfolio-gate, or
correlation-waiver action is authorized.
