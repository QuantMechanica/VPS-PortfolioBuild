---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-MOP-WTI-SAMECAL-MIDHINGE5-2026_S01
variant_id: KELOHARJU-MOP-WTI-SAMECAL-MIDHINGE5-2026_S01
source_id: KELOHARJU-MOP-WTI-SAMECAL-MIDHINGE5-2026
ea_id: QM5_41230
slug: wti-samecal-midhinge5
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41230_wti-samecal-midhinge5_card.md
execution_contract_status: APPROVED
created: 2026-08-30
created_by: Research+Development
last_updated: 2026-08-30
g0_status: APPROVED
g0_decision: decisions/2026-08-30_qm5_41230_wti_same_calendar_midhinge5_g0.md
source_approval: decisions/2026-08-30_wti_same_calendar_midhinge5_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; NIST/SEMATECH"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; NIST/SEMATECH"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, The Journal of Finance 71(4), DOI 10.1111/jofi.12398; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; NIST/SEMATECH e-Handbook of Statistical Methods, DOI 10.18434/M32189."
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
  - type: official_statistical_reference
    citation: "NIST/SEMATECH e-Handbook of Statistical Methods."
    location: "DOI 10.18434/M32189; Measures of Location and Box Plot pages read 2026-08-30"
    quality_tier: A
    role: quartile_middle_fifty_percent_and_tail_resistant_location_context_only
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI exact-five-year same-calendar fixed-midhinge extraction."
    location: "strategy-seeds/sources/KELOHARJU-MOP-WTI-SAMECAL-MIDHINGE5-2026/source.md"
    quality_tier: internal_governed_complete
    role: exact_calendar_endpoints_fixed_hinge_indexes_risk_claim_and_lifecycle
strategy_mechanic: exact-prior-five-year-same-calendar-month-wti-log-returns-ascending-fixed-lower-and-upper-hinge-midpoint-sign-monthly-renewal
sources:
  - "[[sources/KELOHARJU-MOP-WTI-SAMECAL-MIDHINGE5-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/middle-fifty-percent-location]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/five-sample-fixed-midhinge]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, fixed-midhinge, robust-location, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
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
magic: 412300000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "Approximately 10-12 completed WTI positions per full post-warm-up year; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_HINGE_ONLY_AND_SINGLE_CFD_TRANSLATION_RISK
r1_reasoning: "Two complete-read peer-reviewed trading papers support recurring same-calendar commodity information, explicit WTI membership, own-return direction, and monthly renewal. NIST supplies quartile and robust-location context. The exact five-sample hinge-only WTI trading conjunction is an untested QM translation."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform D1-label normalization, exact Y-5..Y-1 endpoints, five-return requirement, ascending sort, fixed hinge indexes 1 and 3, divisor two, epsilon side map, consumed attempt, fixed risk, hard stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered XTIUSD.DWX D1 history covers 2017-2025 and native MT5 state supplies every runtime input. Five-year warm-up, session labels, rolls, financing, gaps, and futures/CFD basis remain binding."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite arithmetic, sorting, averaging, comparisons, ATR risk controls, quotes, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: exact prior five matching-calendar years; all five mandatory; ascending sort; lower hinge index 1; upper hinge index 3; exact divisor two; strict absolute location above 1e-12; 3000 D1 history bars; ATR(20)*3.5 frozen stop; 40-day stale repair; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI recurring-calendar sleeve outside the certified XAU/SP500/NDX/XNG book. Verify normalized completed endpoints, exact five-year membership, ascending sort, fixed hinge indexes, exclusion of median and extremes, divisor two, sign, consumed month, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, uniform_energy_label_normalization, exact_prior_five_year_same_calendar_months, completed_month_endpoints, no_current_month_price, five_of_five_sample, ascending_sort_exactly_five, lower_hinge_index_one, upper_hinge_index_three, median_and_extremes_excluded, divisor_two, strict_sign_epsilon, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-30 and decisions/2026-08-30_qm5_41230_wti_same_calendar_midhinge5_g0.md: R1 passes with two complete peer-reviewed WTI/commodity lineages, official NIST quartile context, and explicit hinge-only/CFD translation risk; R2 locks calendar, endpoints, exact sample, sort, indexes, divisor, side, attempt, risk, stop, spread, and lifecycle; R3 binds the five-year rule to registered WTI D1 history; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found one expected same-calendar family neighbor, and fixed disagreement fixtures prove directional non-equivalence to raw-mean, median, trim, Winsor, shortest-half, and trimean siblings."
---

# QM5_41230 WTI Same-Calendar Five-Sample Fixed Midhinge

## Hypothesis

WTI production, storage, transport, refining, hedging, and demand pressures can
recur in the same named calendar month. A raw multi-year mean can be controlled
by one oil shock, while an ordinary median reads only one observation. This
card tests a deliberately different middle-50% location: average only the
fixed lower and upper hinges of five exact matching-month returns, excluding
both extremes and the median after sorting.

The direct WTI carrier and recurring monthly clock target exposure outside the
certified XAU/SP500/NDX/XNG set. That is a construction objective, not proof
of low correlation, profitability, or CFD/futures equivalence. Q02 owns
activity and baseline economics; unchanged Q09 alone owns realized portfolio
overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-MOP-WTI-SAMECAL-MIDHINGE5-2026/source.md`,
SHA-256
`7B20FBACBA3DC8FF02DF354E6ED966EFB61B37ED82E03CD3D64264EB699AC4FE`,
committed as `b5879eb6b`. Candidate-specific source approval is
`decisions/2026-08-30_wti_same_calendar_midhinge5_source_approval.md`,
SHA-256
`13AB9BA51B57C75D05BC0AF384F3A716F4A391A472266F5C03875C443D03934E`.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
information, explicit crude-oil membership, monthly renewal, and a five-year
history floor. Moskowitz, Ooi, and Pedersen supply explicit WTI membership,
own-return direction, and monthly renewal. NIST supplies quartile,
middle-50%, and tail-resistant-location context. None tests this exact WTI
midhinge conjunction, continuous CFD, or execution contract.

No source or sibling return, alpha, significance, profit factor, drawdown,
trade count, cost, WTI-only result, CFD equivalence, or correlation statistic
transfers. The five-sample hinge convention, epsilon, fixed risk, stop,
spread, and lifecycle are pre-result QM falsification choices.

## Formula

At broker-month decision `(Y,M)`, reconstruct the completed log return for
calendar month `M` in each exact year `Y-5..Y-1`, then sort the five values:

```text
x = sort_ascending(r[Y-5], r[Y-4], r[Y-3], r[Y-2], r[Y-1])

lower_hinge = x[1]
upper_hinge = x[3]
location    = (lower_hinge + upper_hinge) / 2

location > +1e-12 => BUY XTIUSD.DWX
location < -1e-12 => SELL XTIUSD.DWX
otherwise          => FLAT
```

Every endpoint, sort member, hinge index, and divisor is exact. The extremes
and median establish ordering but do not enter the numeric location.
Current-month data, interpolation, raw mean, ordinary median, middle-three
mean, endpoint replacement, trimean, shortest interval, tied-window blend,
pseudomedian, iterative location, score, recency weight, regime gate, and
fallback estimator are forbidden.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_samecal_midhinge5_preallocation_dedup_20260830.json`,
SHA-256
`73AE30B9E4B499FC0D09175B2AC3EF8E95025B27C6620A2FB4203EFE32576802`,
found no exact identity across 4,729 registry identities, 1,367 cards, and 45
Strategy Wiki nodes. It returned only `QM5_20099_wti-samecal` as the expected
fuzzy family neighbor.

- `[-6,-4,-3,+5,+5.5]` makes this card buy from `+0.5`, while raw mean,
  median, middle-three trim, endpoint-Winsor, shortest-half, and trimean
  siblings all sell.
- `[-6,-5,+2,+3,+12]` makes this card sell from `-1`, while raw mean,
  median, and trimean siblings buy.
- `QM5_41055`, `QM5_20099`, `QM5_41199`, `QM5_41201`, `QM5_41202`, and
  `QM5_41204` use median, mean, trim, inclusive-pair pseudomedian,
  endpoint-Winsor, or iterative Huber arithmetic.
- `QM5_41227` preserves chronology inside rolling pair means;
  `QM5_41228` selects a data-dependent shortest interval; and `QM5_41229`
  gives the median half of its final weight. This card always reads only
  fixed sorted indexes `1` and `3`, each at one-half.
- `QM5_20283_wti-trimean-mom` uses twelve adjacent recent monthly returns and
  six even-sample order statistics, not five exact same-calendar-year returns
  and two odd-sample hinges.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FIXED_MIDHINGE_SIGN_MONTHLY_SLEEVE`.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0, intended magic
  `412300000`.
- Decision clock: first executable host tick after a genuine normalized
  broker-month transition.
- Formation: exact matching month in `Y-5..Y-1`; all five returns mandatory.
- Hold: next genuine broker-month boundary; 40 days is survivor repair only.
- Expected cadence after warm-up: approximately ten to twelve positions/year;
  Q02 retires below five in any full scored year.
- Runtime: native D1 history and MT5 execution state only.

## Rules

### Entry Rules

1. Require exact EA ID `41230`, exact `XTIUSD.DWX` D1 host, slot 0,
   registered magic, locked inputs, fixed-risk mode, both current news axes
   OFF, legacy news OFF, and Friday close OFF.
2. Process malformed exposure and prior-month liquidation before entry-only
   gates. Evaluate only after a genuine normalized broker-month transition.
3. Accept one uniform native or `+1` energy D1-label convention. Require the
   normalized current host D1 date to equal broker date and apply the same
   offset to every historical endpoint.
4. Persist current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or submission. Never retry after any outcome.
5. Reconstruct calendar month `M` in exact years `Y-5..Y-1`. Require strict
   adjacent-month completed endpoints, confirming following bars, positive
   finite closes, and all five returns. No substitute year is allowed.
6. Sort exactly five returns ascending. Read lower hinge index `1` and upper
   hinge index `3`; add them and divide exactly by two. Do not numerically
   include index `2`, `0`, or `4`. Reject nonfinite input or output.
7. Buy above `+1e-12`, sell below `-1e-12`, and consume flat inside the
   inclusive epsilon band. Magnitude never changes risk.
8. Require no owned exposure or same-month entry deal, a finite non-crossed
   quote, spread in `[0,1500]` points, completed ATR(20,D1), normalized stop,
   valid volume metadata, and sufficient margin.
9. Apply exactly `RISK_FIXED=1000`, attach a frozen
   `3.5 * ATR(20,D1)` broker stop, and use no target.
10. Open at most one WTI position. Any submission or final-composition defect
    is repaired by closing every owned position.

### Exit Rules

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

### Filters And No-Trade Rules

- Wrong host, period, EA ID, slot, risk mode, locked input, label convention,
  endpoint, exact-year sample, sort, hinge, divisor, epsilon, quote, spread,
  ATR, sizing, margin, or order state consumes the persisted month.
- Both current news axes and legacy news are OFF; no external calendar or
  feed is consulted. Lifecycle repair is never delayed by entry gates.
- Current-month OHLC/volume, contiguous recent momentum, fixed-month
  direction, curve, storage, inventory, event, or portfolio state may not
  enter.

### Trade Management Rules

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
| `strategy_lower_hinge_index` | 1 | fixed zero-based lower hinge |
| `strategy_upper_hinge_index` | 3 | fixed zero-based upper hinge |
| `strategy_midhinge_divisor` | 2 | exact equal-hinge normalization |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair only |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No endpoint, sample, hinge, divisor, epsilon, direction, stop, hold, spread,
or lifecycle sweep is authorized.

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
API, CSV, optimizer artifact, trained output, or manual signal input.

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
| sort, fixed hinges, divisor, epsilon side | trade_entry | deterministic native arithmetic |
| fixed-risk sizing and frozen stop | trade_entry | framework sizing and market request |
| malformed, month, and stale exits | management / close | close owned position only |
| no target, trail, partial, or intramonth signal exit | management | no optional management path |
| news and Friday overrides | no_trade / close | all news OFF; Friday close OFF |

## Reputable-Source Gate Findings

- R1: `PASS_WITH_HINGE_ONLY_AND_SINGLE_CFD_TRANSLATION_RISK`.
- R2: `PASS` for the exact locked mechanical contract.
- R3: `PASS`; five-year warm-up, session-label, and continuous-futures/CFD
  basis risks remain binding Q02 falsification items.
- R4: `PASS`; structural native arithmetic only.

## Falsification And Requalification

Retire or fail on wrong calendar endpoints, current-month leakage, missing
exact years, incorrect sort/hinges/divisor, accidental median inclusion,
wrong sign, fewer than five positions in any full post-warm-up scored year,
nonpositive governed economics, repeated attempts, missing stop, wrong
lifecycle, invalid fixed risk, or nondeterminism. No post-result change to the
sample, statistic, direction, carrier, stop, spread, hold, or retry policy is
allowed.

Passing Q02 would establish only executable baseline evidence. It would not
establish certification, source replication, futures/CFD equivalence,
profitability outside the tested window, or portfolio diversification. Q09
alone may test realized overlap with the existing book.

## Change History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-30 | initial WTI same-calendar five-sample midhinge card | G0 | APPROVED; build pending |
| v2 | 2026-08-30 | exact V5 build, fixed-risk preset, strict compile, and paced baseline enqueue | Q01/Q02 | Q01 PASS; Q02 ENQUEUED_PENDING |

## Approvals

| Gate | Date | Verdict | Evidence |
|---|---|---|---|
| Source Approval | 2026-08-30 | APPROVED_SOURCE | `decisions/2026-08-30_wti_same_calendar_midhinge5_source_approval.md` |
| G0 Research Intake | 2026-08-30 | APPROVED | `decisions/2026-08-30_qm5_41230_wti_same_calendar_midhinge5_g0.md` |
| Q01 Static / Compile | 2026-08-30 | PASS | `D:/QM/reports/work_items/b4168347-7430-4494-8a72-c97485fcd2d1/QM5_41230/COMPILE_EA/compile_evidence.json`; 0 errors, 0 warnings; build check PASS |
| Q02 Baseline | 2026-08-30 | ENQUEUED_PENDING | work item `7d1d8bce-8dec-4d14-acd9-93fa8bfcfb7a`; five-sample CPU average 77.7984%, maximum 86.72%, below 97% ceiling |

## Safety Boundary

This card authorizes one branch-only non-live V5 build, strict compile/Q01,
one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue subject to the CPU
ceiling. It does not authorize a manual tester run, live/demo/shadow/stress/
optimization presets, AutoTrading, `T_Live`, deploy or T_Live manifests,
portfolio-gate edits, portfolio admission, decorrelation claims, or
correlation waivers.
