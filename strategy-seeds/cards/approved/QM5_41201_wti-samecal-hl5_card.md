---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-HL-WTI-SAMECAL5-2026_S01
variant_id: KELOHARJU-HL-WTI-SAMECAL5-2026_S01
source_id: KELOHARJU-HL-WTI-SAMECAL5-2026
ea_id: QM5_41201
slug: wti-samecal-hl5
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41201_wti-samecal-hl5_card.md
execution_contract_status: APPROVED
created: 2026-08-29
created_by: Research+Development
last_updated: 2026-08-29
g0_status: APPROVED
g0_decision: decisions/2026-08-29_qm5_41201_wti_same_calendar_hodges_lehmann5_g0.md
source_approval: decisions/2026-08-29_wti_same_calendar_hodges_lehmann5_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), 1557-1590, DOI 10.1111/jofi.12398; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; governed inclusive-pair Hodges-Lehmann-style arithmetic."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete-read packet strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_return_information_crude_oil_membership_and_five_year_floor
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read lineage and exact inclusive-pair arithmetic in strategy-seeds/sources/MOP-WTI-HLRET-2026/source.md"
    quality_tier: A
    role: explicit_wti_own_return_lineage_and_governed_hodges_lehmann_style_arithmetic
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI exact-five-year same-calendar Hodges-Lehmann extraction."
    location: "strategy-seeds/sources/KELOHARJU-HL-WTI-SAMECAL5-2026/source.md"
    quality_tier: internal_governed
    role: exact_calendar_endpoints_fifteen_pair_averages_central_index_risk_and_lifecycle
strategy_mechanic: exact-prior-five-year-same-calendar-month-wti-log-returns-all-fifteen-inclusive-pair-averages-odd-hodges-lehmann-pseudomedian-sign-monthly-renewal
sources:
  - "[[sources/KELOHARJU-HL-WTI-SAMECAL5-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/hodges-lehmann-pseudomedian]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/inclusive-pair-pseudomedian]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, hodges-lehmann-style, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 412010000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "Approximately 10-12 completed XTI monthly positions per full post-warm-up year; a missing exact historical year, invalid endpoint, or exact tie-band state consumes the month flat."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_ESTIMATOR_AND_CFD_TRANSLATION_RISK
r1_reasoning: "Peer-reviewed same-calendar commodity evidence with explicit crude-oil membership plus a complete governed peer-reviewed WTI own-return and inclusive-pair arithmetic lineage; the exact five-year standalone-CFD conjunction remains untested."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform normalized endpoints, exact Y-1..Y-5 sample, all fifteen inclusive pairs, ascending sort, central index seven, sign band, consumed attempt, fixed risk, hard stop, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_qualification: LONG_WARMUP_AND_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history and native MT5 state supply every runtime input; five-year warm-up, D1 session labels, rolls, and futures/CFD basis remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, inclusive pair averages, sorting, finite arithmetic, comparisons, ATR risk controls, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: exact prior 5 same-calendar years and all 5 required; all i<=j pairs and exactly 15 values; ascending sort and zero-based central index 7; sign epsilon 1e-12; 3000 D1 history bars; ATR(20)*3.5 stop; 35-day stale exit; 1500-point entry spread ceiling."
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
review_focus: "Falsify a direct-WTI robust same-calendar sleeve outside the directional XAU/SP500/NDX/XNG book. Verify uniform D1-label normalization, exact Y-1..Y-5 completed endpoints, five-of-five sample, all fifteen inclusive pairs including self-pairs, central-index arithmetic, strict sign direction, consumed month, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_month_bar_clock, uniform_energy_label_normalization, exact_prior_five_years, exact_same_calendar_months, completed_month_endpoints, no_current_month_price, five_of_five_sample, inclusive_self_pairs, exact_fifteen_pair_count, pair_average_divisor_two, ascending_sort, central_index_seven, sign_epsilon, sign_only_direction, monthly_attempt_state, monthly_renewal, risk_mode_dual, hard_stop_present, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-29 and decisions/2026-08-29_qm5_41201_wti_same_calendar_hodges_lehmann5_g0.md: R1 passes with peer-reviewed same-calendar crude-oil evidence and governed peer-reviewed WTI inclusive-pair arithmetic; R2 locks calendar, endpoints, exact sample, all fifteen pairs, central order statistic, side, attempt, risk, stop, and lifecycle; R3 uses registered native XTI D1 with warm-up/session/CFD risk; R4 is deterministic native arithmetic only. Canonical dedup found only expected same-calendar family neighbors, and fixed fixtures prove directional non-equivalence."
---

# QM5_41201 WTI Five-Year Same-Calendar Hodges-Lehmann Seasonality

## Hypothesis

WTI demand, refinery utilization, storage, hedging, maintenance, weather, and
capital-allocation pressures may recur in the same calendar month. A raw mean
is vulnerable to one oil-shock year, while a raw median ignores the spacing
among neighboring returns. This card takes the exact five prior returns for
the upcoming calendar month, expands them into all fifteen inclusive pair
averages, and follows their central order statistic.

Direct WTI supplies crude-oil exposure absent from the stated directional
XAU, SP500, NDX, and XNG book. That economic distinction does not prove low
realized correlation. Q02 owns density/economics and unchanged Q09 owns
portfolio overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-HL-WTI-SAMECAL5-2026/source.md`, SHA-256
`9ED87587900CBC9342C7810E9172C56691FC59F137109F63B49D6C1E49012B6A`,
authorized by
`decisions/2026-08-29_wti_same_calendar_hodges_lehmann5_source_approval.md`
at commit `11575ffbf` before extraction.

Keloharju, Linnainmaa, and Nyberg supply the same-calendar-month information
object, explicit crude-oil membership, and a five-year history floor. The
governed Moskowitz/Ooi/Pedersen packet supplies WTI own-return lineage and
exact inclusive-pair pseudomedian arithmetic on a different contiguous-return
state. Neither source tests this exact direct-WTI seasonal position.

No source return, alpha, probability, significance, density, profit factor,
drawdown, transaction cost, CFD equivalence, decorrelation, or portfolio
statistic transfers.

## Non-Duplicate Decision

The fail-closed checker scanned 4,700 registry identities, 1,346 cards, and
45 Strategy Wiki nodes. It found no exact identity and surfaced four expected
same-calendar family neighbors. Receipt:
`artifacts/qm5_wti_samecal_hl5_preallocation_dedup_20260829.json`.

- `QM5_20099`, `QM5_41055`, `QM5_41059`, and `QM5_41191` use respectively a
  raw mean, raw median, positive-hit boundary, and ten-year signed-rank score.
- `QM5_41199` uses the same five raw returns but discards the two extremes and
  averages the middle three. This rule retains every observation through five
  self-pairs and ten cross-pairs and selects one central expanded value.
- `QM5_20276` applies inclusive-pair arithmetic to twelve contiguous recent
  monthly returns; `QM5_41139` applies it to daily returns inside one month.
  Neither uses five disjoint observations of the upcoming calendar month.
- `[-11,-9,-8,10,12]` gives this rule `+0.5` but gives raw mean `-1.2`, raw
  median `-8`, and middle-three mean `-7/3`. The vector
  `[-12,-11,5,9,10]` reverses the disagreement: this rule is `-1` while the
  other three are positive.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_15_WALSH_AVERAGE_HODGES_LEHMANN_SIGN_MONTHLY_RENEWAL`.

## Markets, Timeframe, And Cadence

- Host/traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Intended magic: `412010000`.
- Decision: first executable tick of the first normalized D1 bar after a
  genuine broker-month transition.
- Formation: same target calendar month in every exact year `Y-1..Y-5`; all
  five observations are mandatory.
- Hold: next broker-month boundary; 35 days is stale repair.
- Expected pre-result cadence: ten to twelve positions/year after warm-up;
  Q02 retires below five in any full post-warm-up year.

## Formula

For target calendar month `M` in historical year `H`:

```text
pre_close(H,M) = close of the immediately preceding D1 bar, normalized into
                 the immediately preceding calendar month
end_close(H,M) = close of the final normalized D1 bar in (H,M), confirmed by
                 a following D1 bar in the immediately following month
r(H,M)         = ln(end_close(H,M) / pre_close(H,M))

collect exactly r(Y-k,M), k=1..5
require all five returns finite and all exact years present

k = 0
for i = 0..4:
  for j = i..4:
    pair_average[k] = (r[i] + r[j]) / 2
    k += 1

require k == 15
sorted = ascending copy of pair_average[0..14]
hl = sorted[7]

BUY  iff hl > +1e-12
SELL iff hl < -1e-12
FLAT iff abs(hl) <= 1e-12 or any contract check fails
```

Signal magnitude never changes risk. There is no estimator fallback,
missing-year substitution, or current-month input.

## Rules

These rules are the complete baseline. No raw mean, raw median, trimmed mean,
hit-rate, signed-rank, contiguous-return pseudomedian, fixed month list,
recent-return confirmation, trend, inventory, event, curve, volume, range,
breakout, oscillator, volatility signal, optimizer artifact, or external-data
filter is authorized.

### Entry

1. Evaluate only on exact `XTIUSD.DWX`, D1, EA ID 41201, slot 0.
2. Process malformed and later-month owned exposure before every entry gate.
3. Accept only native same-day D1 labels or one uniform `+1` calendar-day
   energy offset. Require the normalized current D1 date to equal the broker
   date and apply the same offset to every historical endpoint.
4. Enter only on the first normalized D1 bar after a genuine broker-month
   transition. Mid-month initialization waits for the next boundary.
5. Persist broker `yyyymm` before history, signal, news, spread, quote, ATR,
   sizing, margin, or submission. Never retry after any downstream outcome.
6. Copy at most 3,000 completed D1 bars. For every exact year `Y-1..Y-5`,
   select the final normalized close in target month `M`, its immediately
   preceding D1 close, and a following D1 bar. Require adjacent calendar-
   month identities; reject the whole month if any exact year is invalid.
7. Compute all five finite log returns, enumerate every `i<=j` pair exactly
   once, require fifteen finite averages including five self-pairs, sort
   ascending, and select exact zero-based index 7.
8. Positive beyond `1e-12` buys; negative below `-1e-12` sells; the inclusive
   tie band consumes the month.
9. Require valid completed-bar ATR(20,D1). Place one frozen hard stop at
   `3.5*ATR`; use no take-profit.
10. Require a valid quote and no genuinely positive spread above 1,500
    points. Modeled zero `.DWX` spread is valid.
11. Submit one market order once. No retry, pending order, scale-in, grid,
    martingale, pyramid, hedge, or companion leg exists.

### Exit And Management

1. At the first observed D1 bar in a later broker `yyyymm`, close owned
   exposure before evaluating the new month.
2. Close after 35 elapsed calendar days as a final stale guard.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time exposure.
4. The frozen broker hard stop and framework kill switch remain authoritative.
5. Framework Friday close is disabled for this monthly identity.
6. No target, reversal, trailing stop, break-even move, partial exit, or
   discretionary close is authorized.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 5 | exact prior years; all required |
| `strategy_required_observations` | 5 | exact raw-return count |
| `strategy_required_pair_averages` | 15 | exact inclusive-pair count |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band |
| `strategy_history_bars_d1` | 3000 | bounded endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No sweep, statistic fallback, month selection, endpoint, direction, sample,
pair convention, stop, or lifecycle change is authorized.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, volume step, minimum volume,
  computed lot, or price consumes the month.
- This card creates no live, demo, shadow, stress, or optimization preset.

The empirical source is a diversified futures result and the exact estimator
conjunction is untested. Continuous-CFD roll, financing, gaps, spread, and
contract translation can erase the premise. Only Q09 may assess realized book
correlation.

## Data Requirements

Native `XTIUSD.DWX` D1 OHLC/timestamps, broker clock, symbol quotes and
properties, positions, deal history, and terminal-global attempt state only.
No futures curve, inventory, volume, open interest, event feed, API, CSV,
optimizer artifact, trained output, or manual signal input.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_COMPOSITE_ESTIMATOR_AND_CFD_TRANSLATION_RISK | Complete peer-reviewed same-calendar crude-oil evidence plus complete governed peer-reviewed WTI inclusive-pair arithmetic lineage; exact conjunction untested. |
| R2 | PASS | Calendar, endpoints, sample, pairs, sort, central index, side, attempt, risk, and lifecycle locked. |
| R3 | PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK | Registered native XTI D1 and MT5 state supply every runtime field. |
| R4 | PASS | Deterministic native arithmetic and state only; no trained signal or external runtime feed. |

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, boundary, attempt, history, endpoints, pairs, sort, central value, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| monthly renewal and survivor repair | Trade Close | strategy lifecycle helper; Friday close disabled |
| kill switch, ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than five completed positions per full post-
warm-up year; zero trades; nonpositive governed economics; wrong or partial
monthly endpoints; current-month leakage; any missing exact year; invalid raw
or pair count; missing/duplicate self-pair; wrong pair average, sort, central
index, epsilon, or side; retry; missing stop; wrong monthly lifecycle;
nondeterminism; or registry/risk mismatch.

No weak result may be rescued by reverting to another estimator, selecting
months, adding recent trend/return, inventory, event, curve, volume,
volatility, or price-action filters, changing the sample, or extending the
hold.

## Validation Plan

Q01 must prove:

1. native and uniform `+1` labels select only the exact normalized month
   boundary and same-calendar returns use completed endpoints for every exact
   year `Y-1..Y-5`, including December/January wrapping;
2. any missing or malformed exact year consumes the month without
   substitution;
3. five raw returns generate exactly fifteen finite `i<=j` averages, every
   self-pair equals its raw return, sorting is nondecreasing, and index 7 is
   the odd central value;
4. both fixed disagreement vectors produce the locked side and distinguish
   mean, median, hit, signed-rank, trim, and contiguous-return neighbors;
5. no current-month OHLC, volume, or tick price enters the signal;
6. persistent `yyyymm` attempts prevent same-month retry after every
   downstream failure and restart;
7. fixed-risk sizing uses a valid frozen completed-bar ATR stop;
8. next-month close, malformed repair, stale guard, and disabled Friday close
   remain reachable; and
9. strict compile, card lint, build checks, setfile schema, magic resolver,
   and static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized portfolio correlation.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-29 | initial WTI five-year same-calendar Hodges-Lehmann card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-29 | APPROVED; R1-R4 PASS | `decisions/2026-08-29_qm5_41201_wti_same_calendar_hodges_lehmann5_g0.md`; approved source packet |
| Q01 Build Validation | 2026-08-29 | NOT_BUILT | deterministic magic allocation and build pending |
| Q02 Baseline Screening | 2026-08-29 | NOT_ENQUEUED_Q01_PENDING | no work item before compile/review PASS |

## Safety Boundary

This card authorizes one branch-only non-live build, deterministic allocation,
strict Q01 validation, one `RISK_FIXED` D1 backtest setfile, and one paced Q02
enqueue only after prerequisites and a non-binding CPU check. It does not
authorize a manual backtest, live/demo/shadow/stress/optimization preset,
AutoTrading, `T_Live`, deploy or live manifest, portfolio-gate change,
portfolio admission, correlation waiver, terminal control, or queue deletion.
