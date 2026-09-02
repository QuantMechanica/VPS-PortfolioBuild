---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902_S01
variant_id: AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902_S01
source_id: AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902
ea_id: QM5_41281
slug: xauxag-mconover-scale-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41281_xauxag-mconover-scale-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41281_xauxag_monthly_conover_scale_reversion_g0.md
source_approval: decisions/2026-09-02_xauxag_monthly_conover_scale_reversion_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; William J. Conover; Karsten Schweikert; CME Group; NIST/SEMATECH"
source_citation: "OpenAI Codex (2026), XAU/XAG monthly Conover squared-rank scale-state reversion; supporting records Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread; NIST/SEMATECH, Two Sample Linear Rank Sum Test and Squared Ranks Test; Conover (1999), Practical Nonparametric Statistics, 3rd ed., pp. 300-310."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). XAU/XAG monthly Conover squared-rank scale-state reversion."
    location: "strategy-seeds/sources/AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_risk_and_lifecycle
  - type: peer_reviewed_carrier_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete-read packet strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_carrier_and_adverse_evidence_only
  - type: official_exchange_carrier
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A
    role: ratio_definition_distinct_demand_drivers_and_opposed_leg_carrier_only
  - type: official_statistical_method
    citation: "NIST/SEMATECH Dataplot. Two Sample Linear Rank Sum Test; Squared Ranks Test."
    location: "strategy-seeds/sources/AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902/retrieval_route_conover_scores_20260902.json"
    quality_tier: A
    role: group_mean_absolute_deviation_pooled_rank_squared_score_and_scale_interpretation_only
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-month-log-ratio-endpoints-twelve-adjacent-changes-fixed-six-old-six-recent-separate-arithmetic-mean-centered-absolute-deviations-strict-pooled-ranks-conover-squared-rank-sum-exact-924-inclusive-upper-half-tail461-raw-mean-shift-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/nonparametric-scale-state]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio-change]]"
  - "[[indicators/conover-squared-rank-scale-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, conover-squared-ranks, nonparametric-scale-state, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41281_XAU_XAG_CONOVER_SCALE_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412810000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 5-6 completed XAU/XAG packages per full post-warm-up year before deviation ties, zero mean shifts, market-data, and execution gates; one consumed attempt per broker month. The frozen strict-rank support admits 461 of 924 assignments, or 5.987 states per twelve attempts."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_OFFICIAL_METHOD_EVIDENCE
r1_reasoning: "One durable AI source; complete governed peer-reviewed gold/silver evidence and adverse findings; official exchange carrier evidence; complete bounded official NIST method pages; hashes and explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronization, endpoints, changes, block means, deviations, strict ties, pooled ranks, squared scores, all 924 labels, upper-half boundary, raw-mean side, attempt, aggregate risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories and MT5 state supply every runtime input; synchronization, continuous-CFD basis, financing, calendar, and legging risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, bounded arithmetic and sorting, integer enumeration, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; 12 adjacent log-ratio changes; fixed old/recent blocks of 6; separate arithmetic-mean centering; pooled absolute-deviation strict relative tie epsilon 1e-12; ascending ranks 1..12; squared-rank scores; score total 650; recent expected score 325; all 924 six-rank assignments; recent score minimum 326; inclusive upper-tail cap 461; raw block-mean contrarian side epsilon 1e-12; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a monthly Conover-scale gold/silver relative-change fade outside the directional XAU/SP500/NDX/XNG book. Verify synchronization, change orientation, block means, deviations, strict ties, ranks, squared scores, exact 924 enumeration, upper tail 461, raw-mean contrarian side, consumed month, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_log_ratio_change_orientation, fixed_six_old_six_recent_membership, separate_arithmetic_mean_centering, pooled_absolute_deviation_tie_rejection, ascending_pooled_deviation_ranks, exact_squared_rank_scores, exact_924_label_enumeration, inclusive_upper_tail_461, raw_mean_shift_contrarian_pair_sides, no_pvalue_or_critical_value_claim, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41281_xauxag_monthly_conover_scale_reversion_g0.md: R1 passes through one durable AI source, complete peer-reviewed carrier evidence, official exchange evidence, complete bounded official NIST formula pages, hashes, adverse findings, and explicit synthesis boundaries; R2 locks synchronization, changes, means, deviations, ties, ranks, scores, enumeration, boundary, side, attempt, aggregate risk, atomicity, and lifecycle; R3 uses registered native XAU/XAG D1 with synchronization/CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,780 registry rows, 1,416 cards, and 45 Wiki nodes; fixed fixtures prove qualification and side disagreement with Klotz and Brown-Forsythe neighbors."
---

# QM5_41281 XAU/XAG Monthly Conover Scale Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. At the first tradable D1
boundary of each broker month, compare the newest six completed monthly
changes in `ln(XAU)-ln(XAG)` with the prior six. When within-block
mean-centered absolute deviations occupy the strict Conover squared-rank
upper half, fade the raw recent mean shift for one broker month.

Opposite equal-target-notional legs aim to reduce outright XAU direction and
create a market-neutral-style stream distinct from the directional
XAU/SP500/NDX/XNG book. They do not prove neutrality or decorrelation. Q02
owns activity/economics, later gates own robustness, and unchanged Q09 alone
owns realized overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902/source.md`.
Its source approval was committed as `6a88b02d89` before extraction.

Schweikert supports only a state-dependent gold/silver carrier and supplies
binding adverse evidence. CME supports the ratio definition, different demand
drivers, and opposed-leg form. NIST supports only within-group mean-centered
absolute deviations, pooled ranks, squared-rank sums, and scale
interpretation. The exact monthly sample, strict tie rule, 461-tail activity
boundary, contrarian direction, CFD mapping, risk, attempt state, atomicity,
and lifecycle are pre-result QM hypotheses. No source supplies a profitable
rule or transfers a p-value, critical value, return, drawdown, frequency,
neutrality, or correlation claim.

## Non-Duplicate Decision

The corrected-root receipt found no exact identity and surfaced only shared-
carrier fuzzy neighbors. This card separately mean-centers each block, ranks
absolute deviations, squares the ordinal ranks, and gates on a fixed-score
upper tail. It is not Klotz's signed-residual squared-normal score,
Brown-Forsythe's numeric median deviations without a label tail, Cucconi's
raw-rank quadratic, Savage's harmonic raw-rank score, or Kuiper's ECDF path.

Frozen fixtures prove both qualification and side disagreement:

| fixture | this card | nearest neighbor |
|---|---|---|
| Conover-only | score 331, tail 440, SELL XAU | Klotz tail 640 and Brown-Forsythe flat |
| Klotz-only | score 248, tail 753, flat | Klotz score 3.9642160041, tail 494, BUY XAU |
| Brown-Forsythe-only | score 313, tail 514, flat | Brown-Forsythe BUY XAU |
| side disagreement | score 397, tail 187, BUY XAU | Brown-Forsythe SELL XAU |

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_SEPARATE_MEAN_CENTERED_ABSOLUTE_DEVIATION_STRICT_RANK_CONOVER_SQUARED_RANK_SUM_EXACT_924_UPPER_HALF_TAIL461_RAW_MEAN_SHIFT_CONTRARIAN_BASKET`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_41281_XAU_XAG_CONOVER_SCALE_RV_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1.
- Traded dependency slot 1: `XAGUSD.DWX`, D1.
- One consumed decision per broker month at the first synchronized executable
  D1 boundary inside a 180-minute grace window.
- Formation: thirteen consecutive completed synchronized month-end pairs,
  producing twelve adjacent changes in fixed six-old/six-recent blocks.
- Hold: first later broker month; forty elapsed calendar days is the stale
  repair ceiling.
- Expected activity: approximately 5-6 packages/year before data and
  execution gates; Q02 retires any full scored year below five.

## Formula

For chronological completed-month close pairs `i=0..12`:

```text
q[i] = ln(XAU[i]) - ln(XAG[i])
r[i] = q[i+1] - q[i], i=0..11

old = r[0..5]; recent = r[6..11]
mu_old = mean(old); mu_recent = mean(recent)
d[i] = abs(r[i] - mu_of_own_block)

strictly pool/rank all d ascending, ranks 1..12
C_recent = sum(rank^2 for the six recent deviations)

tail = count over every six-rank subset P of {1..12}
       where sum(rank^2 for rank in P) >= C_recent

qualify iff C_recent >= 326 and tail <= 461
SELL XAU / BUY XAG iff mu_recent - mu_old > 1e-12
BUY XAU / SELL XAG iff mu_recent - mu_old < -1e-12
FLAT otherwise
```

All twelve changes and deviations must be finite. Deviations must be pairwise
distinct under `1e-12*max(1,abs(a),abs(b))`. The enumerator must visit exactly
924 assignments. Score magnitude never scales risk. The exhaustive label
tail is an activity boundary, not a NIST p-value or published critical value.

## Rules

1. Run only on `XAUUSD.DWX`, D1, slot 0, with registered XAG dependency.
2. Detect a genuine broker-month transition from synchronized current D1 bars.
3. Persist the month attempt before any downstream gate and never retry it.
4. Exclude current-month prices; select the latest exact timestamp-matched
   pair from each of the thirteen immediately preceding broker months.
5. Require consecutive month keys, chronological positive finite closes, and
   no completed endpoint more than ten calendar days stale.
6. Compute the locked means, deviations, ranks, squared score, all 924 labels,
   tail, and mean-shift side.
7. Open exactly one opposed-leg package only for a qualifying nonzero side.
8. Split one fixed stop-risk budget, align notionals by reducing volume only,
   and require aggregate package integrity.
9. Close both legs at the next synchronized month or forty-day ceiling.

## Entry Rules

- The host must be exact `XAUUSD.DWX` D1 with `qm_ea_id=41281` and slot 0.
- Both current D1 bars must share the same timestamp and broker day.
- Entry must occur within 180 minutes of the host D1 boundary.
- No owned position may exist and the month attempt must be unused.
- Both symbols must be trade-enabled with valid quotes, contract/tick/volume
  metadata, margins, and spreads no greater than 1,500/500 points.
- Use closed D1 ATR(20) for each frozen `3.5*ATR` hard stop.
- Allocate half of one aggregate `$1,000` stop-risk budget to each leg, then
  reduce volumes only until target absolute USD notionals differ by at most
  20 percent.
- Direction `+1`: BUY XAU slot 0, then SELL XAG slot 1.
- Direction `-1`: SELL XAU slot 0, then BUY XAG slot 1.
- If either submission fails or the resulting pair is malformed, flatten all
  owned exposure immediately. No orphan leg may remain.

## Exit Rules

1. Kill-switch and broker hard-stop handling remain framework-owned.
2. Any malformed composition, wrong side, missing stop, wrong symbol/magic,
   or notional mismatch closes all owned legs immediately.
3. On the first synchronized tick in a broker month later than entry, close
   both legs with `QM_EXIT_TIME_STOP`.
4. At forty elapsed calendar days, close both legs with `QM_EXIT_TIME_STOP`.
5. There is no target, convergence exit, opposite signal, intramonth flip,
   Friday flatten, trail, break-even, partial close, scale-in, or pyramid.

## Filters And No-Trade Module

- Fail closed on wrong host/period/identity/slot or unregistered magic.
- Fail closed on bad fixed-risk, news-axis, Friday-close, or stress defaults.
- Fail closed on stale/unsynchronized history or nonconsecutive month keys.
- Fail closed on nonpositive/nonfinite closes, changes, deviations, ATR,
  quote, point, tick, contract, margin, or volume metadata.
- Fail closed on any pooled deviation tie, score invariant failure,
  enumeration count other than 924, score below 326, tail above 461, or
  zero raw mean shift.
- Both news axes and legacy mode are OFF; Friday close is OFF because the
  one-month relative-value hold is load-bearing.

## Trade Management Rules

- Exactly zero or two owned positions are valid; any other count is repaired
  by closing all owned exposure.
- Exactly one XAU slot-0 leg and one XAG slot-1 leg with opposite expected
  sides and nonzero frozen stops are required.
- Actual entry notionals must remain inside the locked 20-percent mismatch
  ceiling; violation closes the package rather than resizing it.
- No re-hedge, scale-in, partial close, stop movement, retry, or new signal is
  authorized during the hold.

## Parameters To Test

No optimization surface is authorized. Q02 uses exactly one locked baseline:

| parameter | locked value |
|---|---:|
| synchronized endpoints | 13 |
| adjacent changes | 12 |
| old/recent block sizes | 6 / 6 |
| center | separate arithmetic means |
| transformation | within-block absolute deviations |
| relative tie epsilon | `1e-12` |
| score | pooled deviation rank squared |
| score total / expected recent | 650 / 325 |
| minimum recent score | 326 |
| assignment count / upper-tail cap | 924 / 461 |
| direction epsilon | `1e-12` |
| D1 history buffer | 900 bars |
| entry grace | 180 minutes |
| endpoint gap ceiling | 10 days |
| ATR stop | `3.5*ATR(20,D1)` |
| target notional ratio | 1.0 |
| max notional mismatch | 20% |
| stale hold ceiling | 40 days |
| XAU/XAG spread ceilings | 1500 / 500 points |

## Source-Defined Rules

- Conover squared-rank scale scoring starts with absolute deviations from each
  group's mean, pools their ranks, and sums squared ranks by sample.
- Gold/silver is a state-dependent intermarket relationship with distinct
  demand drivers and material adverse evidence against a constant spread.

No source defines the exact trading conjunction, threshold, side, or
performance.

## QM Interpretations

- Monthly XAU/XAG log-ratio changes and chronological six/six split.
- Strict deviation-tie rejection, full 924 fixed-score enumeration, and
  inclusive upper-tail cap 461.
- Raw block-mean shift as location direction and contrarian mapping.
- One consumed monthly attempt, CFD symbols, entry grace, staleness checks,
  equal target notionals, fixed-dollar risk, spreads, atomicity, and lifecycle.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- `qm_stress_reject_probability=0` in the canonical baseline.
- Kill-switch, weekend, broker-disconnect, and hard-stop coverage remain active.

## Exit Precedence

1. Kill-switch / broker hard stop.
2. Malformed or incomplete package repair.
3. Next synchronized broker-month exit.
4. Forty-day stale exit.
5. No other strategy or framework calendar exit.

## Runtime Data Dependencies

- Native `XAUUSD.DWX` and `XAGUSD.DWX` D1 time/close history.
- Native closed D1 ATR values for both symbols.
- Broker time/month, quotes, spread, symbol metadata, margin, positions,
  deals, and terminal global variables for attempt persistence.
- Tester host symbol `XAUUSD.DWX`, account currency USD, deposit 100,000.
- Q02 logical-basket window `2018.07.02` through `2024.12.31`.
- No external API, calendar, file, trained artifact, or future price.

## Risk

| item | contract |
|---|---|
| backtest risk mode | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| portfolio weight | 1.0 |
| package allocation | half frozen stop-risk budget per leg |
| stops | `3.5*ATR(20,D1)` per leg, frozen at entry |
| hedge target | equal absolute USD notionals, reduction only |
| notional tolerance | maximum 20% mismatch |
| concurrent exposure | one logical package |
| statistic sizing | forbidden |
| live risk | not authorized |

Aggregate risk must not be applied once per leg. Rounded volume may only be
reduced, never increased beyond either half-budget risk cap.

## Execution Assumptions

- Both registered custom symbols are available and synchronized in the tester.
- Opposed CFD legs are submitted sequentially; no atomic exchange spread is
  assumed, so legging and repair risk remain.
- Equal notionals do not remove basis, volatility, financing, or factor risk.
- The logical basket is evaluated as one work item; component legs are never
  standalone Q02 strategies.

## Failure Conditions

Retire or fail closed on any formula/fixture mismatch, accepted deviation tie,
invalid enumeration, source/card/EA/set constant mismatch, zero completed
packages, fewer than five in any full post-warm-up year, component-leg fanout,
missing logical set/manifest/registry, nonpositive governed economics, orphan
leg, aggregate-risk double counting, lifecycle deviation, or later gate
failure.

## Expected Behavior

- Approximately 5-6 monthly packages per full year after warm-up.
- Both long-ratio and short-ratio packages are possible.
- Intramonth holding and cross-weekend exposure are expected.
- PnL is combined two-leg relative-value PnL, not per-leg alpha.
- No profitability or correlation level is presumed.

## Logging

Log broker month, endpoint keys/timestamps, twelve changes, old/recent means,
twelve deviations, pooled ranks and labels, recent squared-rank score,
assignment count, tail count, direction, quotes/spreads, ATR/stops, volumes,
notionals, magics, order/repair results, and exit reason.

## Framework Alignment

| card rule | module |
|---|---|
| identity, host, fixed-risk/news/Friday contract, month attempt, history, Conover arithmetic, package state | `Strategy_NoTradeFilter` and bounded helpers |
| quotes, spreads, ATR, sizing, equal-notional reduction, atomic two-leg submission | `Strategy_EntrySignal` |
| malformed-package repair, next-month exit, forty-day exit | `Strategy_ManageOpenPosition` |
| broker/framework reason mapping | `Strategy_ExitSignal` and V5 close helper |

The no-trade hook must never close exposure. Basket repair and lifecycle belong
in management. The build must use `QM_MagicChecked` and `QM_BasketOrder`; no
manual magic arithmetic or raw ungoverned order path.

## Falsification And Requalification

Any change to symbols, period, endpoint count, block membership, centering,
tie rule, scores, enumeration, tail cap, direction, risk, stops, spread
ceilings, notional tolerance, attempt state, atomicity, or hold requires a new
source/card variant, binary, Q02-Q10 evidence, and Q09 requalification. A
downstream failure cannot be repaired inside this card.

## Safety Boundary

Authorized: deterministic identity allocation, branch-only non-live build,
reference tests, strict Q01, one logical fixed-risk set plus two component
validation sets, and one paced logical Q02 enqueue below the CPU ceiling.

Forbidden: optimization, manual tester launch, live/demo/shadow/stress set,
component Q02 rows, portfolio-gate edit, correlation waiver, portfolio
admission, deploy/live manifest, `T_Live`, AutoTrading, or terminal control.

## Revision History

| version | date | reason | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial monthly Conover XAU/XAG card | G0 | APPROVED; build pending |

## Pipeline History

| version | date | rebuild reason | Q-stage reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial build | Q01 | IN_PROGRESS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41281_xauxag_monthly_conover_scale_reversion_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
