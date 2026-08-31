---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-SCIPY-WTI-SAMECAL-CAUCHY5-2026_S01
variant_id: KELOHARJU-SCIPY-WTI-SAMECAL-CAUCHY5-2026_S01
source_id: KELOHARJU-SCIPY-WTI-SAMECAL-CAUCHY5-2026
ea_id: QM5_41237
slug: wti-samecal-cauchy5
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41237_wti-samecal-cauchy5_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41237_wti_same_calendar_cauchy5_g0.md
source_approval: decisions/2026-08-31_wti_same_calendar_cauchy5_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; SciPy community"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; SciPy community"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), DOI 10.1111/jofi.12398; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; SciPy community, scipy.optimize.least_squares reference, Cauchy robust loss."
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
    location: "https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.least_squares.html; complete 487-line page reviewed 2026-08-31"
    quality_tier: A_method
    role: cauchy_rho_log_one_plus_z_scale_and_outlier_influence_definition
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI exact-five-year same-calendar fixed-scale Cauchy extraction."
    location: "strategy-seeds/sources/KELOHARJU-SCIPY-WTI-SAMECAL-CAUCHY5-2026/source.md"
    quality_tier: internal_governed_complete
    role: exact_calendar_endpoints_median_mad_weight_update_risk_claim_and_lifecycle
strategy_mechanic: exact-prior-five-year-same-calendar-month-wti-log-returns-odd-median-mad-frozen-scale-cauchy-rational-weight-thirty-two-update-location-sign-monthly-renewal
sources:
  - "[[sources/KELOHARJU-SCIPY-WTI-SAMECAL-CAUCHY5-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/robust-location]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/cauchy-weighted-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, robust-location, cauchy-weighting, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
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
magic: 412370000
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
r1_track_record: PASS_WITH_CAUCHY_CONJUNCTION_AND_SINGLE_CFD_TRANSLATION_RISK
r1_reasoning: "Two complete peer-reviewed trading-paper records support recurring same-calendar commodity information, explicit WTI membership, own-return direction, and monthly renewal. Official SciPy documentation fixes the Cauchy robust loss and scale convention. The exact derivative-weight WTI conjunction is an untested QM translation."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform D1-label normalization, exact Y-5..Y-1 endpoints, five-return requirement, median, MAD, frozen scale, rational weight, exactly 32 updates, epsilon side map, consumed attempt, fixed risk, hard stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_qualification: FIVE_YEAR_WARMUP_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history covers the required five-year warm-up and native MT5 state supplies every runtime input. Session labels, rolls, financing, gaps, and futures/CFD basis remain binding."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, deterministic sorting, absolute deviations, squares, finite arithmetic, ATR risk controls, quotes, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: exact prior five matching-calendar years; all five mandatory; odd median; raw MAD; frozen 1.4826*MAD scale; median initialization; exactly 32 Cauchy rational-weight updates; strict final sign outside 1e-12; 3000 D1 history bars; ATR(20)*3.5 frozen stop; 40-day stale repair; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI recurring-calendar sleeve outside the certified XAU/SP500/NDX/XNG book. Verify normalized completed endpoints, exact five-year membership, median, MAD, frozen scale, rational weights, 32 updates, consumed month, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, uniform_energy_label_normalization, exact_prior_five_year_same_calendar_months, completed_month_endpoints, no_current_month_price, five_of_five_sample, chronological_return_orientation, odd_median, raw_mad, frozen_rescaled_mad, cauchy_rational_weight, exact_32_updates, strict_sign_epsilon, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41237_wti_same_calendar_cauchy5_g0.md: R1 passes with two complete peer-reviewed WTI/commodity lineages and official SciPy Cauchy documentation, with explicit conjunction/CFD translation risk; R2 locks calendar, endpoints, exact sample, median, MAD, scale, weight, update count, epsilon, side, attempt, risk, stop, spread, and lifecycle; R3 binds the five-year rule to registered WTI D1 history; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found expected same-calendar robust-location neighbors, and a fixed fixture proves the opposite side from raw mean, median, bisquare, and Hampel siblings."
---

# QM5_41237 WTI Same-Calendar Cauchy-Weighted Location

## Hypothesis

WTI production, storage, transport, refining, hedging, and demand pressures can
recur in the same named calendar month. A raw historical mean can be dominated
by one oil shock, while compact-support estimators can discard a finite tail
entirely. This card tests whether recurring direction is more useful when all
five exact yearly returns retain positive but rationally decaying Cauchy
weight under one frozen robust scale.

The direct WTI carrier and monthly clock target exposure outside the certified
XAU/SP500/NDX/XNG set. That construction does not prove low correlation,
profitability, or CFD/futures equivalence. Q02 owns activity and baseline
economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-SCIPY-WTI-SAMECAL-CAUCHY5-2026/source.md`,
SHA-256
`858FC0B9A828F87CD9590DA49646864629B9540C77C2390D5D2947BD4B39E2EC`,
committed as `f2cdeefd3`. Candidate-specific source approval is
`decisions/2026-08-31_wti_same_calendar_cauchy5_source_approval.md`, SHA-256
`55C201573F379308E60A1F0784E62B1F341FB240146C1AF866F8868CEF53D5DE`,
committed as `db875341a`.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
information, explicit crude-oil membership, monthly renewal, and a five-year
history floor. Moskowitz, Ooi, and Pedersen supply explicit WTI membership,
own-return direction, and monthly renewal. Official SciPy documentation fixes
`rho(z)=ln(1+z)`, its scale convention, and its outlier-influence purpose.
None tests this exact five-year derivative-weight conjunction, continuous
CFD, or execution contract.

No source or sibling return, alpha, significance, profit factor, drawdown,
trade count, cost, WTI-only result, CFD equivalence, or correlation statistic
transfers. The sample, derivative weight, start, frozen scale, update count,
epsilon, fixed risk, stop, spread, and lifecycle are pre-result QM choices.

## Formula

At broker-month decision `(Y,M)`, reconstruct the completed log return for
calendar month `M` in each exact year `Y-5..Y-1`. Preserve chronological
returns and sort only copies:

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
  weight[i] = 1 / (1 + u[i]^2)
  mu[j+1]   = sum(weight[i] * r[i]) / sum(weight[i])

mu[32] > +1e-12 => BUY XTIUSD.DWX
mu[32] < -1e-12 => SELL XTIUSD.DWX
otherwise        => FLAT
```

Reject nonpositive or nonfinite MAD or scale and every nonfinite intermediate.
The scale freezes before iteration and every one of the 32 updates executes.
There is no convergence stop, alternate start, refit, global search, fallback,
magnitude sizing, or parameter sweep.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_samecal_cauchy5_preallocation_dedup_20260831.json`,
SHA-256
`5841B4C9F78B39C80BB9E5EE57087EF68222BF22ED6DF7F2AC9F4DE270FF35D9`,
found no exact identity across 4,736 registry identities, 1,374 cards, and 45
Strategy Wiki nodes. It returned expected fuzzy same-calendar and robust-
location neighbors.

- `[-0.080,-0.050,-0.001,+0.005,+0.010]` produces Cauchy location
  approximately `+0.001385877861` and this card buys.
- Raw mean, median, trim, Winsor, trimean, midhinge, five-sample bisquare, and
  five-sample Hampel are negative and sell that fixture.
- Bisquare finishes near `-0.001228911486`; Hampel finishes near
  `-0.017078133333`. Sign reflection reverses every strict mapping.
- No existing same-calendar card uses the strictly positive rational weight
  `1/(1+u^2)` with this exact five-year sample, frozen scale, median start,
  and fixed 32-update path.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FROZEN_SCALE_CAUCHY_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0, intended magic
  `412370000`.
- Decision clock: first executable host tick after a genuine normalized
  broker-month transition.
- Formation: exact matching month in `Y-5..Y-1`; all five returns mandatory.
- Hold: next genuine broker-month boundary; 40 days is survivor repair only.
- Expected cadence after warm-up: approximately ten to twelve positions/year;
  Q02 retires below five in any full scored year.
- Runtime: native D1 history and MT5 execution state only.

## Rules

The following sections are the complete locked baseline. There is no
optimization surface and no result-conditioned alternative.

## 4. Entry Rules

1. Require exact EA ID `41237`, exact `XTIUSD.DWX` D1 host, slot 0,
   registered magic, locked inputs, fixed-risk mode, both current news axes
   OFF, legacy news OFF, and Friday close OFF.
2. Process malformed exposure and prior-month liquidation before entry-only
   gates. Evaluate only after a genuine normalized broker-month transition.
3. Accept one uniform native or `+1` energy D1-label convention. Require the
   normalized current D1 date to equal broker date and apply the same offset
   to every historical endpoint.
4. Persist current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or submission. Never retry after any outcome.
5. Reconstruct calendar month `M` in exact years `Y-5..Y-1`. Require strict
   adjacent-month completed endpoints, confirming following bars, positive
   finite closes, and all five returns. No substitute year is allowed.
6. Sort a copy of exactly five returns and read median index `2`. Sort their
   five absolute deviations from that median and read raw MAD index `2`.
   Reject nonpositive or nonfinite MAD.
7. Freeze `scale=1.4826*MAD`. Starting from the median, execute exactly 32
   updates over the original five returns using `u=(r-mu)/scale` and
   `w=1/(1+u^2)`. Reject any nonfinite state or nonpositive weight sum.
8. Buy only when final location exceeds `+1e-12`; sell only below `-1e-12`;
   consume flat otherwise. Magnitude never changes risk.
9. Require no owned exposure or same-month entry deal, a finite non-crossed
   quote, spread in `[0,1500]` points, completed ATR(20,D1), normalized stop,
   valid volume metadata, and sufficient margin.
10. Apply exactly `RISK_FIXED=1000`, attach a frozen
    `3.5 * ATR(20,D1)` broker stop, and use no target. Open at most one WTI
    position; repair any final-composition defect by closing owned exposure.

## 5. Exit Rules

1. At the first processed host D1 bar of the next normalized broker month,
   close the old position before evaluating a replacement.
2. Close after 40 elapsed calendar days as final survivor repair.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time owned exposure.
4. The broker hard stop, framework kill switch, and framework close helper
   remain authoritative.
5. Friday close is disabled because the structural monthly hold spans
   weekends.
6. There is no intramonth signal exit, target, trail, break-even, partial
   close, scale-in, grid, martingale, pyramid, stop-and-reverse, or
   discretionary exit.

## 6. Filters (No-Trade Module)

- Wrong host, period, EA ID, slot, risk mode, locked input, label convention,
  endpoint, exact-year sample, median, MAD, scale, weight, update count,
  epsilon, quote, spread, ATR, sizing, margin, or order state consumes the
  persisted month.
- Both current news axes and legacy news are OFF; no external calendar or feed
  is consulted. Lifecycle repair is never delayed by entry gates.
- Current-month OHLC/volume, contiguous recent momentum, fixed-month
  direction, curve, storage, inventory, event, or portfolio state may not
  enter.

## 7. Trade Management Rules

- Every tick begins with framework MAE tracking before any guard can return.
- Malformed, cross-month, and stale repair runs before entry-only gates and
  remains retryable until owned exposure is flat.
- Maintain at most one exact-symbol, exact-magic WTI position; never manage a
  manual or another EA's trade.
- The entry hard stop never moves. Signal changes do not alter an open
  position inside the month.
- Persist the consumed-month ledger in terminal-global state so restart
  cannot create a second attempt. Tester initialization clears stale
  prior-run state.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 5 | exact prior matching-calendar years |
| `strategy_history_bars_d1` | 3000 | bounded endpoint reconstruction |
| `strategy_scale_multiplier` | 1.4826 | raw-MAD consistency multiplier |
| `strategy_cauchy_iterations` | 32 | exact fixed update count |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair only |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No endpoint, sample, median, MAD, scale, curve, update count, epsilon,
direction, stop, hold, spread, or lifecycle sweep is authorized.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen broker hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target, signal-magnitude sizing, risk renewal, or compounding override.
- Invalid price, stop distance, tick value, tick size, volume step, minimum
  volume, lot, margin, or quote consumes the month.
- This card creates no live, demo, shadow, stress, or optimization preset.

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
| median, MAD, frozen scale and 32 Cauchy updates | trade_entry | deterministic native arithmetic |
| fixed-risk sizing and frozen stop | trade_entry | framework sizing and market request |
| malformed, month, and stale exits | management / close | close owned position only |
| no target, trail, partial, or intramonth signal exit | management | no optional management path |
| news and Friday overrides | no_trade / close | all news OFF; Friday close OFF |

## Reputable-Source Gate Findings

- R1: `PASS_WITH_CAUCHY_CONJUNCTION_AND_SINGLE_CFD_TRANSLATION_RISK`.
- R2: `PASS` for the exact locked mechanical contract.
- R3: `PASS`; five-year warm-up, session-label, and continuous-futures/CFD
  basis risks remain binding Q02 falsification items.
- R4: `PASS`; structural native arithmetic only.

## Falsification And Requalification

Retire or fail on wrong calendar endpoints, current-month leakage, missing
exact years, incorrect return orientation, median, MAD, scale, rational
weight, update count, epsilon, wrong sign, fewer than five positions in any
full post-warm-up scored year, nonpositive governed economics, repeated
attempts, missing stop, wrong lifecycle, invalid fixed risk, or
nondeterminism. No post-result change to the sample, estimator, direction,
carrier, stop, spread, hold, or retry policy is allowed.

Passing Q02 would establish only executable baseline evidence. It would not
establish certification, source replication, futures/CFD equivalence,
profitability outside the tested window, or portfolio diversification. Q09
alone may test realized overlap with the existing book.

## Change History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-31 | initial WTI same-calendar Cauchy-location card | G0 | APPROVED; build pending |

## Approvals

| Gate | Date | Verdict | Evidence |
|---|---|---|---|
| Source Approval | 2026-08-31 | APPROVED_SOURCE | `decisions/2026-08-31_wti_same_calendar_cauchy5_source_approval.md` |
| G0 Research Intake | 2026-08-31 | APPROVED | `decisions/2026-08-31_qm5_41237_wti_same_calendar_cauchy5_g0.md` |
| Q01 Static / Compile | 2026-08-31 | NOT_BUILT | deterministic magic allocation and build pending |
| Q02 Baseline | 2026-08-31 | NOT_ENQUEUED_Q01_PENDING | compile and governed CPU check pending |

## Safety Boundary

This card authorizes one branch-only non-live V5 build, strict compile/Q01,
one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue subject to the CPU
ceiling. It does not authorize a manual tester run, live/demo/shadow/stress/
optimization presets, AutoTrading, `T_Live`, deploy or T_Live manifests,
portfolio-gate edits, portfolio admission, decorrelation claims, or
correlation waivers.
