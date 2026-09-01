---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XAUXAG-MCUCCONI-RV-20260902_S01
variant_id: AI-CODEX-XAUXAG-MCUCCONI-RV-20260902_S01
source_id: AI-CODEX-XAUXAG-MCUCCONI-RV-20260902
ea_id: QM5_41278
slug: xauxag-mcucconi-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41278_xauxag-mcucconi-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41278_xauxag_monthly_cucconi_reversion_g0.md
source_approval: decisions/2026-09-02_xauxag_monthly_cucconi_reversion_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Odoardo Cucconi; Marco Marozzi; Karsten Schweikert; CME Group"
source_citation: "OpenAI Codex (2026), XAU/XAG monthly Cucconi location-scale-state reversion; supporting records Marozzi (2012), Revista Colombiana de Estadistica 35(3), 371-384; Marozzi (2009), Journal of Nonparametric Statistics 21(5), DOI 10.1080/10485250902952435; Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). XAU/XAG monthly Cucconi location-scale-state reversion."
    location: "strategy-seeds/sources/AI-CODEX-XAUXAG-MCUCCONI-RV-20260902/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_execution_risk_atomicity_and_lifecycle
  - type: peer_reviewed_relationship_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete governed packet strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relation_and_adverse_evidence_only
  - type: official_exchange_carrier_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "complete governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A_official
    role: gold_silver_ratio_carrier_and_distinct_demand_drivers_only
  - type: peer_reviewed_statistical_method
    citation: "Marozzi, M. (2012). A modified Cucconi Test for Location and Scale Change Alternatives. Revista Colombiana de Estadistica 35(3), 371-384."
    location: "complete publisher PDF and hash in retrieval_route_marozzi_cucconi_20260902.json"
    quality_tier: A_complete
    role: classical_cucconi_squared_rank_contrary_rank_moments_correlation_and_exact_permutation_construction
  - type: peer_reviewed_statistical_method_metadata
    citation: "Marozzi, M. (2009). Some notes on the location-scale Cucconi test. Journal of Nonparametric Statistics 21(5), 629-647."
    location: "DOI 10.1080/10485250902952435; authoritative Crossref metadata"
    quality_tier: A_metadata_boundary
    role: method_identity_and_exact_critical_value_lineage_only
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-month-log-ratio-endpoints-twelve-adjacent-changes-fixed-six-old-six-recent-strict-pooled-ranks-cucconi-squared-rank-and-contrary-rank-correlated-quadratic-exact-924-directional-half-tail-rank-sum-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XAUXAG-MCUCCONI-RV-20260902]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/nonparametric-location-scale-state]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio-change]]"
  - "[[indicators/cucconi-squared-rank-contrary-rank-state]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, cucconi, nonparametric-location-scale, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41278_XAU_XAG_CUCCONI_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412780000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 5-6 completed XAU/XAG packages per full post-warm-up year after thirteen synchronized completed month ends; one consumed attempt per broker month. The frozen strict-rank support admits 480/924 Cucconi states, of which 18 have neutral recent rank sum, leaving 462 directional states or exactly six per twelve combinatorial attempts before market data and execution gates."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE
r1_reasoning: "One durable AI-originated source; complete governed peer-reviewed gold/silver evidence and adverse findings; official exchange carrier research; complete peer-reviewed publisher PDF defining classical Cucconi arithmetic and exact permutation construction; authoritative method metadata, hashes, and explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronization, endpoints, adjacent changes, fixed blocks, strict tie tolerance, pooled rank orientation, squared-rank and contrary-rank sums, moments, rho, statistic, all 924 labels, inclusive boundary, rank-sum side, attempt, aggregate risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories and MT5 state supply every runtime input; synchronization, continuous-CFD basis, financing, and legging risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, bounded integer enumeration, arithmetic, comparisons, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; 12 adjacent log-ratio changes; fixed old/recent blocks of 6; strict relative tie epsilon 1e-12; pooled raw-change ranks ascending; rank-square expectation 325; standard deviation 83.3966426182733; rho -0.8953271028037383; exact classical Cucconi quadratic; all 924 six-rank assignments; inclusive tail cap 480; neutral recent rank sum 39; rank-sum contrarian side; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a monthly Cucconi-state gold/silver relative-change fade outside the directional XAU/SP500/NDX/XNG book. Verify synchronization, change orientation, fixed membership, strict ties, pooled ranks, squared and contrary-rank sums, constants, correlated quadratic, exact 924 enumeration, inclusive tail 480, rank-sum contrarian side, consumed month, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_log_ratio_change_orientation, fixed_six_old_six_recent_membership, strict_raw_change_tie_rejection, ascending_pooled_change_ranks, exact_rank_square_expectation_and_sd, exact_negative_rho, classical_cucconi_correlated_quadratic, exact_924_label_enumeration, inclusive_tail_480, neutral_recent_rank_sum_39, rank_sum_contrarian_pair_sides, no_pvalue_or_critical_value_claim, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41278_xauxag_monthly_cucconi_reversion_g0.md: R1 passes through one durable AI source, complete peer-reviewed carrier evidence, official exchange evidence, a complete peer-reviewed method PDF, authoritative metadata, hashes, adverse findings, and explicit synthesis boundaries; R2 locks synchronization, changes, blocks, ties, ranks, moments, rho, statistic, enumeration, boundary, side, attempt, aggregate risk, atomicity, and lifecycle; R3 uses registered native XAU/XAG D1 with synchronization/CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,777 registry rows, 1,413 cards, and 45 Wiki nodes; fixed fixtures prove qualification disagreement with Kuiper, Anderson-Darling, and Klotz neighbors."
---

# QM5_41278 XAU/XAG Monthly Cucconi Location-Scale Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. When the latest six
completed monthly gold-minus-silver log-ratio changes form a high classical
Cucconi squared-rank/contrary-rank state relative to the prior six, fade the
ordinal location direction for one broker month.

Opposite equal-target-notional legs are intended to reduce outright XAU
direction and create a market-neutral-style stream distinct from the
directional XAU/SP500/NDX/XNG book. They do not prove dollar, beta, volatility,
factor, market, or portfolio neutrality. Q02 owns activity/economics, later
gates own robustness, and unchanged Q09 alone owns realized overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MCUCCONI-RV-20260902/source.md`.
Its approval was committed as `3cad3fab48` before extraction. Schweikert and
CME support only the state-dependent carrier and opposed-leg structure.
Marozzi supports only the named classical statistic, its moments/correlation,
and fixed-label permutation construction.

The exact monthly sample, 480-tail activity boundary, rank-sum direction,
contrarian translation, CFDs, risk, attempt state, atomicity, and lifecycle are
QM hypotheses fixed before market testing. No source supplies a profitable
rule or transfers a p-value, threshold, return, drawdown, frequency,
neutrality, or decorrelation claim.

## Non-Duplicate Decision

The corrected-root dedup receipt found no exact match and surfaced only four
shared-carrier fuzzy neighbors:

- `QM5_41263` uses two Kuiper ECDF extrema;
- `QM5_41260` integrates a tail-weighted Anderson-Darling ECDF path;
- `QM5_41265` retains Brown-Forsythe numeric absolute deviations; and
- `QM5_41269` separately mean-centers both blocks and applies Klotz nonlinear
  squared-normal scores.

This card retains no ECDF path, distance spacing, block centering, or normal
score. It combines squared recent integer ranks and squared contrary-ranks
through their source-defined negative correlation. `QM5_41270` is also not a
duplicate: its 25-by-25 direct-WTI daily sample adds standardized Wilcoxon and
Ansari-Bradley components and continues the WTI direction.

Frozen strict-rank fixtures prove boundary disagreement:

| path | this card | nearest neighbor |
|---|---|---|
| `RROROROOORRO` | Cucconi tail 480, rank sum 34, BUY XAU | Anderson-Darling tail 532, flat |
| `RROROROROROO` | Cucconi tail 456, rank sum 31, BUY XAU | Kuiper distance 1/3, tail 922, flat |
| `RRRRROOROOOO` | Cucconi tail 14, BUY XAU | Klotz tail 566, flat |
| `RROROROROORO` | Cucconi tail 484, flat | Klotz tail 374, BUY XAU |

`O`/`R` label pooled ascending old/recent observations; complement paths lock
SELL symmetry. Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_SIX_BY_SIX_RAW_CHANGE_STRICT_RANK_CUCCONI_SQUARED_RANK_CONTRARY_RANK_CORRELATED_QUADRATIC_EXACT_924_TAIL_480_RANK_SUM_CONTRARIAN_BASKET`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_41278_XAU_XAG_CUCCONI_RV_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1.
- Traded dependency slot 1: `XAGUSD.DWX`, D1.
- One consumed decision per broker month at the first synchronized executable
  D1 boundary, inside a 180-minute grace window.
- Formation: thirteen consecutive completed synchronized month-end pairs,
  producing twelve adjacent changes in fixed six-old/six-recent blocks.
- Hold: first later broker month; forty elapsed calendar days is the stale
  repair ceiling.
- Expected activity: 5-6 completed packages/year after warm-up. The exact
  strict-label prior is 462 directional states per 924 assignments, exactly
  six per twelve attempts before data and execution gates.

## Formula

For chronological completed-month close pairs `i=0..12`:

```text
q[i] = ln(XAU[i]) - ln(XAG[i])
r[i] = q[i+1] - q[i], i=0..11

old = r[0..5]; recent = r[6..11]
strictly pool/rank all r ascending; R are the six recent ranks

E2  = 325
SD2 = sqrt(6955) = 83.3966426182733
rho = -479/535 = -0.8953271028037383

U = (sum(R^2)-E2)/SD2
V = (sum((13-R)^2)-E2)/SD2
C = (U^2+V^2-2*rho*U*V)/(2*(1-rho^2))

tail = count over every six-rank subset P of {1..12}
       where C(P) + relative_epsilon >= C(observed)

qualify iff tail <= 480
SELL XAU / BUY XAG iff sum(R) > 39
BUY XAU / SELL XAG iff sum(R) < 39
FLAT iff sum(R) == 39
```

All twelve raw changes must be finite and pairwise distinct under
`1e-12*max(1,abs(a),abs(b))`. The enumerator must visit exactly 924
assignments. Statistic and rank-sum magnitudes never scale risk.

## Rules

1. Run only on `XAUUSD.DWX`, D1, slot 0, with registered XAG dependency.
2. Detect a genuine broker-month transition from synchronized current D1 bars.
3. Persist the month attempt before any downstream gate and never retry it.
4. Exclude current-month prices; select the latest exact timestamp-matched
   pair from each of the thirteen immediately preceding broker months.
5. Require consecutive month keys, chronological positive finite closes, and
   no completed endpoint more than ten calendar days stale.
6. Compute the locked formula, all 924 assignments, tail, and rank sum.
7. Open exactly one opposed-leg package only for a nonneutral qualifying side.
8. Split one fixed stop-risk budget, align notionals by reducing volume only,
   and require aggregate package integrity.
9. Close both legs at the next synchronized month or the forty-day ceiling.

## 4. Entry Rules

- The host must be exact `XAUUSD.DWX` D1 with `qm_ea_id=41278` and slot 0.
- Both current D1 bars must share the same timestamp and broker day.
- Entry must occur within 180 minutes of the host D1 boundary.
- No owned position may exist and the month attempt must be unused.
- History, endpoint, change, tie, rank, Cucconi, enumeration, and side rules
  above must pass exactly.
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

## 5. Exit Rules

1. Kill-switch and broker hard-stop handling remain framework-owned.
2. Any malformed composition, wrong side, missing stop, wrong symbol/magic,
   or notional mismatch closes all owned legs immediately.
3. On the first synchronized tick in a broker month later than entry, close
   both legs with `QM_EXIT_TIME`.
4. At forty elapsed calendar days, close both legs with `QM_EXIT_TIME` even if
   synchronized month detection is unavailable.
5. There is no convergence target, opposite signal, intramonth flip, Friday
   flatten, trail, break-even, partial close, scale-in, or pyramid exit.

## 6. Filters (No-Trade Module)

- Fail closed on wrong host/period/identity/slot or unregistered magic.
- Fail closed on bad fixed-risk, news-axis, Friday-close, or stress defaults.
- Fail closed on stale/unsynchronized history or nonconsecutive month keys.
- Fail closed on nonpositive/nonfinite closes, changes, ATR, quote, point,
  tick, contract, margin, or volume metadata.
- Fail closed on any raw-change tie, statistic invariant failure, enumeration
  count other than 924, tail above 480, or recent rank sum 39.
- Both news axes and legacy mode are OFF; the card requests no calendar data.
- Friday close is OFF because the one-month relative-value hold is load-
  bearing. Weekend and global kill-switch rules remain inherited.

## 7. Trade Management Rules

- Exactly zero or two owned positions are valid; any other count is repaired
  by closing all owned exposure.
- Exactly one XAU slot-0 leg and one XAG slot-1 leg with opposite expected
  sides and nonzero frozen stops are required.
- Actual entry notionals must remain inside the locked 20-percent mismatch
  ceiling; violation closes the package rather than resizing it.
- No re-hedge, scale-in, partial close, stop movement, retry, or new signal is
  authorized during the hold.
- Package closure attempts both legs through V5 close helpers.

## 8. Parameters To Test

No optimization surface is authorized. Q02 uses exactly one locked baseline:

| parameter | locked value |
|---|---:|
| synchronized endpoints | 13 |
| adjacent changes | 12 |
| old/recent block sizes | 6 / 6 |
| relative epsilon | `1e-12` |
| rank-square expectation | `325` |
| rank-square SD | `83.3966426182733` |
| rho | `-0.8953271028037383` |
| assignment count | 924 |
| inclusive tail cap | 480 |
| neutral recent rank sum | 39 |
| D1 history buffer | 900 bars |
| entry grace | 180 minutes |
| endpoint gap ceiling | 10 days |
| ATR stop | `3.5*ATR(20,D1)` |
| target notional ratio | 1.0 |
| max notional mismatch | 20% |
| stale hold ceiling | 40 days |
| XAU/XAG spread ceilings | 1500 / 500 points |

## Source-Defined Rules

- The classical Cucconi statistic uses pooled squared ranks, squared contrary-
  ranks, source-defined moments, and their negative correlation.
- The fixed-label permutation construction counts statistics at least as
  extreme as observed over all assignments of the first sample size.
- Gold/silver is a state-dependent intermarket relation with distinct demand
  drivers and material adverse evidence against a constant spread.

No source defines the exact trading conjunction or performance.

## QM Interpretations

- Monthly XAU/XAG log-ratio changes and the chronological six/six split.
- Strict tie rejection rather than average ranks.
- Complete 924-label enumeration and inclusive tail cap 480.
- Rank sum 39 as neutral direction and contrarian mapping.
- One consumed monthly attempt, CFD symbols, entry grace, staleness checks,
  equal target notionals, fixed-dollar risk, spreads, atomicity, and lifecycle.
- The 462/924 directional support is an activity prior only.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- `qm_stress_reject_probability=0` in the canonical baseline.
- Kill-switch, weekend, broker-disconnect, and hard-stop framework coverage
  remain active.

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

Retire or fail closed on:

- any formula/fixture mismatch, tie accepted, invalid rank permutation, or
  assignment count not equal to 924;
- any source/card/EA/set constant mismatch;
- zero completed packages or fewer than five in any full post-warm-up year;
- component-leg fanout, missing logical set, bad manifest, or bad registry;
- nonpositive governed economics or any later gate failure;
- any orphan leg, aggregate-risk double counting, or lifecycle deviation.

## Expected Behavior

- Roughly five to six monthly packages per full year after warm-up.
- Both long-ratio and short-ratio packages by complement symmetry.
- Intramonth holding and cross-weekend exposure are expected.
- PnL is combined two-leg relative-value PnL, not per-leg alpha.
- No profitability or correlation level is presumed.

## Logging

Log enough state to replay each consumed attempt: broker month, endpoint keys
and timestamps, twelve changes, pooled ranks/labels, recent squared-rank and
contrary-rank sums, U, V, rho, C, assignment count, tail count, recent rank
sum, direction, quotes/spreads, ATR/stops, target and rounded volumes,
notionals, magics, order results, repair reason, and exit reason.

## Framework Alignment

| card rule | module |
|---|---|
| identity, host, fixed-risk/news/Friday contract, month attempt, history, signal arithmetic, package state | `Strategy_NoTradeFilter` and bounded helpers |
| quotes, spreads, ATR, sizing, equal-notional reduction, atomic two-leg submission | `Strategy_EntrySignal` |
| malformed-package repair, next-month exit, forty-day exit | `Strategy_ManageOpenPosition` |
| broker/framework reason mapping | `Strategy_ExitSignal` and V5 close helper |

The no-trade hook must never close owned exposure. Basket repair and lifecycle
belong in management. The build must use `QM_MagicChecked` and
`QM_BasketOrder`; no manual magic arithmetic or raw ungoverned order path.

## Falsification And Requalification

Any change to symbols, period, endpoint count, block membership, tie rule,
moments, rho, statistic, enumeration, tail cap, neutral rank sum, direction,
risk, stops, spread ceilings, notional tolerance, attempt state, atomicity, or
hold requires a new source/card variant, binary, Q02-Q10 evidence, and Q09
requalification. A downstream failure cannot be repaired inside this card.

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
| v1 | 2026-09-02 | initial monthly Cucconi XAU/XAG card | G0 | APPROVED; build pending |

## Pipeline History

| version | date | rebuild reason | Q-stage reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial build | Q01 | IN_PROGRESS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41278_xauxag_monthly_cucconi_reversion_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
