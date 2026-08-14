---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-SCHWEIKERT-XAUXAG-SEASRV-2026_S01
variant_id: KELOHARJU-SCHWEIKERT-XAUXAG-SEASRV-2026_S01
source_id: KELOHARJU-SCHWEIKERT-XAUXAG-SEASRV-2026
ea_id: QM5_21517
slug: xauxag-seas-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_21517_xauxag-seas-rv_card.md
execution_contract_status: DRAFT
created: 2026-08-14
created_by: Research+Development
last_updated: 2026-08-14
g0_status: APPROVED
source_author: "Matti Keloharju; Juhani Linnainmaa; Peter Nyberg; Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_authors: "Matti Keloharju; Juhani Linnainmaa; Peter Nyberg; Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Journal of Finance 71(4), 1557-1590; Schweikert (2018), Journal of Banking & Finance 88, 44-51; Yaya, Vo, and Olayinka (2021), Resources Policy 72, 102045; CME Group Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete 57-page review strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: prior_year_same_calendar_month_return_expectation
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed review strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relation
  - type: peer_reviewed_paper
    citation: "Yaya, O. S., Vo, X. V., and Olayinka, H. A. (2021). Gold and silver prices, their stocks and market fear gauges: Testing fractional cointegration using a robust approach. Resources Policy 72, 102045."
    location: "DOI 10.1016/j.resourpol.2021.102045; governed review strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: long_run_mean_reversion_context
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: B
    role: opposite_leg_relative_value_carrier
strategy_mechanic: monthly-xau-xag-just-completed-relative-return-minus-prior-ten-year-same-calendar-relative-mean-standardized-surprise-contrarian-two-leg-basket
sources:
  - "[[sources/KELOHARJU-SCHWEIKERT-XAUXAG-SEASRV-2026]]"
concepts:
  - "[[concepts/same-calendar-month-seasonality]]"
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/seasonally-adjusted-reversal]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/sample-standard-deviation]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, calendar-seasonality, standardized-surprise, contrarian, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_21517_XAU_XAG_SEASRV_D1
symbol: QM5_21517_XAU_XAG_SEASRV_D1
symbol_slot: 0
magic: 215170000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately six to nine completed two-leg packages per full post-warm-up year at the fixed half-standard-deviation band; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02_ENQUEUED
q01_status: PASS
q02_status: ENQUEUED
review_focus: "Falsify a monthly paired precious-metals return stream that fades only the realized XAU-minus-XAG return unexplained by its recurring same-calendar expectation; Q09 alone may establish realized decorrelation from the XAU/SP500/NDX/XNG book."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [just_completed_month_mapping, synchronized_month_end_timestamps, realized_sample_exclusion, ten_year_same_calendar_window, sample_variance_denominator, strict_surprise_band, contrarian_direction, basket_atomicity, aggregate_fixed_risk, restart_attempt_state, magic_schema, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-14_qm5_21517_xauxag_seas_rv_g0.md: R1 peer-reviewed Journal of Finance seasonality lineage plus peer-reviewed gold/silver relation papers and a governed CME carrier; R2 exact completed-month seasonal-surprise estimator, n-1 scale, strict band, inverse sides, shared risk, stops, monthly attempt, renewal, and repair; R3 registered XAU/XAG D1 route; R4 deterministic native arithmetic only. The canonical checker returned CLEAN across 4,389 registry rows and 485 intake cards; same-calendar-following, agreement, raw momentum, return-spread, ratio, residual, tail, channel, run, and rank families were manually separated."
---

# QM5_21517 XAU/XAG Seasonal-Surprise Reversion

## Hypothesis

Gold and silver share a long-run but state-dependent relationship while their
monetary, safe-haven, industrial, and business-cycle sensitivities differ.
Recurring calendar effects may explain part of their relative monthly return.
When the just-completed gold-minus-silver return is unusually large even after
subtracting that calendar expectation, the residual displacement may converge
over the next broker month.

The opposite-leg package targets relative precious-metal exposure rather than
another outright XAU or index swing. It is not proof of dollar, beta,
volatility, factor, or portfolio neutrality. Q02 owns density and baseline
economics; Q09 alone owns realized book correlation.

## Source traceability and claim boundary

The governed composite packet is
`strategy-seeds/sources/KELOHARJU-SCHWEIKERT-XAUXAG-SEASRV-2026/source.md`.
Keloharju, Linnainmaa, and Nyberg supply the prior-year same-calendar commodity
return expectation. Schweikert and Yaya, Vo, and Olayinka supply the
state-dependent gold/silver relation and long-run mean-reversion context. CME
defines the ratio-spread carrier and its distinct metal drivers.

None of the sources tests the exact conjunction, ten-year cap, sample scale,
half-standard-deviation band, Darwinex continuous CFDs, aggregate fixed risk,
ATR stops, spread caps, attempt ledger, or monthly lifecycle. No source return,
alpha, significance, Sharpe ratio, drawdown, trade count, cost, hedge ratio,
neutrality, CFD equivalence, or portfolio-correlation statistic transfers.

## Non-duplicate decision

The canonical checker returned `CLEAN` for the slug, strategy ID, and complete
mechanic across 4,389 registry rows and 485 intake cards. Manual review fixes
the boundary:

- `QM5_20186_xauxag-samecal` follows the historical seasonal mean for the
  decision month; it never observes or reverses a realized surprise.
- `QM5_20189_xauxag-calmom1` follows only when the seasonal and immediately
  completed relative-return signs agree. This candidate subtracts expectation,
  divides by its historical sample scale, and fades the residual.
- `QM5_20057_xauxag-xmom1` follows the raw prior relative month.
- `QM5_12862_xauxag-rspread` fades a rolling ten-D1 return-spread score, not a
  completed broker month relative to recurring calendar history.
- Ratio-level, OLS, conditional-quantile, C-MTAR, MAD, empirical-tail, channel,
  run, variance-ratio, moment-rank, and long-horizon reversal EAs use different
  state objects or clocks.

The completed-month mapping, same-calendar historical sample, exclusion of the
realized observation, expectation subtraction, sample scaling, strict
contrarian band, and monthly package are jointly load-bearing. Verdict:
`CLEAN_AUTHORIZED_XAUXAG_STANDARDIZED_SEASONAL_SURPRISE_REVERSION`.

## Markets, timeframe, and formula

- Logical basket: `QM5_21517_XAU_XAG_SEASRV_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1, magic `215170000`.
- Companion/traded slot 1: `XAGUSD.DWX`, D1, magic `215170001`.
- Decision clock: first processed host D1 bar after a genuine broker-month
  transition.
- Formation: just-completed synchronized relative month plus the same calendar
  month in up to exactly ten earlier years, requiring at least five samples.
- Hold: until the next broker-month boundary, with a 40-day stale guard.

At decision month `M`, let `J=M-1` with exact year rollover. For synchronized
month-end closes:

```text
realized_J = ln(XAU_end_J / XAU_end_(J-1))
           - ln(XAG_end_J / XAG_end_(J-1))

sample_y   = the same relative return for calendar month J in prior year y
mu          = arithmetic_mean(sample_y)
sd          = sqrt(sum((sample_y-mu)^2)/(n-1))
surprise_z  = (realized_J-mu)/sd

SELL XAU / BUY XAG when surprise_z > +0.50 + 1e-10
BUY XAU / SELL XAG when surprise_z < -0.50 - 1e-10
FLAT otherwise
```

The realized observation is excluded from `sample_y`. Population variance,
pooled leg variances, simple returns, a decision-month forecast, or a rolling
D1 score is not equivalent.

## Rules

The entry, exit, filter, and lifecycle rules below are the complete authorized
baseline. There is no signal-parameter sweep or fallback estimator.

## 4. Entry Rules

1. Require exact EA ID `21517`, `XAUUSD.DWX` D1 host, slot 0, both registered
   magics, and every locked baseline input.
2. Process malformed-package repair and prior-month liquidation before
   entry-only gates. Evaluate only after a genuine broker-month transition.
3. Persist the current broker month as consumed before history, signal, news,
   spread, quote, ATR, sizing, or order checks. A flat, blocked, failed,
   stopped, or partially opened decision may not retry that month.
4. Reconstruct the exact just-completed broker month and its preceding month
   from completed D1 bars for both legs. Require positive finite closes and
   exact matching XAU/XAG endpoint timestamps.
5. Reconstruct the same relative calendar-month return in the preceding ten
   years, excluding the realized observation. Retain only exactly synchronized
   paired samples and require at least five.
6. Compute each relative log return as XAU minus XAG, the arithmetic sample
   mean, and sample standard deviation with denominator `n-1`. Zero or
   nonfinite variance consumes the month flat.
7. At `surprise_z > +0.50 + 1e-10`, sell XAU and buy XAG. At
   `surprise_z < -0.50 - 1e-10`, buy XAU and sell XAG. Otherwise remain flat.
8. Require no owned exposure or same-month entry deal, XAU/XAG spreads in
   `[0,1500]` and `[0,3000]` points, executable quotes, completed
   `ATR(20,D1)`, valid stops, registered magics, and valid volume metadata.
9. Split one aggregate `RISK_FIXED=1000` package budget equally between the
   two independently ATR-normalized legs. Attach a frozen
   `3.5*ATR(20,D1)` hard stop to each; no take-profit.
10. Open XAU then XAG and retain exposure only if exactly one correctly
    directed, opposite-side position exists in each slot. Flatten every owned
    leg immediately after order or final-package failure.

## 5. Exit Rules

1. Close both legs on the first processed XAU D1 bar of the next broker month
   before considering a replacement package.
2. Close both legs after 40 elapsed calendar days as a stale guard.
3. Immediately flatten an orphan, duplicate, wrong-symbol, same-direction,
   wrong-magic, or missing-stop package.
4. Per-leg broker hard stops and the framework kill switch remain
   authoritative.
5. Friday close is disabled because the source-aligned monthly hold spans
   weekends.
6. There is no intramonth signal exit, target, trail, break-even, partial
   close, scale-in, grid, martingale, pyramid, or discretionary exit.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact host, timeframe, EA ID, slot, risk, news,
  Friday, stress, or locked strategy inputs.
- Reject consumed or already-entered months, owned exposure, incomplete or
  mismatched month endpoints, the wrong calendar-month sample, fewer than five
  samples, included realized observation, nonfinite return, population or zero
  variance, inside-band surprise, excessive spread, invalid quote, ATR, stop,
  magic, or volume state.
- Both news axes and the legacy news mode are locked OFF for Q02. Lifecycle
  exits and package repair run before entry-only gates.
- Runtime may not read a futures chain, external file/API, inventory, analyst
  forecast, trained output, optimizer result, or portfolio state.

## 7. Trade Management Rules

- Maintain exactly one XAU position and one oppositely directed XAG position,
  each in its registered magic slot with its original broker hard stop.
- One shared fixed-risk package budget is split equally by stop risk. Signal
  magnitude never scales the risk budget.
- Consume at most one decision per broker month. Terminal-persistent state plus
  owned deal/position history prevents restart re-entry; tester initialization
  clears only a future-dated marker.
- Close old-month, stale, orphaned, duplicate, same-direction, wrong-magic, or
  missing-stop exposure before entry logic.
- No randomness, PnL-adaptive fit, partial close, scale-in, or pyramiding is
  allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_history_years` | 10 | [10] | bounded prior same-calendar years |
| `strategy_min_history_years` | 5 | [5] | minimum synchronized historical samples |
| `strategy_history_bars` | 4000 | [4000] | bounded completed-D1 reconstruction buffer |
| `strategy_completed_months` | 1 | [1] | exact just-completed formation month |
| `strategy_surprise_entry_z` | 0.50 | [0.50] | strict standardized-surprise band |
| `strategy_signal_epsilon` | 1e-10 | [1e-10] | threshold comparison tolerance |
| `strategy_variance_epsilon` | 1e-16 | [1e-16] | fail-closed variance floor |
| `strategy_atr_period_d1` | 20 | [20] | completed per-leg stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop multiple |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | basket order deviation |

Every calendar offset, endpoint, return type, sample rule, denominator,
threshold, side, risk split, stop, hold, spread, and retry rule is locked.

## Author Claims

The seasonality paper supports a historical same-calendar commodity-return
expectation in a broad cross-section. The gold/silver papers support a
state-dependent long-run relationship, and CME supports the intermarket
carrier. None claims that a standardized seasonal surprise predicts next-month
convergence on two continuous CFDs or that this package diversifies the QM
book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the aggregate package. Risk is high: this is a novel
cross-source conjunction on a two-name carrier; ten same-calendar observations
produce a noisy scale; common USD/metal beta, silver industrial beta, CFD
financing/rolls, gaps, asynchronous history, legging, hard-stop
desynchronization, and lot granularity may dominate the intended relative
return.

Opposite direction and equal stop-risk halves do not guarantee dollar, beta,
volatility, factor, or portfolio neutrality.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full
  post-warm-up year.
- Fail on wrong month mapping, timestamp mismatch, realized-sample leakage,
  simple rather than log returns, population variance, wrong threshold or
  sides, repeated monthly attempt, same-direction/orphan legs, aggregate-risk
  breach, hold beyond 40 days, missing stop, invalid risk mode, or
  nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing a window, sample floor, estimator,
  threshold, direction, carrier, stop, hold, spread, or retry rule.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | Peer-reviewed Journal of Finance seasonality paper with complete open-paper evidence, two peer-reviewed gold/silver relation papers, and a governed CME carrier. |
| R2 | PASS | Fixed calendar mapping, synchronized samples, estimator, strict band, inverse sides, package risk, stops, attempt state, renewal, and repair. |
| R3 | PASS | Registered synchronized XAU/XAG D1 history and native execution state supply every runtime input. |
| R4 | PASS | Deterministic calendar, price, logarithm, arithmetic, ATR, and trade-state operations only. |

- [x] Dedup: deterministic CLEAN; manual review separates seasonal following,
  sign agreement, raw momentum, return-spread, ratio, residual, robust tail,
  channel, run, moment, and reversal families.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked inputs, risk/news/Friday contract,
  magic, and cheap parameter guards.
- trade_entry: consumed monthly attempt, completed-month reconstruction,
  historical same-calendar sample, standardized surprise, inverse sides,
  spread/quote/ATR/stop checks, two orders, and atomic repair.
- trade_management: malformed-state repair, next-month close, 40-day stale
  exit, and orphan cleanup before entry-only gates.
- trade_close: framework close helper, per-leg broker hard stops, and kill
  switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, one logical-basket `RISK_FIXED` backtest setfile, and one paced
non-live Q02 handoff when CPU capacity permits. It does not authorize a manual
backtest; live, demo, shadow, stress, or optimization artifact; AutoTrading;
`T_Live`; deploy/T_Live manifest; portfolio admission; portfolio-gate change;
or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-14 | initial standardized XAU/XAG seasonal-surprise reversal | Q02 | Q01 PASS; Q02 enqueued |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-14 | APPROVED; R1-R4 PASS | `decisions/2026-08-14_qm5_21517_xauxag_seas_rv_g0.md`; bounded source packet |
| Q01 Build Validation | 2026-08-14 | PASS; compile 0/0, build check 0/0 | `artifacts/qm5_21517_build_result.json` |
| Q02 Baseline Screening | 2026-08-14 | ENQUEUED, pending | work item `774d944c-7220-4c22-8a74-93a0791168c8` |
