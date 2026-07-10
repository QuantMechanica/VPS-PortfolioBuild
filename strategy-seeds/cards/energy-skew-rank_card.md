---
strategy_id: FERNANDEZ-SKEW-2018_XTI_XNG_S01
source_id: FERNANDEZ-SKEW-2018
ea_id: QM5_13118
slug: energy-skew-rank
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Fernandez-Perez, Frijns, Fuertes, and Miffre (2018), The Skewness of Commodity Futures Returns, Journal of Banking & Finance 86, 143-158, DOI 10.1016/j.jbankfin.2017.06.015."
source_citations:
  - type: peer_reviewed_paper
    citation: "Fernandez-Perez, Adrian; Frijns, Bart; Fuertes, Ana-Maria; and Miffre, Joelle (2018). The Skewness of Commodity Futures Returns. Journal of Banking & Finance 86, 143-158."
    location: "Sections 3.1 and 4.1-4.4; Equation 1; Tables I and III-V; Appendix A; DOI https://doi.org/10.1016/j.jbankfin.2017.06.015; accepted manuscript https://openrepository.aut.ac.nz/server/api/core/bitstreams/05e08e2e-f763-4f46-ac67-4c13ac10a451/content"
    quality_tier: A
    role: primary
sources:
  - "[[sources/FERNANDEZ-SKEW-2018]]"
concepts:
  - "[[concepts/commodity-skewness-premium]]"
  - "[[concepts/energy-relative-value]]"
  - "[[concepts/selective-hedging]]"
indicators:
  - "[[indicators/pearson-skewness]]"
  - "[[indicators/atr]]"
strategy_type_flags: [cross-sectional-rank, market-neutral-basket, monthly-rebalance, symmetric-long-short, atr-hard-stop]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
markets: [commodities, energy, crude_oil, natural_gas]
single_symbol_only: false
logical_symbol: QM5_13118_ENERGY_SKEW_RANK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "One market-neutral monthly XTI/XNG package after warm-up; approximately 12 completed packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.05
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Adds a monthly commodity-skewness risk-premium driver; realized orthogonality to the XAU/SP500/NDX/XNG book remains unclaimed until Q09."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, narrow_cross_section]
g0_approval_reasoning: "Mission-directed G0 2026-07-10: R1 peer-reviewed JBF DOI/full institutional manuscript with explicit crude-oil and natural-gas source instruments; R2 locked 12-month Pearson-skew monthly energy rank; R3 native registered XTI/XNG D1; R4 no ML/banned/external/grid/martingale; pre-allocation dedup CLEAN."
---

# XTI/XNG Commodity-Skewness Rank

## Hypothesis

Commodity investors and commercial hedgers can prefer lottery-like positive
skewness and avoid negative skewness, causing high-skew contracts to become
relatively overpriced and low-skew contracts to earn a premium. The source
finds that past realized skewness contains information beyond momentum, carry,
hedging pressure, business-cycle, and calendar-seasonality factors. This card
tests that structural risk premium in a paired energy carrier: long the lower-
skew leg and short the higher-skew leg.

The pair is market-neutral by opposite direction and equal fixed-risk
allocation, not guaranteed beta neutrality. Low correlation to the current
book is a design objective only; Q09 is the correlation judge.

## Source And Evidence Boundary

The primary source is Fernandez-Perez, Frijns, Fuertes, and Miffre (2018),
*Journal of Banking & Finance* 86, DOI
`10.1016/j.jbankfin.2017.06.015`. The complete 44-page accepted manuscript was
read, including appendices and tables. It estimates each commodity's Pearson
skewness from 12 months of daily log returns, ranks 27 futures monthly, buys the
lowest-skew quintile, and shorts the highest-skew quintile for one month. Crude
oil and natural gas are explicit members of its energy panel.

One bounded author conclusion is that the paper documents "a significantly
negative relation between skewness and expected returns." The source's broad
portfolio performance is not a claim for this two-leg CFD carrier.

## Concept And Non-Duplicate Decision

On the first tradable `XTIUSD.DWX` D1 bar of each broker month, compute each
energy leg's Pearson moment coefficient from completed daily log returns in the
preceding 12 complete broker-calendar months:

`skew = mean((r - mean(r))^3) / mean((r - mean(r))^2)^(3/2)`.

- Lower XTI skew: buy XTI and sell XNG.
- Higher XTI skew: sell XTI and buy XNG.
- Exact numerical tie, invalid variance, or insufficient history: stay flat.

This differs mechanically from:

- `QM5_12567_cum-rsi2-commodity`, a long-only two-day RSI pullback;
- `QM5_12733_xti-xng-xmom`, a recent-return momentum rank;
- `QM5_12840_xti-xng-rspread`, a return-spread z-score fade;
- `QM5_12850_xti-xng-vcb`, a volatility-contraction breakout;
- `QM5_13089_xti-xng-carry`, a broker swap/carry rank;
- `QM5_13113_energy-mom-ivol`, a momentum and residual-volatility double sort;
- `QM5_13115_energy-samecal`, a historical same-calendar-month return rank;
- fixed-month, inventory, COT, RSI, channel, and event cards, whose signals do
  not use the third moment of the daily return distribution.

Repository search found no commodity realized-skewness implementation.
Pre-allocation dedup was `CLEAN` for slug `energy-skew-rank`, strategy ID
`FERNANDEZ-SKEW-2018_XTI_XNG_S01`, and the complete mechanic.

## Markets And Timeframe

- Logical basket: `QM5_13118_ENERGY_SKEW_RANK_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Signal cadence: first tradable D1 bar of each broker month.
- Expected frequency: approximately 12 completed paired packages/year after
  warm-up, above the Q02 floor of five trades/year/symbol.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split equally across the legs.
- Runtime data: native MT5 D1 closes, ATR, spread, broker calendar, and position
  state only.

## Rules

### Entry Rules

- Evaluate only on the first new host D1 bar of a broker month.
- Define the formation window as the 12 completed broker-calendar months
  immediately before that decision month; never include the current month.
- Copy bounded completed D1 histories for XTI and XNG.
- Convert consecutive valid positive closes inside the window to daily log
  returns. Require at least `strategy_min_return_observations=180` for each leg.
- Compute each leg's Pearson population moment coefficient using the same
  daily-return definition and 12-month window as the source.
- Require finite statistics and strictly positive return variance for both legs.
- BUY XTI plus SELL XNG when `skew_XTI < skew_XNG`.
- SELL XTI plus BUY XNG when `skew_XTI > skew_XNG`.
- Do not enter on an exact numerical tie, invalid history/arithmetic/ATR,
  excessive spread, an existing package, or a month already attempted.
- Allocate half the fixed package-risk budget to each leg and place a frozen
  per-leg ATR hard stop.

## Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month, then
  rerank and allow one renewed package.
- Close both legs if the package exceeds `strategy_max_hold_days=35`.
- If either hard stop removes one leg, flatten the orphaned leg immediately.
- Flatten any unexpected side or magic composition.
- Friday close is disabled to preserve the source's one-month holding period.

## Filters And Trade Management

- Exact host guard: `XTIUSD.DWX`, D1, magic slot 0.
- Parameter, history, arithmetic, variance, ATR, volume-step, and spread checks
  fail closed.
- One paired package per EA; no re-entry after a stop within the same month.
- No take-profit, trailing stop, break-even move, partial close, scale-in,
  grid, martingale, pyramiding, external data, adaptive fit, or ML.
- Framework kill switch and news entry compliance remain authoritative.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_lookback_months` | 12 | [12] | source-defined formation window |
| `strategy_history_bars` | 500 | [400, 500, 650] | bounded D1 reconstruction buffer |
| `strategy_min_return_observations` | 180 | [180, 200] | fail-closed data sufficiency |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg hard-stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard around monthly reset |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG entry spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The 12-month completed daily-return window, Pearson third standardized moment,
lower-minus-higher rank direction, monthly rebalance, paired carrier, and no
same-month re-entry are locked. Changing to co-skewness, an implied option
measure, a magnitude/volatility rank, an adaptive threshold, or a single-leg
time-series skew signal requires a new card.

## Initial Risk Profile

- `expected_pf: 1.05` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 25.0` reflects XNG gap risk, legging risk, and the narrow
  two-asset cross-section.
- Risk class: high.
- The source's 27-future quintiles and collateral treatment are absent. The
  V5 carrier uses equal `RISK_FIXED` leg budgets and hard stops rather than
  importing source portfolio weights.

## Kill Criteria

- Retire at Q02 if realized frequency is below five completed packages/year.
- Fail on zero trades, invalid formation windows, non-deterministic reruns,
  repeated `OnInit` failure, orphan packages, or risk-mode mismatch.
- Do not shorten the 12-month window, replace skewness with a proxy, add a
  directional filter, or widen the universe after a poor baseline.
- Treat the 27-future-to-two-CFD narrowing and futures/CFD basis mismatch as
  falsification risks, not waiver grounds.

## Strategy Allowability Check

- [x] R1 reputable: peer-reviewed Journal of Banking & Finance paper, DOI, and
  complete institutional accepted manuscript.
- [x] R2 mechanical: fixed completed-window Pearson skewness, deterministic
  energy rank, monthly renewal, and ATR hard stops.
- [x] R3 testable: registered `XTIUSD.DWX` and `XNGUSD.DWX` D1 history.
- [x] R4 compliant: no banned indicator, ML, external runtime feed, adaptive
  PnL fit, grid, martingale, or pyramiding.
- [x] Expected frequency exceeds the five-trades/year Q02 floor.
- [x] Repository dedup was clean before atomic EA-ID allocation.

## Framework Alignment

- no_trade: exact host/slot, parameter domain, monthly attempt, bounded
  completed-window history, arithmetic/variance, spread, ATR, and package guards.
- trade_entry: source-defined low-skew-versus-high-skew energy rank, paired
  market orders, equal fixed-risk allocation, and frozen ATR stops.
- trade_management: next-month rollover, 35-day stale close, package-side and
  orphan repair.
- trade_close: framework close helper plus broker ATR stops.

`hard_rules_at_risk`:

- `basket_execution`: Q02 must evaluate one logical package rather than two
  standalone legs.
- `friday_close`: disabled only for the source-aligned monthly hold; monthly
  rollover, stale close, orphan cleanup, and hard stops remain.
- `risk_mode_dual`: the build creates only a RISK_FIXED backtest setfile.
- `cfd_futures_basis`: no futures/CFD equivalence is assumed.
- `narrow_cross_section`: two energy legs are not the paper's extreme quintiles.

## Implementation Notes

- target_modules.no_trade: exact XTI/D1/slot and fail-closed parameter/history
  guards.
- target_modules.entry: bounded completed-window log returns, Pearson skewness,
  cross-sectional rank, paired fixed-risk ATR-stopped orders.
- target_modules.management: monthly reset, orphan/side repair, and stale close.
- target_modules.close: `QM_TM_ClosePosition` plus broker stops.
- estimated_complexity: medium.
- estimated_test_runtime: one logical XTI/XNG D1 Q02 baseline.
- data_requirements: standard native DWX D1 history only.

## Risk

Q02 falsifies this card if trade density, economics, drawdown, execution, or
data integrity fail. The source-diversification loss, futures-to-CFD
translation, equal-risk rather than beta-neutral sizing, and XNG gap risk are
explicit. Portfolio correlation is not inferred and may only be measured at
Q09 after a surviving return stream exists.

No `T_Live`, AutoTrading setting, live setfile, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial source-backed XTI/XNG skewness-rank build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by OWNER mission directive | this card |
| Q01 Build Validation | 2026-07-10 | PENDING | `artifacts/qm5_13118_build_result.json` |
| Q02 Baseline Screening | 2026-07-10 | PENDING ENQUEUE | evidence pending |
