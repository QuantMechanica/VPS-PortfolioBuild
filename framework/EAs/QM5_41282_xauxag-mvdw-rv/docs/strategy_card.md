---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XAUXAG-MVDW-RV-20260902_S01
variant_id: AI-CODEX-XAUXAG-MVDW-RV-20260902_S01
source_id: AI-CODEX-XAUXAG-MVDW-RV-20260902
ea_id: QM5_41282
slug: xauxag-mvdw-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41282_xauxag-mvdw-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41282_xauxag_monthly_van_der_waerden_reversion_g0.md
source_approval: decisions/2026-09-02_xauxag_monthly_van_der_waerden_reversion_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Bartel Leendert van der Waerden; Karsten Schweikert; CME Group; NIST/SEMATECH; SAS Institute"
source_citation: "OpenAI Codex (2026), XAU/XAG monthly Van der Waerden normal-score location-shift reversion; supporting records Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread; NIST/SEMATECH and SAS/STAT official Van der Waerden score and exact-test records."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). XAU/XAG monthly Van der Waerden normal-score reversion."
    location: "strategy-seeds/sources/AI-CODEX-XAUXAG-MVDW-RV-20260902/source.md"
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
    citation: "NIST/SEMATECH Dataplot and SAS/STAT. Van der Waerden normal scores and exact two-sample linear-rank test."
    location: "strategy-seeds/sources/AI-CODEX-XAUXAG-MVDW-RV-20260902/retrieval_route_vdw_scores_20260902.json"
    quality_tier: A
    role: normal_quantile_score_formula_location_interpretation_and_exact_test_identity_only
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-month-log-ratio-endpoints-twelve-adjacent-changes-fixed-six-old-six-recent-strict-pooled-ranks-van-der-waerden-normal-scores-exact-924-inclusive-absolute-tail462-score-sign-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XAUXAG-MVDW-RV-20260902]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/nonparametric-location-shift]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio-change]]"
  - "[[indicators/van-der-waerden-normal-score-location-state]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, van-der-waerden, signed-normal-score, nonparametric-location-state, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41282_XAU_XAG_VDW_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412820000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 6 completed XAU/XAG packages per full post-warm-up year before change ties, exact zero scores, market-data, and execution gates; one consumed attempt per broker month. The frozen strict-rank support admits 462 of 924 assignments, split 231/231 by side."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_OFFICIAL_METHOD_EVIDENCE
r1_reasoning: "One durable AI source; complete governed peer-reviewed gold/silver evidence and adverse findings; official exchange evidence; complete bounded official NIST and SAS method pages; hashes and explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronization, endpoints, changes, strict ties, pooled ranks, twelve signed normal-score numerators, all 924 labels, absolute-tail boundary, score-sign side, attempt, aggregate risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories and MT5 state supply every runtime input; synchronization, continuous-CFD basis, financing, calendar, and legging risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, bounded sorting and signed-integer enumeration, ATR risk controls, quotes, positions, deals, and persistent attempt state; no trained output, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; 12 adjacent log-ratio changes; fixed old/recent blocks of 6; pooled strict relative tie epsilon 1e-12; ascending ranks 1..12; Van der Waerden Phi^-1(r/13) scores frozen as signed integer numerators over 1e15; score numerator sum zero; all 924 six-rank assignments; 20 exact zero states; inclusive absolute-tail cap 462; score-sign contrarian side; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a monthly signed-normal-score gold/silver location-shift fade outside the directional XAU/SP500/NDX/XNG book. Verify synchronization, change orientation, strict ranks, twelve frozen numerators, exact 924 enumeration, absolute tail 462, score-sign side, consumed month, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_log_ratio_change_orientation, fixed_six_old_six_recent_membership, pooled_change_tie_rejection, ascending_pooled_change_ranks, exact_signed_normal_score_numerators, exact_924_label_enumeration, inclusive_absolute_tail_462, score_sign_contrarian_pair_sides, no_pvalue_or_critical_value_claim, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41282_xauxag_monthly_van_der_waerden_reversion_g0.md: R1 passes through one durable AI source, complete peer-reviewed carrier evidence, official exchange evidence, complete bounded official NIST and SAS method pages, hashes, adverse findings, and explicit synthesis boundaries; R2 locks synchronization, changes, ties, ranks, frozen scores, enumeration, boundary, side, attempt, aggregate risk, atomicity, and lifecycle; R3 uses registered native XAU/XAG D1 with synchronization/CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,781 registry rows, 1,417 cards, and 45 Wiki nodes; fixed fixtures prove two-way decision disagreement with Savage and Wilcoxon neighbors."
---

# QM5_41282 XAU/XAG Monthly Van der Waerden Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. At the first tradable D1
boundary of each broker month, compare the newest six completed monthly
changes in `ln(XAU)-ln(XAG)` with the prior six. When the recent block carries
an exact upper-half two-sided Van der Waerden normal-score displacement, fade
the signed location shift for one broker month.

Opposite equal-target-notional legs aim to reduce outright XAU direction and
create a market-neutral-style stream distinct from the directional
XAU/SP500/NDX/XNG book. They do not prove neutrality or decorrelation. Q02
owns activity/economics, later gates own robustness, and unchanged Q09 alone
owns realized overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MVDW-RV-20260902/source.md`. Its
source approval was committed as `396bdf003a` before extraction.

Schweikert supports only a state-dependent gold/silver carrier and supplies
binding adverse evidence. CME supports the ratio definition, different demand
drivers, and opposed-leg form. NIST and SAS support only the signed normal-
quantile rank scores, their location interpretation, and exact two-sample
linear-rank identity. The exact monthly sample, score freeze, 462-tail
activity boundary, contrarian direction, CFD mapping, risk, attempt state,
atomicity, and lifecycle are pre-result QM hypotheses. No source supplies a
profitable rule or transfers a p-value, critical value, return, drawdown,
frequency, neutrality, or correlation claim.

## Non-Duplicate Decision

The corrected-root receipt found no exact identity and surfaced only shared-
carrier fuzzy neighbors. This card ranks raw pooled changes and sums signed
normal-quantile scores. It is not Savage's harmonic exponential-order score,
linear Wilcoxon rank sum, Klotz's block-centered squared-normal score,
Conover's squared ranks of centered absolute deviations, Cucconi's correlated
squared-rank quadratic, or an ECDF path statistic.

Frozen fixtures prove two-way decision disagreement:

| fixture | this card | nearest neighbor |
|---|---|---|
| Van der Waerden-only `RRROOOORORRO` | numerator -1132695640151654, tail 422, BUY XAU | Savage tail 616 and Wilcoxon tail 544, flat |
| Wilcoxon-only `RRROROOOOORR` | tail 476, flat | Wilcoxon centered rank sum -5, tail 448, BUY XAU |
| Savage-only `RRROOOOOORRR` | exact zero, flat | Savage score 1.3414502164502164, tail 400, SELL XAU |

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_SIX_BY_SIX_RAW_CHANGE_STRICT_RANK_VAN_DER_WAERDEN_SIGNED_NORMAL_QUANTILE_SCORES_EXACT_924_ABSOLUTE_TAIL_462_SCORE_SIGN_CONTRARIAN_BASKET`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_41282_XAU_XAG_VDW_RV_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1.
- Traded dependency slot 1: `XAGUSD.DWX`, D1.
- One consumed decision per broker month at the first synchronized executable
  D1 boundary inside a 180-minute grace window.
- Formation: thirteen consecutive completed synchronized month-end pairs,
  producing twelve adjacent changes in fixed six-old/six-recent blocks.
- Hold: first later broker month; forty elapsed calendar days is the stale
  repair ceiling.
- Expected activity: approximately six packages/year before data and
  execution gates; Q02 retires any full scored year below five.

## Formula

For chronological completed-month close pairs `i=0..12`:

```text
q[i] = ln(XAU[i]) - ln(XAG[i])
r[i] = q[i+1] - q[i], i=0..11

old = r[0..5]; recent = r[6..11]
require every pair of r values differs by more than
1e-12 * max(1,abs(left),abs(right))

strictly rank all twelve pooled r values ascending
R = the six ranks owned by recent
n(r) = round(Phi^-1(r/13) * 10^15), frozen by table
S = sum(n(r) for r in R)

enumerate all 924 choices of six ranks from 1..12
tail = count(abs(S_perm) >= abs(S))
require tail <= 462 and S != 0

S < 0 -> BUY XAU / SELL XAG
S > 0 -> SELL XAU / BUY XAG
```

The twelve frozen signed numerators are:

```text
-1426076872272847 -1020076232786202 -736315917376130 -502402223373355
-293381232121193  -96558615289639    96558615289639   293381232121193
 502402223373355   736315917376130   1020076232786202 1426076872272847
```

Their sum must equal zero. Enumeration must yield exactly 924 assignments.
Twenty label assignments have exact zero score and remain flat. The tail is
an exact label count and activity gate, not a probability claim.

## Rules

1. Run only on the exact XAU D1 host with both registered symbols and governed
   slots/magics available.
2. At a new broker month inside the grace window, record the attempt before
   any data or signal calculation; never retry that month.
3. Reconstruct thirteen consecutive synchronized completed-month pairs. The
   newest endpoint must immediately precede the current month and be no more
   than ten calendar days stale.
4. Compute the exact formula and fail flat on invalid prices, missing months,
   any relative tie, score-table invariant failure, enumeration mismatch,
   exact zero score, tail above 462, stale quotes, excessive spread, invalid
   ATR, invalid fixed-risk mode, or unalignable notionals.
5. Enter one opposed package in the score-sign contrarian direction.
6. Exit both legs at the first later broker month, after forty elapsed days,
   on package corruption, broker hard stop, or kill switch.

## Entry Rules

- Require no owned exposure on either slot and no foreign position on either
  traded symbol.
- Require `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` for the backtest preset.
- Require XAU/XAG spreads no greater than 1,500/500 points.
- Require finite closed D1 `ATR(20)` for both legs and freeze stop distance at
  `3.5*ATR`.
- Give each leg at most half the aggregate frozen-stop risk budget.
- Reduce volumes only until absolute USD target notionals differ by no more
  than 20 percent.
- Submit XAU first and XAG second through governed basket order handling.
- If both expected legs do not exist after submission, flatten every owned
  leg immediately and consume the month.

## Exit Rules

- First later broker month: close both legs with time-stop reason.
- Forty elapsed calendar days from package entry: close both legs as stale.
- Missing, same-side, duplicated, or otherwise malformed owned package: close
  all owned legs immediately.
- Broker hard stops and kill switch remain authoritative.
- No profit target, score reversal, partial close, scale-in, or intramonth
  re-entry.

## Filters And No-Trade Module

- Both news axes and the legacy news mode are OFF.
- Friday close is OFF because the structural package may span weekends.
- Stress rejection is zero in the Q02 preset.
- Spread, quote, synchronization, history, score, risk-mode, and foreign-
  position gates fail closed.
- The no-trade hook never closes exposure; lifecycle and repair stay in trade
  management.

## Trade Management Rules

- Refresh expected package direction from persistent owned state after a
  restart.
- Validate both owned legs on every management call.
- Close all owned legs on malformed package, next-month boundary, or forty-
  day stale boundary.
- Use governed close helpers and stable reason codes for both legs.

## Parameters To Test

The Q02 baseline is locked, not an optimization surface:

| parameter | value |
|---|---:|
| synchronized endpoints | 13 |
| adjacent changes | 12 |
| old/recent block | 6 / 6 |
| relative tie epsilon | 1e-12 |
| score denominator | 1e15 |
| assignment count | 924 |
| inclusive tail maximum | 462 |
| history bars | 900 D1 |
| month-entry grace | 180 minutes |
| endpoint staleness | 10 days |
| ATR period / multiplier | 20 / 3.5 |
| XAU/XAG spread ceilings | 1500 / 500 points |
| notional mismatch maximum | 20% |
| stale exit | 40 days |

Changing any value creates a new variant and requires fresh evidence.

## Source-Defined Rules

- Schweikert: gold/silver dependence is state-dependent and asymmetric; the
  source does not provide an executable forecast and supplies adverse
  evidence against a stable constant spread.
- CME: the price ratio is a valid opposed-leg relative-value carrier with
  distinct gold and silver demand drivers.
- NIST/SAS: Van der Waerden scores are `Phi^-1(r/(N+1))`, are primarily
  location scores, and support an exact two-sample linear-rank test.

No source defines the trading conjunction or performance expectation.

## QM Interpretations

- Monthly ratio-change sample and fixed six/six blocks.
- Strict tie rejection and fifteen-decimal signed-integer score freeze.
- Complete 924-label two-sided tail and 462 activity boundary.
- Contrarian score-sign direction and one-month hold.
- CFD symbols, fixed risk, ATR stops, equal-notional reduction, spread caps,
  attempt state, atomic repair, and stale exit.

These are disclosed pre-result choices, not source findings.

## Framework Execution Overrides

- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode: OFF.
- Friday close: OFF.
- Stress rejection: zero.
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

Retire or fail closed on any formula/fixture mismatch, accepted change tie,
invalid score-table sum, invalid enumeration, source/card/EA/set constant
mismatch, zero completed packages, fewer than five in any full post-warm-up
year, component-leg fanout, missing logical set/manifest/registry,
nonpositive governed economics, orphan leg, aggregate-risk double counting,
lifecycle deviation, or later gate failure.

## Expected Behavior

- Approximately six monthly packages per full year after warm-up.
- Both long-ratio and short-ratio packages are possible.
- Intramonth holding and cross-weekend exposure are expected.
- PnL is combined two-leg relative-value PnL, not per-leg alpha.
- No profitability or correlation level is presumed.

## Logging

Log broker month, endpoint keys/timestamps, twelve changes, pooled ranks and
labels, recent signed score numerator, assignment count, tail count,
direction, quotes/spreads, ATR/stops, volumes, notionals, magics,
order/repair results, and exit reason.

## Framework Alignment

| card rule | module |
|---|---|
| identity, host, fixed-risk/news/Friday contract, month attempt, history, Van der Waerden arithmetic, package state | `Strategy_NoTradeFilter` and bounded helpers |
| quotes, spreads, ATR, sizing, equal-notional reduction, atomic two-leg submission | `Strategy_EntrySignal` |
| malformed-package repair, next-month exit, forty-day exit | `Strategy_ManageOpenPosition` |
| broker/framework reason mapping | `Strategy_ExitSignal` and V5 close helper |

The no-trade hook must never close exposure. Basket repair and lifecycle belong
in management. The build must use `QM_MagicChecked` and `QM_BasketOrder`; no
manual magic arithmetic or raw ungoverned order path.

## Falsification And Requalification

Any change to symbols, period, endpoint count, block membership, tie rule,
scores, enumeration, tail cap, direction, risk, stops, spread ceilings,
notional tolerance, attempt state, atomicity, or hold requires a new
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
| v1 | 2026-09-02 | initial monthly Van der Waerden XAU/XAG card | G0 | APPROVED; build pending |

## Pipeline History

| version | date | rebuild reason | Q-stage reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial build | Q01 | IN_PROGRESS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41282_xauxag_monthly_van_der_waerden_reversion_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
