---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XAUXAG-MSAVAGE-RV-20260902_S01
variant_id: AI-CODEX-XAUXAG-MSAVAGE-RV-20260902_S01
source_id: AI-CODEX-XAUXAG-MSAVAGE-RV-20260902
ea_id: QM5_41279
slug: xauxag-msavage-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41279_xauxag-msavage-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41279_xauxag_monthly_savage_score_reversion_g0.md
source_approval: decisions/2026-09-02_xauxag_monthly_savage_score_reversion_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; I. Richard Savage; Karsten Schweikert; CME Group; NIST/SEMATECH; SAS Institute"
source_citation: "OpenAI Codex (2026), XAU/XAG monthly centered-Savage-score reversion; supporting records NIST/SEMATECH Two Sample Linear Rank Sum Test; SAS/STAT NPAR1WAY Savage scores and exact test; Savage (1956), Annals of Mathematical Statistics 27(3), 590-615; Schweikert (2018), Journal of Banking & Finance 88; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). XAU/XAG monthly centered-Savage-score reversion."
    location: "strategy-seeds/sources/AI-CODEX-XAUXAG-MSAVAGE-RV-20260902/source.md"
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
    role: gold_silver_ratio_carrier_and_opposed_leg_structure_only
  - type: official_government_statistical_method
    citation: "NIST/SEMATECH. Two Sample Linear Rank Sum Test."
    location: "complete bounded method sections and hash in retrieval_route_savage_scores_20260902.json"
    quality_tier: A_official_complete_bounded
    role: centered_savage_score_formula_and_linear_rank_moments
  - type: official_statistical_software_method
    citation: "SAS Institute. NPAR1WAY Savage Scores and Exact Statement."
    location: "complete bounded method sections and hashes in retrieval_route_savage_scores_20260902.json"
    quality_tier: A_official_complete_bounded
    role: independent_score_formula_and_exact_two_sample_test_identity
  - type: peer_reviewed_method_metadata
    citation: "Savage, I. R. (1956). Contributions to the Theory of Rank Order Statistics-the Two-Sample Case. The Annals of Mathematical Statistics 27(3), 590-615."
    location: "JSTOR stable 2237370 metadata; no complete-body claim"
    quality_tier: A_metadata_boundary
    role: original_method_identity_only
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-month-log-ratio-endpoints-twelve-adjacent-changes-fixed-six-old-six-recent-strict-pooled-ranks-centered-savage-exponential-order-scores-exact-924-two-sided-tail-462-score-direction-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XAUXAG-MSAVAGE-RV-20260902]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/nonparametric-extreme-rank-state]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio-change]]"
  - "[[indicators/centered-savage-rank-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, savage-score, nonparametric-extreme-rank, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41279_XAU_XAG_SAVAGE_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412790000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 6 completed XAU/XAG packages per full post-warm-up year before market-data and execution gates; one consumed attempt per broker month. The exact strict-rank support admits 462 of 924 assignments, split into 231 positive and 231 negative scores."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_OFFICIAL_METHOD_EVIDENCE
r1_reasoning: "One durable AI-originated source; complete governed peer-reviewed gold/silver evidence and adverse findings; official exchange carrier research; complete bounded NIST and SAS score/formula/exact-test sections; original peer-reviewed method metadata; hashes and explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronization, endpoints, adjacent changes, fixed blocks, strict ties, pooled ranks, twelve centered Savage scores, score sum, all 924 labels, absolute inclusive tail 462, score-sign side, attempt, aggregate risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories and MT5 state supply every runtime input; synchronization, continuous-CFD basis, financing, and legging risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, bounded harmonic arithmetic and integer enumeration, comparisons, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; 12 adjacent log-ratio changes; fixed old/recent blocks of 6; strict relative tie epsilon 1e-12; pooled raw-change ranks ascending; centered Savage scores with denominator 27720; all 924 six-rank assignments; inclusive absolute-score tail cap 462; score-sign contrarian side; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a monthly extreme-rank gold/silver relative-change fade outside the directional XAU/SP500/NDX/XNG book. Verify synchronization, change orientation, fixed membership, strict ties, pooled ranks, centered harmonic scores, exact 924 enumeration, absolute tail 462, score-sign contrarian side, consumed month, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_log_ratio_change_orientation, fixed_six_old_six_recent_membership, strict_raw_change_tie_rejection, ascending_pooled_change_ranks, exact_centered_savage_scores, exact_924_label_enumeration, inclusive_absolute_tail_462, nonzero_score_sign, contrarian_pair_sides, no_pvalue_or_critical_value_claim, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41279_xauxag_monthly_savage_score_reversion_g0.md: R1 passes through one durable AI source, complete peer-reviewed carrier evidence, official exchange evidence, complete bounded official method sections, original metadata, hashes, adverse findings, and explicit synthesis boundaries; R2 locks synchronization, changes, blocks, ties, ranks, scores, enumeration, tail, side, attempt, aggregate risk, atomicity, and lifecycle; R3 uses registered native XAU/XAG D1 with synchronization/CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,778 registry rows, 1,414 cards, and 45 Wiki nodes; fixed fixtures prove qualification disagreement with Cucconi, ECDF/rank-sum, and centered Klotz neighbors."
---

# QM5_41279 XAU/XAG Monthly Centered-Savage-Score Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. When the latest six
completed monthly gold-minus-silver log-ratio changes carry an extreme
centered Savage score relative to the prior six, fade the score direction for
one broker month.

Opposite equal-target-notional legs are intended to reduce outright XAU
direction and create a market-neutral-style stream distinct from the
directional XAU/SP500/NDX/XNG book. They do not prove dollar, beta, volatility,
factor, market, or portfolio neutrality. Q02 owns activity/economics, later
gates own robustness, and unchanged Q09 alone owns realized overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MSAVAGE-RV-20260902/source.md`.
Its source approval was committed as `c8ac8a822f` before extraction.
Schweikert and CME support only the state-dependent carrier and opposed-leg
form. NIST and SAS support only the centered Savage score formula, linear-rank
identity, and exact two-sample test. Savage (1956) is bibliographic lineage.

The exact monthly sample, 462-tail activity boundary, score-sign direction,
contrarian translation, CFDs, risk, attempt state, atomicity, and lifecycle
are QM hypotheses fixed before market testing. No source supplies a profitable
rule or transfers a p-value, threshold, return, drawdown, frequency,
neutrality, or decorrelation claim.

## Non-Duplicate Decision

The corrected-root dedup receipt found no exact match and surfaced only shared-
carrier fuzzy neighbors. This card uses a monotone harmonic score on raw ranks
and the exact absolute tail of its signed sum. It is not Cucconi's squared-
rank/contrary-rank quadratic, an Anderson-Darling ECDF path, Kuiper extrema,
numeric Brown-Forsythe deviations, or mean-centered symmetric Klotz scores.

Frozen fixtures prove both disagreement directions:

| path | this card | nearest neighbor |
|---|---|---|
| `RRROOOOOORRR` | Savage tail 400, SELL XAU | rank sum 39; Cucconi/AD2/Kuiper/Klotz flat |
| `RRRROOOROOOR` | Savage tail 536, flat | Cucconi/AD2/Kuiper BUY XAU |
| `RRRROOOOROOR` | Savage tail 632, flat | centered Klotz tail 26, BUY XAU |

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_SIX_BY_SIX_RAW_CHANGE_STRICT_RANK_CENTERED_SAVAGE_HARMONIC_EXPONENTIAL_ORDER_SCORES_EXACT_924_ABSOLUTE_TAIL_462_SCORE_SIGN_CONTRARIAN_BASKET`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_41279_XAU_XAG_SAVAGE_RV_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1.
- Traded dependency slot 1: `XAGUSD.DWX`, D1.
- One consumed decision per broker month at the first synchronized executable
  D1 boundary inside a 180-minute grace window.
- Formation: thirteen consecutive completed synchronized month-end pairs,
  producing twelve adjacent changes in fixed six-old/six-recent blocks.
- Hold: first later broker month; forty elapsed calendar days is the stale
  repair ceiling.
- Expected activity: six packages/year before market and execution gates.

## Formula

For chronological completed-month close pairs `i=0..12`:

```text
q[i] = ln(XAU[i]) - ln(XAG[i])
r[i] = q[i+1] - q[i], i=0..11

old = r[0..5]; recent = r[6..11]
strictly pool/rank all r ascending; R are the six recent ranks

a(rank) = sum[j=1..rank] 1/(12-j+1) - 1
S = sum[a(rank) for rank in R]

tail = count over every six-rank subset P of {1..12}
       where abs(S(P)) + relative_epsilon >= abs(S(observed))

qualify iff tail <= 462
SELL XAU / BUY XAG iff S > 0
BUY XAU / SELL XAG iff S < 0
FLAT iff S is zero within relative tolerance
```

All twelve raw changes must be finite and pairwise distinct under
`1e-12*max(1,abs(a),abs(b))`. The enumerator must visit exactly 924
assignments. Score magnitude never scales risk.

## Rules

1. Run only on `XAUUSD.DWX`, D1, slot 0, with registered XAG dependency.
2. Detect a genuine broker-month transition from synchronized current D1 bars.
3. Persist the month attempt before any downstream gate and never retry it.
4. Exclude current-month prices; select the latest exact timestamp-matched
   pair from each of the thirteen immediately preceding broker months.
5. Require consecutive month keys, chronological positive finite closes, and
   no completed endpoint more than ten calendar days stale.
6. Compute the locked scores, exact sum, all 924 assignments, tail, and side.
7. Open exactly one opposed-leg package only for a qualifying nonzero score.
8. Split one fixed stop-risk budget, align notionals by reducing volume only,
   and require aggregate package integrity.
9. Close both legs at the next synchronized month or forty-day ceiling.

## 4. Entry Rules

- The host must be exact `XAUUSD.DWX` D1 with `qm_ea_id=41279` and slot 0.
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

## 5. Exit Rules

1. Kill-switch and broker hard-stop handling remain framework-owned.
2. Any malformed composition, wrong side, missing stop, wrong symbol/magic,
   or notional mismatch closes all owned legs immediately.
3. On the first synchronized tick in a broker month later than entry, close
   both legs with `QM_EXIT_TIME_STOP`.
4. At forty elapsed calendar days, close both legs with `QM_EXIT_TIME_STOP`.
5. There is no target, convergence exit, opposite signal, intramonth flip,
   Friday flatten, trail, break-even, partial close, scale-in, or pyramid.

## 6. Filters (No-Trade Module)

- Fail closed on wrong host/period/identity/slot or unregistered magic.
- Fail closed on bad fixed-risk, news-axis, Friday-close, or stress defaults.
- Fail closed on stale/unsynchronized history or nonconsecutive month keys.
- Fail closed on nonpositive/nonfinite closes, changes, ATR, quote, point,
  tick, contract, margin, or volume metadata.
- Fail closed on any raw-change tie, score invariant failure, enumeration
  count other than 924, tail above 462, or zero score.
- Both news axes and legacy mode are OFF; Friday close is OFF because the
  one-month relative-value hold is load-bearing.

## 7. Trade Management Rules

- Exactly zero or two owned positions are valid; any other count is repaired
  by closing all owned exposure.
- Exactly one XAU slot-0 leg and one XAG slot-1 leg with opposite expected
  sides and nonzero frozen stops are required.
- Actual entry notionals must remain inside the locked 20-percent mismatch
  ceiling; violation closes the package rather than resizing it.
- No re-hedge, scale-in, partial close, stop movement, retry, or new signal is
  authorized during the hold.

## 8. Parameters To Test

No optimization surface is authorized. Q02 uses exactly one locked baseline:

| parameter | locked value |
|---|---:|
| synchronized endpoints | 13 |
| adjacent changes | 12 |
| old/recent block sizes | 6 / 6 |
| relative epsilon | `1e-12` |
| score denominator | 27720 |
| assignment count | 924 |
| inclusive absolute-tail cap | 462 |
| D1 history buffer | 900 bars |
| entry grace | 180 minutes |
| endpoint gap ceiling | 10 days |
| ATR stop | `3.5*ATR(20,D1)` |
| target notional ratio | 1.0 |
| max notional mismatch | 20% |
| stale hold ceiling | 40 days |
| XAU/XAG spread ceilings | 1500 / 500 points |

## Source-Defined Rules

- Centered Savage scores are cumulative reciprocal/harmonic functions of
  pooled ranks and correspond to exponential order-statistic scores.
- An exact two-sample Savage test uses the selected sample's score sum under
  fixed-label permutation.
- Gold/silver is a state-dependent intermarket relation with distinct demand
  drivers and material adverse evidence against a constant spread.

No source defines the exact trading conjunction or performance.

## QM Interpretations

- Monthly XAU/XAG log-ratio changes and chronological six/six split.
- Strict tie rejection, complete 924-label absolute-score enumeration, and
  inclusive tail cap 462.
- Score sign as location direction and contrarian mapping.
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

Retire or fail closed on any formula/fixture mismatch, accepted tie, invalid
enumeration, source/card/EA/set constant mismatch, zero completed packages,
fewer than five in any full post-warm-up year, component-leg fanout, missing
logical set/manifest/registry, nonpositive governed economics, orphan leg,
aggregate-risk double counting, lifecycle deviation, or later gate failure.

## Expected Behavior

- Roughly six monthly packages per full year after warm-up.
- Both long-ratio and short-ratio packages by complement symmetry.
- Intramonth holding and cross-weekend exposure are expected.
- PnL is combined two-leg relative-value PnL, not per-leg alpha.
- No profitability or correlation level is presumed.

## Logging

Log broker month, endpoint keys/timestamps, twelve changes, pooled ranks and
labels, recent Savage score, absolute score, assignment count, tail count,
direction, quotes/spreads, ATR/stops, volumes, notionals, magics, order/repair
results, and exit reason.

## Framework Alignment

| card rule | module |
|---|---|
| identity, host, fixed-risk/news/Friday contract, month attempt, history, score arithmetic, package state | `Strategy_NoTradeFilter` and bounded helpers |
| quotes, spreads, ATR, sizing, equal-notional reduction, atomic two-leg submission | `Strategy_EntrySignal` |
| malformed-package repair, next-month exit, forty-day exit | `Strategy_ManageOpenPosition` |
| broker/framework reason mapping | `Strategy_ExitSignal` and V5 close helper |

The no-trade hook must never close exposure. Basket repair and lifecycle belong
in management. The build must use `QM_MagicChecked` and `QM_BasketOrder`; no
manual magic arithmetic or raw ungoverned order path.

## Falsification And Requalification

Any change to symbols, period, endpoint count, block membership, tie rule,
scores, enumeration, tail cap, direction, risk, stops, spread ceilings,
notional tolerance, attempt state, atomicity, or hold requires a new source/
card variant, binary, Q02-Q10 evidence, and Q09 requalification. A downstream
failure cannot be repaired inside this card.

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
| v1 | 2026-09-02 | initial monthly centered-Savage XAU/XAG card | G0 | APPROVED; build pending |

## Pipeline History

| version | date | rebuild reason | Q-stage reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial build | Q01 | IN_PROGRESS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41279_xauxag_monthly_savage_score_reversion_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
