---
card_schema_version: 2
ea_id: QM5_20157
slug: xau-xag-ratio
type: strategy
strategy_id: SCHWEIKERT-XAUXAG-RATIO-2026_S01
variant_id: SCHWEIKERT-XAUXAG-RATIO-2026_S01
source_id: SCHWEIKERT-XAUXAG-RATIO-2026
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20157_xau-xag-ratio_card.md
execution_contract_status: DRAFT
created: 2026-07-25
created_by: Research+Development
last_updated: 2026-07-25
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka"
strategy_mechanic: rolling-log-gold-silver-ratio-zscore-reversion-two-leg-basket
source_citation: "Schweikert (2018), Journal of Banking & Finance 88; Yaya, Vo and Olayinka (2021), Resources Policy 72."
sources:
  - "[[sources/SCHWEIKERT-XAUXAG-RATIO-2026]]"
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, mean-reversion, low-frequency]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
markets: [commodities, precious_metals]
single_symbol_only: false
logical_symbol: QM5_20157_XAUUSD_XAGUSD_RATIO_D1
symbol: QM5_20157_XAUUSD_XAGUSD_RATIO_D1
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 5-20 completed two-leg packages/year; Q02 must prove or retire density."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 20.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: ENQUEUED
q02_work_item_id: 3ccaa92d-4376-4b6c-a536-9a982a9e497f
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, relative_value_neutrality, low_frequency, risk_mode_dual, cfd_basis, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission explicitly authorized XAUUSD~XAGUSD gold/silver ratio reversion as a candidate. R1 PASS two peer-reviewed publisher records; R2 PASS fixed rolling log-ratio z-score rules; R3 PASS registered XAUUSD.DWX and XAGUSD.DWX D1; R4 PASS deterministic native MT5 data only, no ML or banned indicators. Registry/card semantic scan found no identical rolling log-ratio z-score basket."
---

# QM5_20157 XAU/XAG Log-Ratio Reversion

## Hypothesis

Gold and silver share a source-supported, though state-dependent, long-run
relationship. Extreme deviations in their rolling D1 log price ratio may
revert. A simultaneous long/short precious-metals package isolates relative
value more directly than a standalone metal position.

This is a falsifiable CFD implementation hypothesis. Source evidence does not
prove a constant equilibrium, the chosen thresholds, future profitability,
or low correlation to the certified book.

## Source Traceability

The governed packet at
`strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` records two
peer-reviewed sources read from publisher pages. Schweikert (2018) reports a
nonlinear, time-varying gold/silver relationship and warns that constant-vector
tests can fail. Yaya, Vo and Olayinka (2021) report fractional cointegration
and discuss mean reversion. The rolling window and hard stops are deliberately
conservative QM translations of that non-stationarity warning.

## Non-Duplicate Decision

The mechanic is distinct from `QM5_1256_desai-goldsilver-stochpair`, which is
a stochastic-oscillator pair rule, and from single-metal trend, seasonal, and
oscillator EAs. It is also distinct from `QM5_12533`: that EA is an FX
EURJPY/GBPJPY spread; only its validated basket manifest/order recipe is reused.

## Rules

### Entry

1. Run only as the logical D1 basket hosted by `XAUUSD.DWX`; select both legs.
2. On each new D1 bar compute 60 completed observations of
   `S = ln(XAUUSD close) - 1.0 * ln(XAGUSD close)`.
3. Calculate the sample mean, sample standard deviation, and latest completed
   spread z-score. Missing/non-positive prices or zero variance fail closed.
4. When `z > +2.0`, sell XAU and buy XAG simultaneously (short spread).
5. When `z < -2.0`, buy XAU and sell XAG simultaneously (long spread).
6. Permit no entry while either basket leg is open. If only one opening order
   succeeds, close the orphan immediately.
7. Allocate fixed-risk budget 50/50 across legs. Each leg receives a frozen
   `2.0 * ATR(20, D1)` hard stop. There is no take profit.

### Exit

1. Recalculate the completed-bar spread state once per D1 bar.
2. Close both legs when `abs(z) < 0.5`.
3. If exactly one basket leg remains, close it immediately.
4. Framework Friday close and kill switch remain authoritative.
5. No trailing, break-even, partial close, scale-in, grid, martingale, or
   discretionary exit is authorized.

### Parameters locked for baseline

- `strategy_z_lookback_d1=60`
- `strategy_beta=1.0`
- `strategy_entry_z=2.0`
- `strategy_exit_z=0.5`
- `strategy_atr_period_d1=20`
- `strategy_atr_sl_mult=2.0`
- `strategy_deviation_points=20`

## Risk and test contract

Q02–Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The two ATR-normalized legs split the risk budget by
equal risk weight. The basket is structurally relative-value but beta=1 and
ATR risk parity do not guarantee realized dollar neutrality; exposure and
portfolio correlation remain empirical Q-gate questions.

News temporal/compliance axes are OFF for the Q02 native-price baseline.
No external feed, futures roll series, inventory data, or ML is used.

## Acceptance and retirement

Q02 must show at least 5 completed packages per year after warm-up and valid
two-leg execution. Zero/one-leg behavior is an implementation defect; below
the frequency floor is RETIRE. Later gates decide costs, robustness, and
correlation. This card authorizes build and non-live testing only.

## Framework alignment

- No-trade: exact symbols, D1 host/slot, history and basket scope.
- Entry: completed-bar log ratio, z threshold, atomic two-leg open.
- Management: none beyond broker stops.
- Close: convergence, orphan repair, Friday close, kill switch.
