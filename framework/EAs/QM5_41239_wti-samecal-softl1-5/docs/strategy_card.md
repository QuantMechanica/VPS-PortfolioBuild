---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-SCIPY-WTI-SAMECAL-SOFTL1-2026_S01
variant_id: KELOHARJU-SCIPY-WTI-SAMECAL-SOFTL1-2026_S01
source_id: KELOHARJU-SCIPY-WTI-SAMECAL-SOFTL1-2026
ea_id: QM5_41239
slug: wti-samecal-softl1-5
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41239_wti-samecal-softl1-5_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41239_wti_same_calendar_soft_l1_5_g0.md
source_approval: decisions/2026-08-31_wti_same_calendar_soft_l1_5_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; SciPy community"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; SciPy community"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), DOI 10.1111/jofi.12398; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; SciPy community, scipy.optimize.least_squares reference, soft-L1 robust loss."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete-read parent packet strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_commodity_information_crude_oil_membership_and_five_year_floor
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read parent packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: explicit_wti_membership_own_return_direction_and_monthly_lifecycle
  - type: official_statistical_documentation
    citation: "SciPy community. scipy.optimize.least_squares reference documentation."
    location: "Previously approved complete page reviewed 2026-08-31; retrieval SHA-256 CD8BCEEF256035736DDDE8E0F690C2487EFEFD5AFA773AEB50C822E5AF632435; fresh route deferred by source policy"
    quality_tier: A_method
    role: soft_l1_rho_square_root_scale_and_reduced_tail_influence_definition
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI exact-five-year same-calendar fixed-scale soft-L1 extraction."
    location: "strategy-seeds/sources/KELOHARJU-SCIPY-WTI-SAMECAL-SOFTL1-2026/source.md"
    quality_tier: internal_governed_complete
    role: exact_calendar_endpoints_median_mad_weight_update_risk_claim_and_lifecycle
strategy_mechanic: exact-prior-five-year-same-calendar-month-wti-log-returns-odd-median-mad-frozen-scale-soft-l1-square-root-weight-thirty-two-update-location-sign-monthly-renewal
sources:
  - "[[sources/KELOHARJU-SCIPY-WTI-SAMECAL-SOFTL1-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/robust-location]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/soft-l1-weighted-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, robust-location, soft-l1-weighting, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 412390000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "Approximately 10-12 completed WTI positions per full post-warm-up year; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SOFT_L1_CONJUNCTION_AND_SINGLE_CFD_TRANSLATION_RISK
r1_reasoning: "Two complete peer-reviewed trading-paper records support recurring same-calendar commodity information, explicit WTI membership, own-return direction, and monthly renewal. A previously approved complete SciPy documentation record fixes the soft-L1 loss and scale convention. The exact derivative-weight WTI conjunction is an untested QM translation."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform D1-label normalization, exact Y-5..Y-1 endpoints, five-return requirement, median, MAD, frozen scale, square-root weight, exactly 32 updates, epsilon side map, consumed attempt, fixed risk, hard stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_qualification: FIVE_YEAR_WARMUP_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history covers the required five-year warm-up and native MT5 state supplies every runtime input. Session labels, rolls, financing, gaps, and futures/CFD basis remain binding."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, deterministic sorting, absolute deviations, squares, square roots, finite arithmetic, ATR risk controls, quotes, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: exact prior five matching-calendar years; all five mandatory; odd median; raw MAD; frozen 1.4826*MAD scale; median initialization; exactly 32 soft-L1 square-root-weight updates; strict final sign outside 1e-12; 3000 D1 history bars; ATR(20)*3.5 frozen stop; 40-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED_PENDING
force_build: true
review_focus: "Falsify a direct-WTI recurring-calendar sleeve outside the certified XAU/SP500/NDX/XNG book. Verify normalized completed endpoints, exact five-year membership, median, MAD, frozen scale, square-root weights, 32 updates, consumed month, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, uniform_energy_label_normalization, exact_prior_five_year_same_calendar_months, completed_month_endpoints, no_current_month_price, five_of_five_sample, chronological_return_orientation, odd_median, raw_mad, frozen_rescaled_mad, soft_l1_square_root_weight, exact_32_updates, strict_sign_epsilon, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41239_wti_same_calendar_soft_l1_5_g0.md: R1 passes with two complete peer-reviewed WTI/commodity lineages and an approved complete SciPy soft-L1 record, with explicit conjunction/CFD translation risk; R2 locks calendar, endpoints, exact sample, median, MAD, scale, weight, update count, epsilon, side, attempt, risk, stop, spread, and lifecycle; R3 binds the five-year rule to registered WTI D1 history; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found expected same-calendar robust-location neighbors, and fixed fixtures prove opposite sides from Cauchy, arctangent, median, and raw-mean siblings."
---

# QM5_41239 WTI Same-Calendar Soft-L1 Location

## Hypothesis

At each genuine WTI broker-month transition into `(Y,M)`, the robust center
of WTI's completed return for the same named month in exact years `Y-5..Y-1`
may contain recurring directional information. This candidate follows the
strict sign of a five-observation soft-L1 location for one month.

This is a direct WTI structural diversification candidate outside the
certified XAU/SP500/NDX/XNG carrier set. It is not evidence of low
correlation, portfolio value, or profitability. Only unchanged downstream
Q09 may establish realized overlap.

## Source Traceability And Claim Boundary

Keloharju, Linnainmaa, and Nyberg support recurring same-calendar commodity
information, explicit crude-oil membership, monthly renewal, and a five-year
history floor. Moskowitz, Ooi, and Pedersen support WTI membership,
own-return direction, and monthly renewal. The approved complete SciPy page
fixes `rho(z)=2*(sqrt(1+z)-1)` and `C^2*rho(f^2/C^2)`.

No source tests this single-WTI, five-return, fixed-scale derivative-weight
conjunction or a continuous Darwinex CFD. Median initialization, MAD scale,
32 updates, epsilon, ATR stop, spread cap, fixed-dollar risk, attempt state,
and lifecycle are disclosed QM choices. No source performance or correlation
result transfers.

The candidate-specific source approval is
`decisions/2026-08-31_wti_same_calendar_soft_l1_5_source_approval.md`. The
bounded packet is
`strategy-seeds/sources/KELOHARJU-SCIPY-WTI-SAMECAL-SOFTL1-2026/source.md`.

## Formula

For the five chronological returns `r[0]..r[4]`:

```text
s      = sort_ascending(copy(r))
median = s[2]
d[i]   = abs(r[i] - median)
a      = sort_ascending(copy(d))
MAD    = a[2]
scale  = 1.4826 * MAD

mu[0] = median
for j = 0..31:
  u[i]      = (r[i] - mu[j]) / scale
  weight[i] = 1 / sqrt(1 + u[i]^2)
  mu[j+1]   = sum(weight[i] * r[i]) / sum(weight[i])
```

The weight is `rho'(u^2)` for SciPy's documented soft-L1 loss. Buy only when
`mu[32] > +1e-12`, sell only when `mu[32] < -1e-12`, and consume the month
flat in the inclusive band or on any invalid arithmetic.

## Non-Duplicate Decision

The corrected canonical receipt
`artifacts/qm5_wti_samecal_softl1_5_preallocation_dedup_20260831.json`,
SHA-256
`0ECF970B9E8EB577F9EE375CF8D8E8881BA1DE6141C6E7B8F9667C45C01FD006`,
found no exact identity across 4,738 registry rows, 1,376 cards, and 45
Strategy Wiki nodes. Expected same-calendar and robust-location fuzzy matches
were manually resolved.

On sorted `[-0.120,-0.075,-0.020,+0.115,+0.120]`, the locked soft-L1 path
finishes near `+0.001324252685` and buys. The otherwise matched Cauchy path
finishes near `-0.004100768370`, arctangent near `-0.004348219120`, and the
median is `-0.020`; all three sell. Soft-L1's
`1/sqrt(1+u^2)` weight therefore changes actual participation relative to
Cauchy's `1/(1+u^2)` and arctangent's `1/(1+u^4)` rather than renaming a
parameter. A second fixture makes soft-L1 sell while raw mean buys.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FROZEN_SCALE_SOFT_L1_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1 for execution, history, ATR, and month clock.
- Slot: 0; deterministic magic `412390000`.
- At most one attempt and one position per normalized broker month.
- Expected pre-result cadence: approximately 10-12 positions per full
  post-warm-up year; fewer than five in any full scored year retires the card.

## Rules

### Entry Rules

1. Run only on exact `XTIUSD.DWX`, D1, EA `41239`, slot 0, registered magic.
2. On the first executable D1 tick after a genuine normalized month change,
   repair malformed owned exposure and close the preceding month's package.
3. Persist the new `yyyymm` attempt before history, signal, news, spread,
   quote, ATR, sizing, or order submission. Never retry that month.
4. Apply one uniform native or `+1` energy D1-label convention to the whole
   history buffer. Mixed per-endpoint normalization is forbidden.
5. For each exact year `Y-5..Y-1`, reconstruct
   `ln(target_month_last_close / prior_month_last_close)`. Require adjacent
   month keys, a later confirming bar, positive finite prices, and all five
   returns. Do not substitute years or use current-month data.
6. Compute the formula above with odd median, raw MAD, frozen
   `1.4826*MAD`, median start, and exactly 32 updates. Any nonpositive scale,
   nonfinite square, root, weight, sum, or location consumes the month flat.
7. Buy strictly above `+1e-12`; sell strictly below `-1e-12`; equality or the
   inclusive epsilon band stays flat.
8. After quote and spread checks, attach one frozen
   `3.5 * ATR(20,D1)` broker hard stop, size through V5 fixed-risk sizing,
   and submit one market request with no target.

### Exit Rules

1. Framework kill switch or close-only instruction has first precedence.
2. Close duplicate, wrong-symbol, wrong-side, wrong-magic, stopless, or
   invalid-metadata owned exposure immediately.
3. Preserve the broker hard stop.
4. Close on the first executable D1 tick of the next normalized broker month.
5. Close after 40 elapsed calendar days only as survivor repair.
6. No intramonth signal exit, target, trail, break-even, partial close, or
   stop-and-reverse.

### Filters (No-Trade Module)

- Fail closed on identity, timeframe, registry, risk-mode, or history error.
- Current news axes and legacy news mode are OFF.
- Friday flattening is OFF because the source-aligned hold spans weekends.
- Reject negative/crossed spread and positive spread above 1,500 points.
- Reject invalid bid/ask, ATR, stop distance, tick value, tick size, volume
  step, volume minimum, margin, or fixed-risk lot.
- No event, inventory, storage, curve, carry, volume, volatility-regime,
  external-feed, portfolio-state, or prior-result gate.

### Trade Management Rules

- Own at most one exact-symbol, exact-magic position.
- Do not modify the frozen initial stop except framework emergency close.
- Do not scale in, pyramid, grid, martingale, hedge, trail, break even,
  partially close, or size by signal magnitude.
- The attempt remains consumed even when any later entry gate fails.

## Parameters To Test

One locked baseline only:

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_history_years` | 5 | exact prior matching-calendar years |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_scale_multiplier` | 1.4826 | frozen raw-MAD scale |
| `strategy_soft_l1_iterations` | 32 | exact reweighting count |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair |
| `strategy_max_spread_points` | 1500 | entry cost ceiling |

No lookback, scale, update, threshold, side, stop, hold, spread, or lifecycle
sweep is authorized.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen broker hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target, signal-magnitude sizing, risk renewal, or compounding override.
- Invalid price, stop, metadata, lot, or margin consumes the month.
- No live, demo, shadow, stress, or optimization preset.

## Runtime Data Dependencies

Native `XTIUSD.DWX` D1 OHLC/timestamps, broker clock, symbol quotes and
properties, positions, deals, and terminal-global attempt state only. No
contract chain, curve, inventory, storage, volume, open interest, event feed,
API, CSV, numerical library, optimizer artifact, trained output, or manual
signal input.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- Framework kill switch, fixed-risk sizing, magic resolution, MAE tracking,
  and owned-position isolation remain mandatory.

## Exit Precedence

1. Framework kill switch or close-only instruction.
2. Duplicate, wrong-symbol, wrong-side, stopless, or invalid-metadata repair.
3. Per-position broker hard stop.
4. New normalized broker-month exit.
5. Forty-day survivor repair.
6. New entry only when flat and the current month is not already consumed.

## Framework Alignment

| Card rule | V5 module | Required implementation |
|---|---|---|
| exact host, D1, EA, slot, risk and locked contract | no_trade | fail closed before signal entry |
| normalized month clock and persistent attempt | no_trade / trade_entry | consume once before fallible gates |
| exact-year endpoint reconstruction | trade_entry | bounded completed D1 history only |
| median, MAD, frozen scale and 32 soft-L1 updates | trade_entry | deterministic native arithmetic |
| fixed-risk sizing and frozen stop | trade_entry | framework sizing and market request |
| malformed, month, and stale exits | management / close | close owned position only |
| no target, trail, partial, or intramonth signal exit | management | no optional management path |
| news and Friday overrides | no_trade / close | all news OFF; Friday close OFF |

## Reputable-Source Gate Findings

- R1: `PASS_WITH_SOFT_L1_CONJUNCTION_AND_SINGLE_CFD_TRANSLATION_RISK`.
- R2: `PASS` for the exact locked mechanical contract.
- R3: `PASS`; five-year warm-up, session-label, and continuous-futures/CFD
  basis risks remain binding Q02 falsification items.
- R4: `PASS`; structural native arithmetic only.

## Falsification And Requalification

Retire or fail on wrong calendar endpoints, current-month leakage, missing
exact years, incorrect return orientation, median, MAD, scale, square-root
weight, update count, epsilon, wrong sign, fewer than five positions in any
full post-warm-up scored year, nonpositive governed economics, repeated
attempts, missing stop, wrong lifecycle, invalid fixed risk, or
nondeterminism. No post-result change to the sample, estimator, direction,
carrier, stop, spread, hold, or retry policy is allowed.

Passing Q02 establishes only executable baseline evidence. It does not
establish certification, source replication, futures/CFD equivalence,
profitability outside the tested window, or portfolio diversification. Q09
alone may test realized overlap with the existing book.

## Change History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-31 | initial WTI same-calendar soft-L1 location card | G0 | APPROVED; Q01 PASS; Q02 enqueued pending |

## Approvals

| Gate | Date | Verdict | Evidence |
|---|---|---|---|
| Source Approval | 2026-08-31 | APPROVED_SOURCE | `decisions/2026-08-31_wti_same_calendar_soft_l1_5_source_approval.md` |
| G0 Research Intake | 2026-08-31 | APPROVED | `decisions/2026-08-31_qm5_41239_wti_same_calendar_soft_l1_5_g0.md` |
| Q01 Static / Compile | 2026-08-31 | PASS | `e34531d1-f2c4-4444-96b9-eef792928f1a`; zero errors and warnings |
| Q02 Baseline | 2026-08-31 | ENQUEUED_PENDING | `5ca5cc87-bd67-40fe-9970-0e382ba53155`; CPU ceiling clear |

## Safety Boundary

This card authorizes one branch-only non-live V5 build, strict compile/Q01,
one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue subject to the
CPU ceiling. It does not authorize a manual tester run, live/demo/shadow/
stress/optimization presets, AutoTrading, `T_Live`, deploy or T_Live
manifests, portfolio-gate edits, portfolio admission, decorrelation claims,
or correlation waivers.
