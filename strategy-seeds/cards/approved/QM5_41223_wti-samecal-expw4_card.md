---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026_S01
variant_id: KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026_S01
source_id: KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026
ea_id: QM5_41223
slug: wti-samecal-expw4
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41223_wti-samecal-expw4_card.md
execution_contract_status: APPROVED
created: 2026-08-30
created_by: Research+Development
last_updated: 2026-08-30
g0_status: APPROVED
g0_decision: decisions/2026-08-30_qm5_41223_wti_same_calendar_exponential_weight_g0.md
source_approval: decisions/2026-08-30_wti_same_calendar_exponential_weight_source_approval.md
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
    citation: "QuantMechanica bounded WTI same-calendar four-year exponential-weight extraction."
    location: "strategy-seeds/sources/KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026/source.md"
    quality_tier: internal_governed
    role: exact_calendar_endpoints_uncompressed_year_ages_decay_kernel_risk_and_lifecycle
strategy_mechanic: exact-up-to-ten-prior-year-same-calendar-month-wti-log-returns-fixed-base-two-four-calendar-year-half-life-uncompressed-year-age-normalized-weighted-mean-sign-monthly-renewal
sources:
  - "[[sources/KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/time-series-direction]]"
  - "[[concepts/exponential-recency-weighting]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/fixed-exponential-year-weight]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, exponential-recency-weighting, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 412230000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "Approximately 10-12 completed WTI monthly positions per full post-warm-up year; only exact-zero or invalid weighted states consume flat."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_DECAY_AND_SINGLE_CARRIER_CFD_TRANSLATION_RISK
r1_reasoning: "Complete peer-reviewed sources explicitly cover same-calendar commodities, crude oil/WTI membership, own-return direction, and monthly renewal; governed arithmetic fixes base-two decay. The exact conjunction and four-year half-life remain untested."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform normalized endpoints, exact Y-1..Y-10 ages, missing-year treatment, five-observation floor, base, exponent, half-life, normalization, side, consumed attempt, fixed risk, hard stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_qualification: LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history and native MT5 state supply every runtime input; five-year warm-up, session labels, rolls, financing, and futures/CFD basis remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, fixed powers, multiplication, addition, division, comparisons, ATR risk controls, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: prior 10-year exact same-calendar search cap; minimum 5 observations; exact year age k-1 without missing-year compression; base 2; four-year half-life; normalized weighted mean; strict sign epsilon 1e-12; 3000 D1 history bars; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a monthly WTI same-calendar sleeve whose fixed calendar-year decay changes information influence and can reverse the existing equal-weight seasonal signal. Verify normalized completed endpoints, exact-year ages, missing-year noncompression, base-two weights, four-year half-life, normalized sign, consumed month, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized independence."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, uniform_energy_label_normalization, exact_prior_year_same_calendar_months, completed_month_endpoints, no_current_month_price, five_sample_floor, ten_year_cap, exact_calendar_year_age, missing_year_no_age_compression, fixed_base_two, four_year_half_life, positive_finite_weights, normalized_weighted_mean, strict_sign_epsilon, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-30 and decisions/2026-08-30_qm5_41223_wti_same_calendar_exponential_weight_g0.md: R1 passes with two complete peer-reviewed WTI/commodity lineages plus governed fixed-decay arithmetic and explicit conjunction risk; R2 locks calendar, endpoints, exact ages, missing-year handling, sample, kernel, normalization, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with warm-up/session/CFD risk; R4 is deterministic native arithmetic only. Corrected-root canonical dedup finds no exact identity; manual review and a fixed opposite-side fixture separate equal-weight same-calendar, contiguous-month exponential trend, Huber, t-score, and sign-score neighbors."
---

# QM5_41223 WTI Same-Calendar Four-Year Exponential-Weight Seasonality

## Hypothesis

WTI demand, storage, production, refinery, transport, hedging, and
capital-allocation pressures can recur in the same calendar month, but the
direction associated with those pressures can change as technology, policy,
trade routes, and producer behavior evolve. A fixed recency kernel over exact
prior-year occurrences tests whether recent seasonal regimes deserve more
influence than stale occurrences without fitting the decay to outcomes.

This is a direct crude-oil structural sleeve outside the certified
XAU/SP500/NDX/XNG carrier set. Different carrier and information clock do not
prove low realized correlation. Q02 owns activity and baseline economics;
unchanged Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026/source.md`. It
was committed after the durable source approval
`decisions/2026-08-30_wti_same_calendar_exponential_weight_source_approval.md`.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity-
return information, explicit crude-oil membership, monthly renewal, and a
five-year history floor. Moskowitz, Ooi, and Pedersen supply WTI membership,
own-return direction, and monthly renewal. The governed exponential-weight
packet supplies only deterministic base-two weight arithmetic and explicitly
records that the source paper does not prescribe the kernel.

None tests the exact same-calendar/year-decay conjunction, four-year
half-life, Darwinex history, fixed risk, ATR stop, spread cap, or current
book. No source or sibling return, alpha, significance, profit factor,
drawdown, trade count, cost, CFD equivalence, or correlation statistic
transfers. The half-life is a pre-result QM falsification choice, not a fitted
or source-claimed optimum.

## Non-Duplicate Decision

The corrected-root checker scanned 4,722 registry identities, 1,360 card
files, and all 45 current Strategy Wiki nodes. It found no exact identity and
returned one expected fuzzy neighbor. Manual mechanic review fixes the
boundary:

- `QM5_20099_wti-samecal` gives each valid historical occurrence equal
  influence. This card uses uncompressed calendar-year exponential decay.
- `QM5_20279_wti-expw-mom` weights twelve contiguous completed monthly
  returns with a three-month half-life. This card observes only matching
  calendar months across years and uses a four-year half-life.
- `QM5_41204_wti-samecal-huber10` uses median/MAD scale and iterative robust
  weights unrelated to observation age.
- `QM5_41211_wti-samecal-tstat` uses an equal-weight mean and sample variance
  confidence band; this card neither estimates variance nor abstains on
  confidence.
- `QM5_41212_wti-samecal-signscore` discards magnitudes into equal binary
  signs; this card retains metric returns and changes influence by year age.

For recent-to-old exact-year returns
`[-0.04,-0.04,-0.04,+0.03,+0.03,+0.03,+0.03,+0.03,+0.03,+0.03]`, the
equal-weight mean is `+0.009` and `QM5_20099` buys. This card's locked
four-year-half-life weighted sum is negative, so it sells. The disagreement
is executable and load bearing rather than a parameter rename.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_EXPONENTIAL_YEAR_DECAY_DIRECTION`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; magic `412230000`.
- Decision clock: first processed D1 bar after a genuine normalized
  broker-month transition.
- Formation: up to ten exact prior-year returns for the upcoming calendar
  month; minimum five valid observations.
- Holding clock: next genuine normalized broker-month boundary, with a
  forty-calendar-day stale guard.
- Expected cadence: ten to twelve positions per full post-warm-up year;
  retire below five observed positions.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and framework state only.

## Rules

At decision month `(Y,M)`, reconstruct WTI's completed return for calendar
month `M` in each exact prior year `Y-k`, `k=1..10`:

```text
r_k = ln(close_at_end_of_month(Y-k,M) /
         close_at_end_of_previous_month(Y-k,M))
age_k = k - 1
w_k = 2 ^ (-age_k / 4.0)
weighted_mean = sum(w_k*r_k) / sum(w_k)
```

Require strict adjacent-month endpoints, a confirming following D1 bar,
positive finite closes, finite returns, at least five valid years, positive
finite weights, and a positive finite weight total. Missing years are skipped
without replacement and do not compress older year ages. No price from the
current decision month enters the signal.

Buy when `weighted_mean > +1e-12`. Sell when
`weighted_mean < -1e-12`. Equality or invalid state consumes the month flat.
Renew at the next month boundary. Signal magnitude never changes risk.

## 4. Entry Rules

1. Require exact EA ID `41223`, `XTIUSD.DWX` D1, slot 0, and every baseline
   input locked to the values below.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine normalized broker-month transition.
3. Persist the current month before history, signal, spread, quote, news,
   stop, sizing, or order checks. A flat, rejected, failed, stopped, or
   blocked outcome cannot retry that month.
4. Reject owned exposure or any owned entry deal already recorded in the
   current broker month.
5. Copy no more than 3,000 completed D1 bars. Under one uniform native or
   `+1` label convention, reconstruct exact calendar-month returns at lags
   one through ten and require at least five valid values.
6. Map lag `k` to age `k-1` even when more recent years are missing. Compute
   base-two weights with the fixed four-year half-life, normalize the weighted
   sum, and apply the strict `1e-12` sign rule.
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
  entry deal, insufficient history, mixed label convention, malformed
  endpoint, current-month leakage, nonpositive close, invalid logarithm,
  invalid age/weight/normalization, inclusive epsilon tie, invalid ATR/quote/
  point metadata, crossed quote, negative spread, or excessive spread.
- Q02 freezes both news axes and legacy news mode OFF. Lifecycle exits are not
  delayed by entry-only gates.
- Runtime may not read a futures curve, inventory release, volume, open
  interest, COT, file, API, analyst input, trained output, portfolio result,
  or another EA's signal.

## 7. Trade Management Rules

- One position maximum for magic `412230000` and one consumed attempt per
  normalized broker month.
- Close before renewal, after forty days, on the frozen hard stop, or under
  framework safety action.
- Terminal-global attempt state survives restart; owned deal history supplies
  an independent no-reentry guard. A future-dated tester marker is removed at
  initialization.
- The signal is recomputed only at a genuine month transition. There is no
  intramonth rescore, half-life adaptation, PnL fit, hedge, averaging,
  scale-in, pyramid, grid, martingale, partial close, or random path.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_history_years` | 10 | [10] | exact prior-year search cap |
| `strategy_min_observations` | 5 | [5] | minimum valid calendar returns |
| `strategy_half_life_years` | 4.0 | [4.0] | fixed base-two year-age decay |
| `strategy_signal_epsilon` | 1e-12 | [1e-12] | strict flat boundary |
| `strategy_history_bars_d1` | 3000 | [3000] | bounded D1 reconstruction |
| `strategy_entry_grace_minutes` | 180 | [180] | first-bar execution guard |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | stale survivor repair |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

Changing the sample cap or floor, endpoint convention, missing-year age,
base, half-life, normalization, epsilon, direction, hold, stop, carrier,
spread cap, or retry state requires a new card and full pipeline run. No
baseline sweep or post-result rescue is authorized.

## Author Claims

The sources document recurring calendar-month commodity information and broad
own-return direction in futures universes that explicitly include crude oil
or WTI. They do not claim that year-age exponential weighting improves a
single-WTI rule, that four years is an optimal half-life, that a continuous
CFD reproduces futures, or that the candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: the source portfolios are broad while
this carrier is one CFD; same-calendar history is sparse; recent extreme
years receive more influence; continuous-CFD rolls, financing, gaps, labels,
stops, source decay, and execution costs can destroy economics; and WTI can
still correlate with XNG or risk assets.

Retire on zero positions or fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, wrong-month or malformed
endpoints, current-month leakage, compressed missing-year age, wrong weight
or half-life, wrong normalization or side, duplicate attempt, missing hard
stop, invalid risk mode, nondeterminism, or later correlation rejection. No
rescue or waiver is permitted.

## Strategy Allowability Check

- [x] R1 reputable: two named-author peer-reviewed papers with DOI, durable
  complete-read repository evidence, and explicit crude-oil/WTI membership;
  exact composite-decay and CFD translation risk are disclosed.
- [x] R2 mechanical: fixed calendar, endpoints, year ages, missing-year rule,
  sample, base, half-life, normalization, side, attempt, stop, spread, and
  exits.
- [x] R3 testable: registered native `XTIUSD.DWX` D1 carrier.
- [x] R4 compliant: deterministic native arithmetic only; no trained model,
  banned signal indicator, external runtime feed, grid, or martingale.
- [x] Exact/fuzzy dedup has no exact identity; every nearest semantic
  relative is separated by a load-bearing state or weighting rule.

## Framework Alignment

- no_trade: exact carrier/ID/slot, frozen inputs, month state, attempt/deal
  guards, history validity, spread, and framework safety gates.
- trade_entry: exact-year same-calendar reconstruction, uncompressed age,
  fixed base-two four-year weights, normalized sign, fixed-risk sizing, and
  frozen ATR stop.
- trade_management: close-before-renew and stale close before entry-only
  gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only deterministic identity and magic allocation, one
branch-only V5 build, strict compile/Q01, and one non-live paced Q02 handoff
when the CPU ceiling is clear. It does not authorize a manual backtest; live,
demo, shadow, optimization, or stress setfile; AutoTrading; `T_Live`; deploy
or live manifest; portfolio admission; portfolio-gate edit; correlation
waiver; or certification claim.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-30 | initial source-bounded WTI same-calendar year-decay card | G0 | APPROVED |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-30 | APPROVED | `decisions/2026-08-30_qm5_41223_wti_same_calendar_exponential_weight_g0.md` |
| Q01 Compile / Static Validation | - | NOT_BUILT | governed magic allocation and build pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | pending Q01 PASS |
