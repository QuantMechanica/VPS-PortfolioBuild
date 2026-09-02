---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XAUXAG-MJT-RV-20260902_S01
variant_id: AI-CODEX-XAUXAG-MJT-RV-20260902_S01
source_id: AI-CODEX-XAUXAG-MJT-RV-20260902
ea_id: QM5_41285
slug: xauxag-mjt-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41285_xauxag-mjt-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41285_xauxag_monthly_jonckheere_terpstra_reversion_g0.md
source_approval: decisions/2026-09-02_xauxag_monthly_jonckheere_terpstra_reversion_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; A. R. Jonckheere; T. J. Terpstra; Karsten Schweikert; CME Group; NIST/SEMATECH; Bilge Altunkaynak; Hamza Gamgam
source_citation: "OpenAI Codex (2026), XAU/XAG monthly Jonckheere-Terpstra ordered-block reversion; supporting records Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; CME Group Gold & Silver Ratio Spread; Jonckheere (1954), Biometrika 41(1-2), DOI 10.1093/biomet/41.1-2.133; NIST/SEMATECH and The R Journal method records."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). XAU/XAG monthly Jonckheere-Terpstra ordered-block reversion."
    location: strategy-seeds/sources/AI-CODEX-XAUXAG-MJT-RV-20260902/source.md
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
  - type: official_and_peer_reviewed_statistical_method
    citation: "NIST/SEMATECH Dataplot Jonckheere-Terpstra Test; Altunkaynak and Gamgam (2020), The R Journal 12(1); Jonckheere (1954), Biometrika 41(1-2), 133-145."
    location: strategy-seeds/sources/AI-CODEX-XAUXAG-MJT-RV-20260902/retrieval_route_20260902.json
    quality_tier: A
    role: ordered_group_pair_count_statistic_and_method_identity_only
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-month-log-ratio-endpoints-twelve-adjacent-changes-three-chronological-four-return-blocks-jonckheere-terpstra-48-cross-block-ordered-win-score-exact-34650-two-sided-threshold29-contrarian-equal-notional-basket
sources:
  - "[[sources/AI-CODEX-XAUXAG-MJT-RV-20260902]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/nonparametric-ordered-block-state]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio-change]]"
  - "[[indicators/jonckheere-terpstra-ordered-win-count]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, jonckheere-terpstra, ordered-block-state, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41285_XAU_XAG_JT_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412850000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 6 completed XAU/XAG packages per full post-warm-up year before change ties, market-data, and execution gates; one consumed attempt per broker month. Exact pre-data strict-rank density is 6.246 directional states per twelve attempts."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_PEER_REVIEW_AND_OFFICIAL_METHOD_EVIDENCE
r1_reasoning: "One durable AI source; complete governed peer-reviewed gold/silver evidence and adverse findings; official exchange carrier evidence; complete bounded official NIST and peer-reviewed R Journal method sections; original peer-reviewed metadata; explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronization, endpoints, changes, three fixed groups, strict ties, all 48 cross-group comparisons, exact 34,650-label enumeration, two-sided tail 18,034, contrarian side, attempt, aggregate risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XAUUSD.DWX and XAGUSD.DWX D1 histories and MT5 state supply every runtime input; synchronization, continuous-CFD basis, financing, calendar, and legging risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, comparisons, bounded integer enumeration, ATR risk controls, quotes, positions, deals, and persistent state; no trained output, random runtime sampling, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; 12 adjacent log-ratio changes; 3 chronological groups of 4; pooled relative tie epsilon 1e-12; 48 ordered cross-group comparisons; score center 24; all 34,650 labeled 4/4/4 rank allocations; inclusive two-sided tail cap 18,034; equivalent lower/upper score boundaries 19/29; contrarian side; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a monthly ordered-block gold/silver relative-change fade outside the directional XAU/SP500/NDX/XNG book. Verify synchronization, change orientation, three fixed groups, strict ties, 48 comparisons, 34,650 allocations, tail 18,034, equivalent 19/29 boundary, contrarian sides, consumed month, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_log_ratio_change_orientation, fixed_three_by_four_membership, pooled_change_tie_rejection, all_48_ordered_cross_group_pairs, exact_34650_label_enumeration, inclusive_two_sided_tail_18034, equivalent_score_boundaries_19_29, contrarian_pair_sides, no_pvalue_or_critical_value_claim, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41285_xauxag_monthly_jonckheere_terpstra_reversion_g0.md: R1 passes through one durable AI source, complete peer-reviewed carrier evidence, official exchange evidence, complete bounded NIST and R Journal method records, original peer-reviewed metadata, adverse findings, and explicit synthesis boundaries; R2 locks synchronization, changes, groups, ties, comparisons, enumeration, tail, side, attempt, aggregate risk, atomicity, and lifecycle; R3 uses registered native XAU/XAG D1 with synchronization/CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,784 registry rows, 1,420 cards, and 45 Wiki nodes; fixed fixtures prove candidate-only, neighbor-only, and opposite-side decisions."
---

# QM5_41285 XAU/XAG Monthly Jonckheere-Terpstra Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. At the first tradable D1
boundary of each broker month, divide the latest twelve completed monthly
changes in `ln(XAU)-ln(XAG)` into three chronological four-change groups.
When all cross-group comparisons show a sufficiently ordered displacement,
fade that relative move for one broker month.

Opposite equal-target-notional legs aim to reduce outright XAU direction and
create a market-neutral-style stream distinct from the directional
XAU/SP500/NDX/XNG book. They do not prove neutrality or decorrelation. Q02
owns activity and economics, later gates own robustness, and unchanged Q09
alone owns realized overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MJT-RV-20260902/source.md`, SHA-256
`B24C7C7C7E31C32790BFD07C3060DA3AEA0C25177E74C9D1135AD1E8C8743633`,
approved at commit `9c63983aa8` before card extraction.

Schweikert supports only a state-dependent gold/silver carrier and supplies
binding adverse evidence. CME supports the ratio definition, different demand
drivers, and opposed-leg form. NIST and The R Journal support only the classic
ordered-group pair-count statistic. Jonckheere supplies original method
metadata; the paywalled article body is not claimed read. The exact time-series
grouping, enumeration boundary, side, CFD mapping, risk, and lifecycle are
pre-result QM synthesis. No source performance or inferential result transfers.

## Non-Duplicate Decision

The corrected-root receipt
`artifacts/qm5_xauxag_mjt_rv_preallocation_dedup_20260902.json`, SHA-256
`E103D2C5F4751B0AB5B228C898DFC85AD49C4C801D29939FB1A4D0C753CBB944`,
found no exact identity. Five fuzzy matches share only the carrier and use
channel, OLS, fixed-horizon reversal, realized-jump, or median/MAD mechanics.

The closest functional neighbors are also distinct. `QM5_41116` votes three
blocks inside one completed month. `QM5_41274` counts 75 comparisons across
fifteen within-month WTI daily closes and always takes a side. `QM5_41177`
uses one six/six Mann-Whitney comparison. This card uses twelve completed
monthly relative changes, three labeled four-change groups, all 48 ordered
cross-group pairs, a complete 34,650-label tail, a neutral band, and an
opposed contrarian package.

Frozen chronological-rank fixtures prove separation:

| ranks | this card | neighbor |
|---|---|---|
| `10,3,1,4,12,7,9,6,11,8,2,5` | `J=29`, SELL XAU | Mann-Whitney `U=20`, Van der Waerden tail `748`, flat |
| `7,8,5,12,6,9,1,3,2,10,11,4` | `J=21`, flat | Mann-Whitney `U=10`, BUY XAU |
| `2,8,6,4,11,12,3,1,9,7,5,10` | `J=30`, SELL XAU | Van der Waerden tail `430`, BUY XAU |

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_THREE_BY_FOUR_CLASSIC_JONCKHEERE_TERPSTRA_48_ORDERED_WINS_EXACT_34650_TWO_SIDED_TAIL18034_CONTRARIAN_BASKET`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_41285_XAU_XAG_JT_RV_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1.
- Traded dependency slot 1: `XAGUSD.DWX`, D1.
- One consumed decision per broker month at the first synchronized executable
  D1 boundary inside a 180-minute grace window.
- Formation: thirteen consecutive completed synchronized month-end pairs,
  producing twelve adjacent changes in three fixed groups of four.
- Hold: first later broker month; forty elapsed calendar days is the stale
  repair ceiling.
- Expected activity: approximately six packages/year before data and
  execution gates; Q02 retires any full scored year below five.

## Formula

For chronological completed-month close pairs `i=0..12`:

```text
q[i] = ln(XAU[i]) - ln(XAG[i])
r[i] = q[i+1] - q[i], i=0..11

G0 = r[0..3]
G1 = r[4..7]
G2 = r[8..11]

J = sum I(x<y) for every x in Ga, y in Gb, a<b
require exactly 48 comparisons

enumerate every labeled 4/4/4 allocation of ranks 1..12
require exactly C(12,4)*C(8,4) = 34,650 assignments
tail = count(abs(J_perm-24) >= abs(J-24))

qualify iff tail <= 18,034
equivalently qualify iff J <= 19 or J >= 29

J >= 29 -> SELL XAU / BUY XAG
J <= 19 -> BUY XAU / SELL XAG
FLAT otherwise
```

All twelve changes must be finite and pairwise distinct under
`1e-12*max(1,abs(a),abs(b))`. Runtime enumeration must prove the assignment
count, tail, symmetry, and 19/29 equivalence. The tail is an activity boundary,
not a p-value or published critical value. Score magnitude never scales risk.

## Rules

1. Run only on exact `XAUUSD.DWX`, D1, slot 0, with registered XAG slot 1.
2. Detect a genuine synchronized broker-month transition and persist the
   current month attempt before every downstream gate. Never retry it.
3. Exclude current-month prices; reconstruct the latest exact timestamp-
   matched pair from each of the thirteen immediately preceding months.
4. Require consecutive month keys, chronological positive finite closes, and
   a newest endpoint no more than ten calendar days stale.
5. Compute the locked changes, tie checks, groups, 48 comparisons, complete
   enumeration, tail, equivalence, and contrarian side.
6. Open exactly one opposed-leg package only for a qualifying state.
7. Split one fixed stop-risk budget, align notionals by reducing volume only,
   and require aggregate package integrity.
8. Close both legs at the next synchronized month or forty-day ceiling.

## Entry Rules

- Require exact EA ID `41285`, host, period, slots, and resolved magics.
- Require no owned or foreign exposure on either traded symbol.
- Both current D1 bars must share timestamp and broker day; entry must occur
  within 180 minutes of the host D1 boundary.
- Require `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` in the Q02 preset.
- Both symbols must be trade-enabled with valid quotes, contract/tick/volume
  metadata, margins, and spreads no greater than 1,500/500 points.
- Use closed D1 ATR(20) for each frozen `3.5*ATR` hard stop.
- Allocate half of one aggregate fixed-risk budget to each leg, then reduce
  volumes only until absolute USD target notionals differ by at most 20%.
- `J<=19`: BUY XAU slot 0, then SELL XAG slot 1.
- `J>=29`: SELL XAU slot 0, then BUY XAG slot 1.
- If either submission fails or the resulting pair is malformed, flatten all
  owned exposure immediately. No orphan leg may remain.

## Exit Rules

1. Framework kill-switch and broker hard-stop handling remain authoritative.
2. Any malformed composition, wrong side, missing stop, wrong symbol/magic,
   or notional mismatch closes all owned legs immediately.
3. On the first synchronized tick in a broker month later than entry, close
   both legs with `QM_EXIT_TIME_STOP`.
4. At forty elapsed calendar days, close both legs with time-stop reason.
5. There is no target, convergence exit, opposite signal, intramonth flip,
   Friday flatten, trail, break-even, partial close, scale-in, or pyramid.

## Filters And No-Trade Module

- Fail closed on wrong host/period/identity/slot or unregistered magic.
- Fail closed on bad fixed-risk, news-axis, Friday-close, or stress defaults.
- Fail closed on stale/unsynchronized history or nonconsecutive month keys.
- Fail closed on nonpositive/nonfinite closes, changes, ATR, quotes, spreads,
  tick, contract, margin, or volume metadata.
- Fail closed on any pooled change tie, comparison count other than 48,
  assignment count other than 34,650, tail mismatch, score/tail equivalence
  mismatch, or interior score.
- Both news axes and legacy mode are OFF; Friday close is OFF because the
  one-month relative-value hold is load-bearing.

## Trade Management Rules

- Exactly zero or two owned positions are valid; any other count is repaired
  by closing all owned exposure.
- Exactly one XAU slot-0 leg and one XAG slot-1 leg with opposite expected
  sides and nonzero frozen stops are required.
- Actual entry notionals must remain inside the locked 20-percent mismatch
  ceiling; violation closes the package rather than resizing it.
- Refresh expected package direction from persistent state after restart.
- No re-hedge, scale-in, partial close, stop movement, retry, or new signal is
  authorized during the hold.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| parameter | value |
|---|---:|
| synchronized endpoints | 13 |
| adjacent changes | 12 |
| chronological groups / size | 3 / 4 |
| relative tie epsilon | `1e-12` |
| cross-group comparisons | 48 |
| score center | 24 |
| labeled allocations | 34,650 |
| inclusive two-sided tail cap | 18,034 |
| equivalent lower / upper score | 19 / 29 |
| D1 history buffer | 900 bars |
| entry grace | 180 minutes |
| endpoint gap ceiling | 10 days |
| ATR stop | `3.5*ATR(20,D1)` |
| target notional ratio | 1.0 |
| max notional mismatch | 20% |
| stale hold ceiling | 40 days |
| XAU/XAG spread ceilings | 1500 / 500 points |

Changing any value creates a new variant and requires fresh evidence.

## Source-Defined Rules

- Jonckheere-Terpstra scoring sums all earlier-group/later-group ordered wins
  for a predeclared ordering.
- Gold/silver is a state-dependent intermarket relationship with distinct
  demand drivers and material adverse evidence against a constant spread.

No source defines the exact time groups, label tail, trading side, threshold,
or performance.

## QM Interpretations

- Monthly XAU/XAG log-ratio changes and chronological 4/4/4 grouping.
- Strict tie rejection, full 34,650 fixed-label enumeration, and inclusive
  two-sided tail cap 18,034.
- Contrarian mapping from the ordered-score direction.
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

1. Kill switch / broker hard stop.
2. Malformed or incomplete package repair.
3. Next synchronized broker-month exit.
4. Forty-day stale exit.
5. No other strategy or framework calendar exit.

## Runtime Data Dependencies

- Native `XAUUSD.DWX` and `XAGUSD.DWX` D1 time/close history.
- Native closed D1 ATR values for both symbols.
- Broker time/month, quotes, spread, symbol metadata, margin, positions,
  deals, and terminal globals for attempt and package persistence.
- Tester host `XAUUSD.DWX`, account currency USD, deposit 100,000.
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
comparison or enumeration mismatch, source/card/EA/set constant mismatch,
zero completed packages, fewer than five in any full post-warm-up year,
component-leg fanout, missing logical set/manifest/registry, nonpositive
governed economics, orphan leg, aggregate-risk double counting, lifecycle
deviation, or later gate failure.

## Expected Behavior

- Approximately six monthly packages per full year after warm-up.
- Both long-ratio and short-ratio packages are possible.
- Intramonth holding and cross-weekend exposure are expected.
- PnL is combined two-leg relative-value PnL, not per-leg alpha.
- No profitability or correlation level is presumed.

## Logging

Log broker month, endpoint keys/timestamps, twelve changes, group labels,
ordered wins, comparison count, observed displacement, assignment count, tail
count, direction, quotes/spreads, ATR/stops, volumes, notionals, magics,
order/repair results, and exit reason.

## Framework Alignment

| card rule | module |
|---|---|
| identity, host, fixed-risk/news/Friday contract, month attempt, history, ordered-score arithmetic, package state | `Strategy_NoTradeFilter` and bounded helpers |
| quotes, spreads, ATR, sizing, equal-notional reduction, atomic two-leg submission | `Strategy_EntrySignal` |
| malformed-package repair, next-month exit, forty-day exit | `Strategy_ManageOpenPosition` |
| broker/framework reason mapping | `Strategy_ExitSignal` and V5 close helper |

The no-trade hook must never close exposure. Basket repair and lifecycle belong
in management. The build must use `QM_MagicChecked` and `QM_BasketOrder`; no
manual magic arithmetic or raw ungoverned order path.

## Falsification And Requalification

Any change to symbols, period, endpoint count, group membership, tie rule,
comparison score, enumeration, tail cap, direction, risk, stops, spread
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
| v1 | 2026-09-02 | initial monthly Jonckheere-Terpstra XAU/XAG card | G0 | APPROVED; build pending |

## Pipeline History

| version | date | rebuild reason | Q-stage reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial build | Q01 | IN_PROGRESS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-02 | APPROVED_SOURCE | `decisions/2026-09-02_xauxag_monthly_jonckheere_terpstra_reversion_source_approval.md` |
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41285_xauxag_monthly_jonckheere_terpstra_reversion_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
