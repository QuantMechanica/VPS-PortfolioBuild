---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026_S01
variant_id: KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026_S01
source_id: KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026
ea_id: QM5_41224
slug: wti-samecal-regimeshift
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41224_wti-samecal-regimeshift_card.md
execution_contract_status: APPROVED
created: 2026-08-30
created_by: Research+Development
last_updated: 2026-08-30
g0_status: APPROVED
g0_decision: decisions/2026-08-30_qm5_41224_wti_same_calendar_regime_shift_g0.md
source_approval: decisions/2026-08-30_wti_same_calendar_regime_shift_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), DOI 10.1111/jofi.12398; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete-read parent packet strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_commodity_information_explicit_crude_oil_membership_and_five_year_floor
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read parent packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: explicit_wti_membership_own_return_direction_and_monthly_lifecycle
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI same-calendar chronological regime-shift extraction."
    location: "strategy-seeds/sources/KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026/source.md"
    quality_tier: internal_governed
    role: exact_calendar_endpoints_two_chronological_blocks_disagreement_direction_risk_and_lifecycle
strategy_mechanic: exact-prior-ten-year-same-calendar-month-wti-log-returns-recent-five-mean-versus-older-five-mean-strict-opposite-sign-follow-recent-block-monthly-renewal
sources:
  - "[[sources/KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/time-series-direction]]"
  - "[[concepts/chronological-regime-shift]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/two-block-arithmetic-mean]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, chronological-regime-shift, disagreement-filter, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 412240000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "At most 12 monthly decisions and provisionally 5-8 completed WTI positions per full post-warm-up year; Q02 must measure and retire any full year below five."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_TWO_BLOCK_SINGLE_CARRIER_CFD_TRANSLATION_RISK
r1_reasoning: "Complete peer-reviewed sources explicitly cover same-calendar commodities, crude oil/WTI membership, own-return direction, and monthly renewal. The exact chronological five/five reversal conjunction remains an untested QM translation."
r2_mechanical: PASS
r2_reasoning: "Month clock, normalized endpoints, exact Y-1..Y-10 membership, complete five/five blocks, arithmetic means, strict disagreement, recent-block side, consumed attempt, fixed risk, hard stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_qualification: TEN_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history and native MT5 state supply every runtime input; ten-year warm-up, session labels, rolls, financing, gaps, and futures/CFD basis remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite sums, division, comparisons, ATR risk controls, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: exact prior 10 same-calendar years, all 10 mandatory; recent block lags 1-5; older block lags 6-10; arithmetic divisor 5 for each; strict opposite signs; follow recent block; epsilon 1e-12; 3000 D1 history bars; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify a monthly direct-WTI regime-shift sleeve outside the certified XAU/SP500/NDX/XNG book. Verify normalized completed endpoints, exact ten-year membership, recent and older five-year arithmetic, strict sign reversal, recent-block direction, consumed month, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized independence."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, uniform_energy_label_normalization, exact_prior_ten_year_same_calendar_months, completed_month_endpoints, no_current_month_price, ten_of_ten_sample, recent_lags_one_to_five, older_lags_six_to_ten, arithmetic_divisor_five, strict_block_sign_reversal, recent_block_direction, strict_sign_epsilon, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-30 and decisions/2026-08-30_qm5_41224_wti_same_calendar_regime_shift_g0.md: R1 passes with two complete peer-reviewed WTI/commodity lineages and explicit translation risk; R2 locks calendar, endpoints, blocks, arithmetic, reversal, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with warm-up/session/CFD risk; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found no exact identity; manual review and a fixed opposite-side fixture separate raw mean, robust location, decay, t-score, sign-score, and intramonth change-point neighbors."
---

# QM5_41224 WTI Same-Calendar Chronological Regime Shift

## Hypothesis

WTI demand, storage, production, refinery, transport, hedging, and capital-
allocation pressures can recur in the same calendar month. Those pressures can
also reverse as technology, policy, trade routes, and producer behavior
change. A chronological comparison of recent and older same-month histories
tests only transitions in seasonal direction: it follows the recent five-year
block when that block strictly opposes the older five-year block and stays flat
when the seasonal sign is stable.

This is a direct crude-oil structural sleeve outside the certified
XAU/SP500/NDX/XNG carrier set. Different carrier and information clock do not
prove low realized correlation. Q02 owns activity and baseline economics;
unchanged Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026/source.md`.
It was committed after durable source approval in
`decisions/2026-08-30_wti_same_calendar_regime_shift_source_approval.md`.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity-
return information, explicit crude-oil membership, monthly renewal, and a
five-year history floor. Moskowitz, Ooi, and Pedersen supply WTI membership,
own-return direction, and monthly renewal. Neither tests the exact chronological
two-block sign reversal or following the recent block.

No source performance, significance, profit factor, drawdown, trade count,
cost, continuous-futures/CFD equivalence, correlation, or portfolio statistic
transfers. The ten-year window, five/five split, strict disagreement state,
recent-block direction, and execution plumbing are locked QM falsification
choices, not fitted or source-claimed optima.

## Non-Duplicate Decision

The corrected-root checker scanned 4,723 registry identities, 1,361 card
files, and all 45 current Strategy Wiki nodes. It found no exact identity and
returned the expected raw WTI same-calendar fuzzy neighbor. Manual mechanic
review fixes the boundary:

- `QM5_20099_wti-samecal` follows the full-sample arithmetic mean. This card
  requires opposite signs in the exact recent and older five-year blocks and
  follows only the recent block.
- `QM5_41055`, `QM5_41199`, `QM5_41201`, `QM5_41202`, and `QM5_41204`
  estimate one robust location. None compares chronological blocks.
- `QM5_41211_wti-samecal-tstat` gates one mean by its sample standard error;
  `QM5_41212_wti-samecal-signscore` uses one full-sample sign count.
- `QM5_41223_wti-samecal-expw4` applies continuous year-age decay and follows
  its weighted sign. This card has no decay kernel and is flat in stable
  seasonal-sign states.
- `QM5_41172_wti-mpettitt-shift-tr` detects a distribution shift among daily
  observations inside one completed month, not across exact same-calendar
  returns from ten years.

For recent-to-old exact-year returns
`[+.01,+.01,+.01,+.01,+.01,-.03,-.03,-.03,-.03,-.03]`, the full equal mean
is `-.01` and the raw same-calendar rule sells. This card's recent mean is
`+.01`, its older mean is `-.03`, and it buys. All-positive or all-negative
histories make raw and decay rules trade but force this card flat. The split,
opposite-sign requirement, and recent-block side are executable and load
bearing rather than a parameter rename.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_CHRONOLOGICAL_REGIME_SHIFT`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `412240000`.
- Decision clock: first processed D1 bar after a genuine normalized broker-
  month transition.
- Formation: exact completed return of the upcoming named month in every year
  `Y-1..Y-10`; all ten observations required.
- Holding clock: next genuine normalized broker-month boundary; forty calendar
  days is survivor repair.
- Expected cadence: provisionally five to eight positions per full post-warm-
  up year; Q02 retires any full year below five.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, point metadata,
  position, deal, broker calendar, and framework state only.

## Rules

At decision month `(Y,M)`, reconstruct WTI's completed return for calendar
month `M` in every exact prior year `Y-k`, `k=1..10`:

```text
r_k = ln(close_at_end_of_month(Y-k,M) /
         close_at_end_of_previous_month(Y-k,M))
recent_mean = (r_1 + r_2 + r_3 + r_4 + r_5) / 5
older_mean  = (r_6 + r_7 + r_8 + r_9 + r_10) / 5

BUY  iff recent_mean > +1e-12 and older_mean < -1e-12
SELL iff recent_mean < -1e-12 and older_mean > +1e-12
FLAT otherwise
```

Require strict adjacent-month endpoints, a confirming following D1 bar,
positive finite closes, finite returns, all ten exact years, and finite means.
There is no missing-year substitution, block compression, weighting, ranking,
sorting, clipping, or fallback. No price from the current decision month
enters the signal. Magnitude never changes risk.

## 4. Entry Rules

1. Require exact EA ID `41224`, `XTIUSD.DWX` D1, slot 0, and every baseline
   input locked to the values below.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine normalized broker-month transition.
3. Persist current broker `yyyymm` before history, signal, spread, quote,
   news, stop, sizing, or order checks. A flat, rejected, failed, stopped, or
   blocked outcome cannot retry that month.
4. Reject owned exposure or any owned entry deal already recorded in the
   current broker month.
5. Copy no more than 3,000 completed D1 bars. Under one uniform native or `+1`
   label convention, reconstruct exact calendar-month returns at lags one
   through ten. Any missing or malformed year consumes the month flat.
6. Sum lags one through five into the recent block and lags six through ten
   into the older block, divide each by exactly five, and apply the strict
   opposite-sign rule. Follow only the recent block's sign.
7. Require a noncrossed quote, modeled spread in `[0,1500]` points, and a
   finite completed `ATR(20,D1)`.
8. Open one market position with a frozen `3.5*ATR(20,D1)` hard stop and no
   take-profit. Framework fixed-risk sizing remains authoritative.

## 5. Exit Rules

1. Close prior-month exposure on the first D1 bar belonging to a later
   normalized broker month before considering replacement risk.
2. Close any position after forty elapsed calendar days as survivor repair.
3. Broker hard stops and the framework kill switch remain authoritative.
4. Friday close is disabled because the approved hold spans weekends.
5. No intramonth signal flip, target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact symbol, D1 timeframe, EA ID, slot, and frozen
  input contract.
- Reject a non-transition bar, consumed month, owned exposure, same-month
  entry deal, incomplete ten-year history, mixed label convention, malformed
  endpoint, current-month leakage, nonpositive close, invalid logarithm,
  invalid block sum or mean, either inclusive epsilon tie, equal block signs,
  invalid ATR/quote/point metadata, crossed quote, negative spread, or
  excessive spread.
- Both news axes and legacy news mode are OFF. Lifecycle exits are never
  delayed by entry-only gates.
- Runtime may not read a futures curve, inventory release, storage, volume,
  open interest, COT, weather, file, API, analyst input, trained output,
  portfolio result, or another EA's signal.

## 7. Trade Management Rules

- One position maximum for magic `412240000` and one consumed attempt per
  normalized broker month.
- Close before renewal, after forty days, on the frozen hard stop, or under
  framework safety action.
- Terminal-global attempt state survives restart; owned deal history supplies
  an independent no-reentry guard. A future-dated tester marker is removed at
  initialization.
- The signal is recomputed only at a genuine month transition. There is no
  intramonth rescore, block adaptation, PnL fit, hedge, averaging, scale-in,
  pyramid, grid, martingale, partial close, or random path.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_history_years` | 10 | [10] | exact prior-year window |
| `strategy_block_years` | 5 | [5] | exact size of both blocks |
| `strategy_signal_epsilon` | 1e-12 | [1e-12] | strict block tie boundary |
| `strategy_history_bars_d1` | 3000 | [3000] | bounded D1 reconstruction |
| `strategy_entry_grace_minutes` | 180 | [180] | first-bar execution guard |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | stale survivor repair |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

Changing the sample, block sizes, endpoint convention, missing-year rule,
arithmetic, epsilon, disagreement condition, recent-block direction, carrier,
hold, stop, spread, or retry state requires a new card and full pipeline run.
No baseline sweep or post-result rescue is authorized.

## Author Claims

The sources document recurring calendar-month commodity information and broad
own-return direction in futures universes that explicitly include crude oil
or WTI. They do not claim a single-WTI chronological sign-reversal premium,
that five-year blocks are optimal, that the recent regime persists, that a
continuous CFD reproduces futures, or that the candidate diversifies QM.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: the sources study broad futures portfolios
while this carrier is one CFD; ten exact years create a long warm-up; the
strict reversal gate may trade too rarely; a detected shift may immediately
reverse; and continuous-CFD rolls, financing, gaps, labels, stops, costs, and
basis can destroy economics.

Retire on zero positions or fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, wrong-month or malformed
endpoints, current-month leakage, incomplete or misassigned blocks, wrong
mean or sign, wrong side, duplicate attempt, missing hard stop, invalid risk
mode, nondeterminism, or later correlation rejection. No rescue or waiver is
permitted.

## Strategy Allowability Check

- [x] R1 reputable: two named-author peer-reviewed papers with DOI, durable
  complete-read repository evidence, and explicit crude-oil/WTI membership;
  exact two-block and CFD translation risk are disclosed.
- [x] R2 mechanical: fixed calendar, endpoints, blocks, arithmetic, reversal,
  side, attempt, stop, spread, and exits.
- [x] R3 testable: registered native `XTIUSD.DWX` D1 carrier.
- [x] R4 compliant: deterministic native arithmetic only; no trained model,
  banned signal indicator, external runtime feed, grid, or martingale.
- [x] Exact/fuzzy dedup has no exact identity; nearest semantic relatives are
  separated by a load-bearing chronological state and direction rule.

## Framework Alignment

- no_trade: exact carrier/ID/slot, frozen inputs, month state, attempt/deal
  guards, history validity, spread, and framework safety gates.
- trade_entry: exact-year same-calendar reconstruction, recent/older block
  means, strict sign reversal, recent-block direction, fixed-risk sizing, and
  frozen ATR stop.
- trade_management: close-before-renew and stale close before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only deterministic magic allocation, one branch-only V5
build, strict compile/Q01, and one non-live paced Q02 handoff if CPU admission
is clear. It authorizes no manual tester action, live/demo/shadow/stress/
optimization preset, terminal control, AutoTrading, `T_Live`, deploy or live
manifest, portfolio-gate mutation, portfolio admission, correlation waiver,
or certification claim.

## Changelog

| date | change |
|---|---|
| 2026-08-30 | Initial source-complete card approved for non-live falsification under the OWNER commodity/energy portfolio mission. |
