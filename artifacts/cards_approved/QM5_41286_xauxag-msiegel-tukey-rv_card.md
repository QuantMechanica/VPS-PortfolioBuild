---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902_S01
variant_id: AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902_S01
source_id: AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902
ea_id: QM5_41286
slug: xauxag-msiegel-tukey-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41286_xauxag-msiegel-tukey-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41286_xauxag_monthly_siegel_tukey_reversion_g0.md
source_approval: decisions/2026-09-02_xauxag_monthly_siegel_tukey_reversion_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Sidney Siegel; John W. Tukey; Karsten Schweikert; CME Group; NIST/SEMATECH
source_citation: "OpenAI Codex (2026), XAU/XAG monthly Siegel-Tukey tail-occupancy reversion; supporting records Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group Gold & Silver Ratio Spread; Siegel and Tukey (1960), JASA 55(291), DOI 10.1080/01621459.1960.10482073; NIST Dataplot Siegel Tukey Test."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). XAU/XAG monthly Siegel-Tukey tail-occupancy reversion."
    location: strategy-seeds/sources/AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902/source.md
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_risk_and_lifecycle
  - type: peer_reviewed_carrier_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete-read packet strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_carrier_and_adverse_evidence_only
  - type: official_exchange_carrier
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md
    quality_tier: A
    role: ratio_definition_distinct_demand_drivers_and_opposed_leg_carrier_only
  - type: peer_reviewed_and_official_statistical_method
    citation: "Siegel and Tukey (1960), JASA 55(291), 429-445; NIST/SEMATECH Dataplot Siegel Tukey Test."
    location: strategy-seeds/sources/AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902/retrieval_route_20260902.json
    quality_tier: A
    role: alternating_extremes_rank_construction_and_method_identity_only
strategy_mechanic: monthly-xauxag-seventeen-synchronized-completed-month-log-ratio-endpoints-sixteen-adjacent-changes-fixed-eight-old-eight-recent-siegel-tukey-alternating-extremes-rank-sum-exact-12870-inclusive-lower-tail6698-recent-cumulative-move-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/nonparametric-tail-occupancy-state]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio-change]]"
  - "[[indicators/siegel-tukey-alternating-extremes-rank-sum]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, siegel-tukey, alternating-extremes-rank-state, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41286_XAU_XAG_ST_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412860000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 6 completed XAU/XAG packages per full post-warm-up year before change ties, neutral cumulative moves, market-data, and execution gates; one consumed attempt per broker month. Exact pre-data strict-rank state support is 6.245 per twelve attempts."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_PEER_REVIEW_EXCHANGE_AND_OFFICIAL_METHOD_EVIDENCE
r1_reasoning: "One durable AI source; complete governed peer-reviewed gold/silver evidence and adverse findings; official exchange carrier evidence; original peer-reviewed method metadata; complete official NIST algorithm evidence; explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronization, endpoints, changes, eight/eight blocks, strict ties, score path, all 12,870 assignments, inclusive 68/6,698 boundary, contrarian side, consumed attempt, aggregate risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_qualification: SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories and MT5 state supply every runtime input; synchronization, roll, financing, calendar, and legging risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, fixed ranks, bounded enumeration, comparisons, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, random runtime path, prohibited signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 17 synchronized endpoints; 16 adjacent log-ratio changes; fixed old/recent blocks of 8; pooled relative tie epsilon 1e-12; ascending-observation Siegel-Tukey score path 1,4,5,8,9,12,13,16,15,14,11,10,7,6,3,2; all 12,870 recent-label assignments; recent score at most 68; inclusive lower-tail cap 6,698; recent cumulative-move contrarian side; 1200 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a monthly tail-occupancy gold/silver relative-change fade outside the directional XAU/SP500/NDX/XNG book. Verify synchronization, change orientation, eight/eight membership, strict ties, score path, 12,870 assignments, inclusive 68/6,698 boundary, recent-move contrarian sides, consumed month, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, seventeen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_log_ratio_change_orientation, fixed_eight_old_recent_membership, pooled_change_tie_rejection, exact_siegel_tukey_score_path, exact_12870_label_enumeration, inclusive_score_68, inclusive_lower_tail_6698, recent_move_contrarian_pair_sides, no_pvalue_or_critical_value_claim, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission: R1 governed source plus peer-reviewed, CME, and NIST evidence; R2 exact monthly rank-basket rules; R3 native XAU/XAG D1; R4 deterministic ML-free two-slot package; fuzzy matches manually resolved."
---

# QM5_41286 XAU/XAG Monthly Siegel-Tukey Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. At the first tradable D1
boundary of each broker month, compare eight older and eight newer completed
monthly changes in `ln(XAU)-ln(XAG)`. When the newer block occupies the
inclusive lower half of the pooled Siegel-Tukey alternating-extremes rank
support, fade its cumulative relative move for one broker month.

Opposed equal-target-notional legs aim to reduce outright precious-metal
direction and create a market-neutral-style stream distinct from the
directional XAU/SP500/NDX/XNG book. They do not prove neutrality,
profitability, or decorrelation. Q02 owns activity and economics; unchanged
Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902/source.md`,
SHA-256
`2C7D7E7DE91C4B8A739E76A016AB3BB6D6C0529AC41FF436267EF2AAF8DDA259`,
approved at commit `6a5fd1d59b` before card extraction.

Schweikert supports only a state-dependent gold/silver carrier and supplies
binding adverse evidence against a constant spread. CME supports the ratio
definition, different demand drivers, and opposed-leg form. Siegel-Tukey
publisher metadata and the complete NIST record support only the
alternating-extremes rank construction. The original article body was
access-controlled and is not claimed read. The exact time blocks, activity
boundary, trading side, CFD mapping, risk, and lifecycle are QM choices.

No source return, p-value, significance, activity, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, correlation, or portfolio result
transfers.

## Non-Duplicate Decision

The fail-closed corrected-root receipt
`artifacts/qm5_xauxag_msiegel_tukey_rv_preallocation_dedup_20260902.json`
found no exact identity across 4,785 registry rows, 1,421 cards, and 45 Wiki
nodes. The expected direct-WTI method parent and XAU/XAG rank-method neighbors
were manually resolved.

- `QM5_41271` trades direct WTI continuation. This card trades a synchronized
  XAU/XAG relative carrier with opposed legs and fades its recent relative
  move.
- Van der Waerden, Cucconi, Kuiper, and Savage siblings use twelve changes,
  six-by-six labels, and different score functions. This rule uses sixteen
  changes, eight-by-eight labels, and a nonmonotone extremes score path.
- Brown-Forsythe, Klotz, and Conover siblings center deviations or use
  different scale scores; this rule ranks raw relative changes.
- Fixed fixtures prove both disagreement directions against the closest
  latest-twelve linear-score neighbors.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_EIGHT_BY_EIGHT_SIEGEL_TUKEY_ALTERNATING_EXTREMES_LOWER_HALF_RECENT_MOVE_CONTRARIAN_BASKET`.

## Markets, Timeframe, And Cadence

- Host and slot 0: exact `XAUUSD.DWX`, D1.
- Second leg and slot 1: exact `XAGUSD.DWX`, D1.
- Logical basket: `QM5_41286_XAU_XAG_ST_RV_D1`.
- Decision clock: first executable tick after a genuine normalized broker-month
  transition, within 180 elapsed minutes of the host D1 boundary.
- Formation: seventeen consecutive completed synchronized month-end pairs;
  every current-month price is excluded.
- Hold: next broker month, with forty-calendar-day stale repair.
- Expected cadence: approximately six completed packages per full post-warm-up
  year. Q02 retires any full scored year below five.

## Formula

For chronological synchronized completed-month pairs `i=0..16`:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[i] = q[i+1] - q[i], i=0..15
old = r[0..7]
recent = r[8..15]
```

Require all changes finite and pairwise distinct under
`1e-12*max(1,abs(left),abs(right))`. Sort all sixteen ascending while retaining
old/recent labels, then assign:

```text
rank position:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16
ST score:       1  4  5  8  9 12 13 16 15 14 11 10  7  6  3  2
S_recent = sum(ST score at recent-labelled rank positions)
```

Enumerate every sixteen-bit mask with exactly eight recent labels. Require
exactly 12,870 assignments and count every `S_perm <= S_recent`. The state
qualifies iff `S_recent<=68` and the inclusive lower-tail count is at most
6,698. Their equivalence is a runtime invariant.

```text
recent_move = sum(r[8..15])
qualify and recent_move > +1e-12 => SELL XAU / BUY XAG
qualify and recent_move < -1e-12 => BUY XAU / SELL XAG
otherwise                         => consume month flat
```

Score and move magnitude never size risk. The overlapping time blocks are not
independent samples; no inferential interpretation is authorized.

## Rules

- Consume the normalized broker month before history, signal, news, spread,
  quote, ATR, sizing, margin, or submission gates. Never retry that month.
- Select the latest timestamp-matched close pair in each immediately prior
  consecutive broker month from a bounded 1,200-D1 buffer.
- Reject current-month input, missing/duplicate/nonconsecutive months,
  nonchronological or mismatched timestamps, nonpositive closes, stale newest
  endpoints, nonfinite arithmetic, pooled ties, or invariant mismatch.
- Permit no foreign position on either symbol and no pre-existing owned
  exposure before a new package.
- Both news axes, legacy mode, Friday close, and stress rejection are OFF.
- No optimization surface exists for Q02.

## 4. Entry Rules

1. Require EA ID 41286, exact host `XAUUSD.DWX`, D1, slot 0, both registered
   magics, fixed-risk mode, framework defaults, and every locked input.
2. Run malformed-package and time-exit management before entry-only gates.
3. Require a genuine new broker month inside the 180-minute entry window.
4. Persist the month attempt before every fallible gate.
5. Reconstruct seventeen synchronized completed endpoints and compute the
   sixteen chronological relative changes.
6. Apply strict tie rejection, the exact score path, all 12,870 allocations,
   the inclusive `68/6698` gate, and the contrarian side map.
7. Require both symbols trade-enabled with valid quotes, contract/tick/volume
   metadata, margins, and spreads no greater than 1,500/500 points.
8. Use closed D1 ATR(20) for two frozen `3.5*ATR` hard stops.
9. Split one aggregate `RISK_FIXED=1000` stop-risk budget equally across the
   legs, then reduce volume only until absolute USD target notionals differ by
   at most 20 percent.
10. Submit XAU first and XAG second through governed basket order handling. If
    either order fails or composition is malformed, flatten all owned exposure
    immediately. No orphan leg may remain.

## 5. Exit Rules

1. Framework kill switch and broker hard stops remain authoritative.
2. Any malformed composition, wrong side, missing stop, wrong symbol/magic, or
   notional mismatch closes all owned legs immediately.
3. On the first synchronized tick in a broker month later than entry, close
   both legs with time-stop reason.
4. At forty elapsed calendar days, close both legs as stale repair.
5. There is no target, convergence exit, opposite signal, intramonth flip,
   Friday flatten, trail, break-even, partial close, scale-in, or pyramid.

## 6. Filters (No-Trade Module)

- Fail closed on wrong host, period, identity, slot, magic, risk, news,
  Friday-close, stress, or locked-input contract.
- Fail closed on stale or unsynchronized history, nonconsecutive month keys,
  bad closes, changes, ties, score path, assignment count, tail equivalence,
  neutral direction, spreads, quotes, ATR, sizing, or margin.
- The no-trade hook never closes exposure. Package repair and lifecycle belong
  in management.
- Runtime may not use futures chains, external files/APIs, volume, inventory,
  forecasts, optimizer output, portfolio state, or trained artifacts.

## 7. Trade Management Rules

- Exactly zero or two owned positions are valid; any other count triggers an
  immediate close-all repair.
- Exactly one XAU slot-0 leg and one XAG slot-1 leg with opposed expected sides
  and nonzero frozen stops are required.
- Entry notionals must remain inside the locked 20-percent mismatch ceiling.
- Refresh expected package direction from terminal-persistent state after a
  restart.
- No re-hedge, resize, stop move, retry, partial close, scale-in, or new signal
  is authorized during the hold.

## Parameters To Test

Q02 has one locked baseline:

| parameter | value |
|---|---:|
| synchronized endpoints | 17 |
| adjacent changes | 16 |
| old / recent block size | 8 / 8 |
| relative tie epsilon | `1e-12` |
| ascending-value ST path | `1,4,5,8,9,12,13,16,15,14,11,10,7,6,3,2` |
| labeled assignments | 12,870 |
| inclusive score max | 68 |
| inclusive lower-tail max | 6,698 |
| D1 history buffer | 1,200 bars |
| entry grace | 180 minutes |
| endpoint gap ceiling | 10 days |
| ATR stop | `3.5*ATR(20,D1)` |
| target notional ratio | 1.0 |
| max notional mismatch | 20% |
| stale hold ceiling | 40 days |
| XAU/XAG spread ceilings | 1,500 / 500 points |

Changing any value creates a new variant and requires fresh evidence.

## Expected Behavior And Frequency

Complete label enumeration gives 6,698 qualifying assignments out of 12,870,
or `0.5204351204351204`, including 526 exactly at score 68. This is a
market-free state-density prior of 6.245 per twelve attempts, not a realized
package or performance estimate. Both ratio directions are possible. The PnL
unit is the combined two-leg package, never either component alone.

## Risk

| item | contract |
|---|---|
| backtest risk mode | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| portfolio weight | 1.0 |
| package allocation | half frozen stop-risk budget per leg |
| stops | `3.5*ATR(20,D1)` per leg, frozen at entry |
| hedge target | equal absolute USD notionals, reduction only |
| notional tolerance | maximum 20% mismatch |
| concurrent exposure | one logical two-leg package |
| statistic sizing | forbidden |
| live risk | not authorized |

Aggregate fixed risk must not be applied once per leg. Rounded volume may only
be reduced, never increased beyond either half-budget cap. Gaps and legging can
exceed modeled stop risk and remain pipeline risks.

## Source-Defined Rules

- Gold and silver have a state-dependent relationship and distinct demand
  drivers; constant-spread assumptions carry adverse evidence.
- The Siegel-Tukey construction pools two samples, sorts values, assigns ranks
  by alternating extremes, and reduces the comparison to a rank sum.
- Smaller transformed-rank sums represent greater occupancy of pooled extremes
  for the labelled sample.

No source defines this time-series sample, half-support boundary, side, fixed
risk, continuous-CFD mapping, or performance.

## QM Interpretations

- Seventeen synchronized month-end pairs, fixed eight/eight blocks, strict
  relative tie rejection, exhaustive label enumeration, and inclusive
  `68/6698` activity boundary.
- Fade of the recent cumulative log-ratio change for one month.
- Consumed month, entry grace, endpoint staleness, aggregate risk, equal target
  notionals, per-leg ATR stops, spread caps, sequential submission repair, and
  stale lifecycle.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- `qm_stress_reject_probability=0` in the canonical baseline.
- Kill-switch, weekend, broker-disconnect, and hard-stop coverage remain active.

## Exit Precedence

1. Kill switch / broker hard stop.
2. Malformed or incomplete package repair.
3. Next synchronized broker-month exit.
4. Forty-day stale exit.
5. No other strategy or framework calendar exit.

## Runtime Data Dependencies

- Native `XAUUSD.DWX` and `XAGUSD.DWX` D1 time/close history.
- Native closed D1 ATR values for both symbols.
- Broker time/month, quotes, spread, symbol metadata, margin, positions, deals,
  and terminal globals for attempt/package persistence.
- Tester host `XAUUSD.DWX`, account currency USD, deposit 100,000.
- Logical-basket Q02 window `2018.07.02` through `2024.12.31`.
- No external API, calendar, file, trained artifact, or future price.

## Execution Assumptions

- Both registered custom symbols are available and timestamp-synchronized in
  the tester.
- Opposed CFD legs are sequential, not an atomic exchange spread; legging and
  repair risk remain.
- Equal notionals do not remove basis, volatility, financing, factor, or
  portfolio risk.
- The logical basket is evaluated as one work item; component sets are schema
  validation artifacts, not standalone Q02 strategies.

## Failure Conditions

Retire or fail closed on any formula/fixture mismatch, accepted change tie,
score-path, assignment, or tail mismatch, source/card/EA/set constant mismatch,
zero completed packages, fewer than five in a full scored post-warm-up year,
component-leg fanout, missing logical manifest/registry, nonpositive governed
economics, orphan leg, aggregate-risk double counting, lifecycle deviation, or
later gate failure.

## Logging

Log broker month, endpoint keys/timestamps, sixteen changes, rank labels,
Siegel-Tukey score, assignment and tail counts, recent move, direction,
quotes/spreads, ATR/stops, volumes, notionals, magics, submission/repair result,
and exit reason. Never log credentials or external account data.

## Framework Alignment

| card rule | module |
|---|---|
| identity, host, risk/news/Friday contract, month attempt, history, rank arithmetic, package state | `Strategy_NoTradeFilter` and bounded helpers |
| quotes, spreads, ATR, sizing, equal-notional reduction, atomic two-leg submission | `Strategy_EntrySignal` |
| malformed-package repair, next-month exit, forty-day stale repair | `Strategy_ManageOpenPosition` |
| broker/framework reason mapping | `Strategy_ExitSignal` and V5 close helper |

The build must use `QM_MagicChecked` and `QM_BasketOrder`; no manual magic
arithmetic or raw ungoverned order path is authorized.

## Falsification And Requalification

Any change to symbols, period, endpoints, block membership, tie rule, score
path, enumeration, boundary, direction, risk, stops, spreads, notional
tolerance, attempt state, atomicity, or hold requires a new source/card,
binary, Q02-Q10 evidence, and Q09 requalification. A downstream failure cannot
be repaired inside this card.

## Safety Boundary

Authorized: deterministic identity/magic allocation, branch-only non-live
build, reference tests, strict Q01, one logical fixed-risk set plus two
component validation sets, and one paced logical-basket Q02 enqueue below the
whole-host CPU ceiling.

Forbidden: optimization, manual tester launch, live/demo/shadow/stress sets,
component Q02 rows, portfolio-gate edit, correlation waiver, portfolio
admission, deploy/live manifest, `T_Live`, AutoTrading, or terminal control.

## Revision History

| version | date | reason | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial XAU/XAG Siegel-Tukey reversion card | G0 | APPROVED; build pending |

## Pipeline History

| version | date | rebuild reason | Q-stage reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial build | Q01 | IN_PROGRESS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-02 | APPROVED_SOURCE | `decisions/2026-09-02_xauxag_monthly_siegel_tukey_reversion_source_approval.md` |
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41286_xauxag_monthly_siegel_tukey_reversion_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
