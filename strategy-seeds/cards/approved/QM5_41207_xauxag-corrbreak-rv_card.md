---
card_schema_version: 2
type: strategy
strategy_id: KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026_S01
variant_id: KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026_S01
source_id: KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026
ea_id: QM5_41207
slug: xauxag-corrbreak-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41207_xauxag-corrbreak-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-30
created_by: Research+Development
last_updated: 2026-08-30
g0_status: APPROVED
g0_decision: decisions/2026-08-30_qm5_41207_xauxag_correlation_break_reversion_g0.md
source_approval: decisions/2026-08-30_xauxag_correlation_break_reversion_source_approval.md
source_author: "Monika Krawiec; Anna Gorska; Karsten Schweikert; CME Group"
source_authors: "Monika Krawiec; Anna Gorska; Karsten Schweikert; CME Group"
source_citation: "Krawiec and Gorska (2015), Granger Causality Tests for Precious Metals Returns, Quantitative Methods in Economics 16(2), 13-22; Schweikert (2018), Are gold and silver cointegrated?, Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; CME Group governed Gold-Silver Ratio Spread research."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Krawiec, M. and Gorska, A. (2015). Granger Causality Tests for Precious Metals Returns. Quantitative Methods in Economics 16(2), 13-22."
    location: "Complete-read evidence strategy-seeds/sources/KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026/source.md"
    quality_tier: A
    role: daily_gold_silver_positive_return_dependence_and_gold_to_silver_ordering
  - type: peer_reviewed_trading_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete-read evidence strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relation_and_adverse_constant_spread_evidence
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread and governed precious-metals spread research."
    location: "strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: B
    role: tradable_intermarket_carrier_and_distinct_monetary_industrial_drivers
  - type: governed_composite_source
    citation: "QuantMechanica bounded XAU/XAG disjoint-correlation-break relative-value extraction."
    location: "strategy-seeds/sources/KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026/source.md"
    quality_tier: internal_governed
    role: exact_history_blocks_statistics_thresholds_execution_risk_and_lifecycle
strategy_mechanic: weekly-synchronized-xau-xag-eighty-d1-return-disjoint-sixty-baseline-twenty-recent-pearson-fisher-correlation-break-five-session-standardized-relative-displacement-fade-atomic-equal-notional-halfway-retracement-basket
sources:
  - "[[sources/KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026]]"
concepts:
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/state-dependent-dependence]]"
  - "[[concepts/correlation-break]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/pearson-correlation]]"
  - "[[indicators/fisher-transform]]"
  - "[[indicators/completed-log-return]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, structural-relative-value, correlation-break, mean-reversion, market-neutral-style, weekly-decision, atr-hard-stop, signal-exit, time-stop, low-frequency]
markets: [commodities, precious_metals, gold_silver_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41207_XAU_XAG_CORRBREAK_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412070000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 5-15 completed XAU/XAG packages per full post-warm-up year; a non-break, sub-threshold displacement, invalid synchronized history, or degenerate variance consumes the broker week flat."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_STATE_TRANSLATION_AND_CFD_RISK
r1_reasoning: "Complete peer-reviewed evidence supports daily gold/silver dependence and a state-dependent relationship; governed CME material supports the intermarket carrier. The exact correlation-break fade, thresholds, and CFD execution are untested QM hypotheses, and adverse evidence is binding."
r2_mechanical: PASS
r2_reasoning: "Weekly clock, exact synchronized history, disjoint 60/20 blocks, Pearson and Fisher arithmetic, four break boundaries, baseline relative scale, five-session score, sides, attempt/target state, nonnegative modeled-spread handling, shared risk, atomicity, stops, halfway exit, and time exits are deterministic and locked."
r3_data_available: PASS
r3_qualification: SYNCHRONIZATION_CONTINUOUS_CFD_AND_LEGGING_RISK
r3_reasoning: "Registered XAUUSD.DWX and XAGUSD.DWX D1 histories and native MT5 state supply every runtime input; label alignment, rolls, financing, spreads, fills, legging, and futures/CFD basis remain explicit Q02 risks."
r4_ml_forbidden: PASS
r4_reasoning: "Only dates, completed prices, logarithms, ordinary sums/products, square roots, Fisher transforms, comparisons, ATR risk controls, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 81 synchronized completed D1 closes; 60 oldest and 20 newest disjoint returns; baseline rho floor 0.50; recent rho ceiling 0.35; raw drop floor 0.25; Fisher z-drop floor 1.645; newest five-return standardized relative-displacement threshold 1.25; exact halfway retracement; ATR(20)*3.5 stops; 15 completed D1 bars/24 calendar days maximum; XAU/XAG spread ceilings 1500/3000 points with zero modeled .DWX spread permitted and crossed quotes rejected; equal USD notionals within 20%; one shared RISK_FIXED budget."
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
review_focus: "Falsify a weekly XAU/XAG correlation-break relative-value sleeve outside the directional XAU/SP500/NDX/XNG book. Verify synchronized completed endpoints, exact disjoint return blocks, Pearson/Fisher arithmetic, four break gates, standardized five-session displacement, contrarian sides, persisted week/target, aggregate fixed risk, atomic equal-notional opposite legs, stops, halfway exit, and stale repair. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_broker_week_bar, synchronized_completed_d1_closes, no_current_bar_price, exact_eighty_returns, disjoint_sixty_twenty_blocks, pearson_sample_arithmetic, fisher_transform_clamp_only, four_correlation_break_gates, baseline_relative_sample_scale, exact_newest_five_displacement, contrarian_package_side, weekly_attempt_state, frozen_halfway_target_state, nonnegative_modeled_spread_and_crossed_quote_rejection, equal_notional_basket, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, retracement_exit, fifteen_bar_exit, twenty_four_day_repair, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-30 and decisions/2026-08-30_qm5_41207_xauxag_correlation_break_reversion_g0.md, including the pre-Q02 Q01 execution-contract amendment: R1 passes with complete peer-reviewed dependence/state lineages and governed exchange carrier while retaining adverse evidence; R2 locks exact history, blocks, statistics, boundaries, displacement, sides, persistence, nonnegative modeled-spread handling, risk, atomicity, stops, and lifecycle; R3 uses registered native XAU/XAG D1 with synchronization/CFD risk; R4 is deterministic native arithmetic only. Canonical dedup found only the expected shared-author gold-lead neighbor; manual mechanic review resolves it and the ratio/residual/return-spread/memory families."
---

# QM5_41207 XAU/XAG Weekly Correlation-Break Relative-Value Fade

## Hypothesis

Gold and silver share USD and precious-metal drivers, but gold carries more
monetary/safe-haven exposure while silver carries more industrial-cycle
exposure. The sources show positive daily dependence and a state-dependent
relationship rather than one stable equilibrium. This card tests whether a
large five-session relative move that occurs while recent return correlation
breaks sharply below a previously strong, disjoint baseline partially
retraces.

The strategy fades only that joint state with opposite equal-notional metal
legs. It does not assume a permanent price ratio, fit a hedge coefficient, or
trade either metal outright. Opposite legs do not prove dollar, beta,
volatility, factor, or portfolio neutrality. Q02 owns activity and economics;
unchanged Q09 alone owns realized book overlap.

## Source Traceability And Claim Boundary

The approved packet is
`strategy-seeds/sources/KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026/source.md`,
SHA-256
`7AF659643DF0CCD6AF645815882545F7336CA96705DC678A76880A91613416D3`,
authorized by
`decisions/2026-08-30_xauxag_correlation_break_reversion_source_approval.md`
at commit `e75f465f1` before card extraction.

Krawiec and Gorska supply daily positive correlation and gold-to-silver
ordering in their historical sample. Schweikert supplies state-dependent
gold/silver relation evidence and adverse findings against a simple stable
spread. CME supplies the governed intermarket carrier. No source tests the
exact disjoint-window break, score, side, hold, CFD pair, or current book.

No source return, coefficient sign for this rule, probability, significance
beyond its reported sample, trade count, profit factor, drawdown, cost, hedge,
CFD equivalence, decorrelation, or portfolio statistic transfers.

## Formula

Load exactly 81 synchronized positive completed D1 close pairs and form 80
adjacent log returns oldest to newest:

```text
gx[i] = ln(xau_close[i+1] / xau_close[i])
sx[i] = ln(xag_close[i+1] / xag_close[i])

rho_old = corr(gx[0..59],  sx[0..59])
rho_new = corr(gx[60..79], sx[60..79])

clamp_for_transform(rho) = min(+0.999999999, max(-0.999999999, rho))
atanh(rho)                = 0.5*ln((1+rho)/(1-rho))
z_drop = (atanh(rho_old)-atanh(rho_new)) / sqrt(1/57+1/17)

break = rho_old >= 0.50
        and rho_new <= 0.35
        and rho_old-rho_new >= 0.25
        and z_drop >= 1.645

d[i]   = gx[i]-sx[i]
mu_d   = mean(d[0..59])
sd_d   = sample_sd(d[0..59])
disp5  = sum(d[75..79])-5*mu_d
score5 = disp5/(sd_d*sqrt(5))

break and score5 >= +1.25 => SELL XAU / BUY XAG
break and score5 <= -1.25 => BUY XAU / SELL XAG
otherwise                 => FLAT
```

Pearson uses ordinary centered products and sample variances. Zero variance,
nonpositive relative scale, non-finite arithmetic, a missing pair, or a time
mismatch is invalid. Correlation clamping is permitted only inside the Fisher
transform; all raw break comparisons use the unclamped correlations.

For a valid signal, freeze:

```text
anchor_ratio = ln(xau_close_5_sessions_before / xag_close_5_sessions_before)
signal_ratio = ln(xau_newest_completed / xag_newest_completed)
target_ratio = anchor_ratio + 0.5*(signal_ratio-anchor_ratio)
```

The target never slides or recomputes after entry.

## Non-Duplicate Decision

The checker examined 4,706 registry identities and 1,352 cards, found no exact
identity, and returned only the expected shared-source-author fuzzy match to
`QM5_41031_xauxag-goldlead`. Its configured Strategy Wiki root was absent;
that coverage is not claimed. Receipt:
`artifacts/qm5_xauxag_corrbreak_rv_preallocation_dedup_20260830.json`, SHA-256
`970112BA5AF89F0645D21AED1F28BACB50746D9C180FB4C802F0C8BD9295B1BF`.

- `QM5_41031` uses one gold shock plus bounded silver under-response and exits
  next day; it has no disjoint correlation state or five-day standardized
  relative displacement.
- Raw-ratio, OLS/CADF, MAD, tail, and conditional-quantile baskets estimate an
  equilibrium center or hedge state; this card estimates none.
- `QM5_12862` fades a rolling return-spread z-score without a high-to-low
  Pearson/Fisher state break.
- Variance-ratio cards estimate memory; weekly flow/path/common-shock and
  same-calendar cards use different information objects and clocks.

Verdict:
`FUZZY_GOLDLEAD_RESOLVED_DISTINCT_DISJOINT_CORRELATION_BREAK_PLUS_FIVE_SESSION_RELATIVE_DISPLACEMENT_FADE`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_41207_XAU_XAG_CORRBREAK_RV_D1`.
- Host/slot 0: exact `XAUUSD.DWX`, D1, intended magic `412070000`.
- Companion/slot 1: exact `XAGUSD.DWX`, D1, intended magic `412070001`.
- Decision: first executable tick of the first host D1 bar in each broker week,
  no later than 180 minutes after that bar opens.
- Formation: exactly 81 synchronized completed close pairs, yielding 80
  completed adjacent returns in fixed 60/20 blocks.
- Hold: halfway retracement, 15 completed host D1 bars, or 24 calendar days.
- Expected cadence: five to fifteen packages/year after warm-up; Q02 retires
  below five in any full post-warm-up year.

## Rules

The following entry, exit, filters, management, and risk rules are the complete
execution contract. There is no result-dependent rescue or implicit fallback.

## 4. Entry Rules

1. Reconcile owned slot-0 and slot-1 positions on every tick before any entry
   gate. An orphan, duplicate, same-side pair, wrong symbol/magic, missing hard
   stop, or missing persisted target is malformed and must be flattened.
2. Evaluate a new signal only on a genuine first host D1 bar of the broker
   week and within 180 minutes of its open. Exact host, D1, slot 0, companion,
   EA ID, and all locked inputs are mandatory.
3. Persist the broker ISO week key before history, signal, news, spread, quote,
   ATR, lot, or order checks. A flat, blocked, rejected, or stopped week never
   retries or backfills.
4. Load exactly 81 synchronized completed D1 closes for both symbols. Require
   positive prices, strictly increasing times, identical cross-leg timestamps,
   and no current forming-bar input.
5. Compute the exact Formula contract. A failed break, invalid state, or
   `abs(score5)<1.25` consumes the week flat.
6. Require positive finite Bid/Ask, reject crossed quotes (`Ask<Bid`), and
   require nonnegative modeled spreads no greater than 1,500 XAU points and
   3,000 XAG points. Exact zero spread is permitted because `.DWX` tester
   history can legitimately model `Ask==Bid`; no live setfile is authorized.
7. Compute frozen completed-D1 ATR(20) stops per leg. Split the aggregate
   `RISK_FIXED` budget into equal stop-risk halves and size each leg through
   framework risk plumbing. Signal magnitude never changes risk.
8. Target equal USD notionals after lot-step rounding; reject mismatch above
   20%. Positive score opens SELL XAU then BUY XAG. Negative score opens BUY
   XAU then SELL XAG. Neither leg has a take-profit.
9. Persist the frozen target ratio, expected pair side, and entry decision time
   before order submission. If leg 2 fails or final composition is not exactly
   one opposite-direction leg per registered magic, flatten all owned legs and
   clear package state. The week remains consumed.

## 5. Exit Rules

1. For SELL-XAU/BUY-XAG, close both legs when the newest synchronized completed
   log ratio is at or below the frozen target. For BUY-XAU/SELL-XAG, close when
   it is at or above the target.
2. Close both legs after 15 completed host D1 bars from entry even if no
   retracement occurs.
3. Close all survivors after 24 elapsed calendar days; this is repair only.
4. If a hard stop removes one leg, flatten the surviving orphan immediately.
5. Framework kill switch or close-only state outranks strategy entry and uses
   framework close services.
6. No broker target, trailing stop, break-even, partial close, Friday close,
   reversal-in-place, or same-week re-entry is authorized.

## 6. Filters (No-Trade Module)

- Framework kill-switch and operational guards remain active.
- Both news axes and legacy news mode are OFF; no external event data is read.
- Framework Friday close is OFF for the multiday relative-value hold.
- Reject wrong host/period/slot/companion, late attachment, unavailable
  symbols, incomplete or unsynchronized history, current-bar leakage,
  non-finite or degenerate statistics, a missed break boundary, invalid
  quotes/spreads/stops/lots/notionals, malformed owned state, missing package
  persistence, or an already-consumed week.
- No raw-ratio threshold, OLS/CADF/quantile hedge, oscillator, trend,
  same-calendar, event, inventory, curve, volume, or discretionary filter is
  authorized.

## 7. Trade Management Rules

- Every tick begins with framework MAE tracking before any guard can return.
- The 81-pair history and statistics run only on the consumed weekly decision
  path. Ordinary per-tick management uses cached/persisted target and native
  positions; completed-ratio exits update once per new host D1 bar.
- Own positions solely by exact EA ID, magic, and symbol. Never manage another
  EA's or manual trade.
- One XAU slot-0 and one XAG slot-1 position in the expected opposite
  directions, each with a positive hard stop, is the only valid open state.
- Any orphan, duplicate, wrong-direction, wrong-symbol, stopless, or
  missing-state package is flattened immediately. Never add, pyramid, grid,
  average, recreate, or reverse a leg.
- Terminal-global state persists the consumed week, target ratio, expected
  side, and package entry time. A restart may manage a valid persisted package
  but may not generate a second weekly attempt.

## Parameters To Test

Only the locked Q02 baseline exists:

| Parameter | Locked value |
|---|---:|
| companion | `XAGUSD.DWX` |
| synchronized completed closes | 81 |
| total returns | 80 |
| baseline / recent returns | 60 / 20, disjoint |
| baseline correlation floor | `0.50` inclusive |
| recent correlation ceiling | `0.35` inclusive |
| raw correlation-drop floor | `0.25` inclusive |
| Fisher z-drop floor | `1.645` inclusive |
| displacement horizon | newest 5 returns |
| absolute standardized score floor | `1.25` inclusive |
| retracement fraction | `0.50` |
| Pearson variance epsilon | `1e-12` |
| hard stop | `3.5 * ATR(20,D1)` per leg |
| maximum hold | 15 completed D1 bars |
| stale survivor repair | 24 elapsed days |
| entry grace | 180 minutes from weekly host D1 open |
| XAU/XAG spread ceilings | 1500 / 3000 points; zero modeled spread allowed, crossed quote rejected |
| maximum notional mismatch | 20% |
| aggregate fixed risk | 1000, split 50/50 by stop risk |

No sweep, alternate window, overlapping sample, fallback statistic, fitted
hedge, threshold rescue, side flip, optimization, or current-bar path is
authorized.

## Risk

- Backtest mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Split the aggregate budget into two `RISK_FIXED=500` stop-risk budgets. This
  is one 1000 package, not 1000 per leg.
- Each leg receives a frozen `3.5*ATR(20,D1)` hard stop and no target.
- Target equal USD notionals, round down, and reject more than 20% mismatch.
- If either lot or stop is invalid, stand down before leg 1. If leg 2 fails,
  flatten leg 1 immediately.
- Gaps, legging, slippage, financing, and unequal contract granularity can
  exceed nominal risk and leave factor exposure; Q02 owns realized economics.
- No live risk mode, live setfile, or live artifact is authorized.

## Data Requirements

- Registered `XAUUSD.DWX` and `XAGUSD.DWX` D1 OHLC/timestamps with at least 82
  synchronized completed bars available at a weekly decision.
- Native broker time, quotes, points, tick values/sizes, volume constraints,
  positions, deals, terminal global variables, and framework services.
- No external file, API, event, curve, inventory, weather, COT, volume, open
  interest, futures chain, trained output, or optimizer artifact.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- Framework kill switch, sizing, magic resolution, order services, MAE
  tracking, and owned-position isolation remain mandatory.

## Exit Precedence

1. Framework kill switch / close-only instruction.
2. Malformed, stopless, orphaned, duplicate, wrong-side, or missing-state
   package repair.
3. Broker hard stop followed by immediate surviving-leg cleanup.
4. Frozen halfway-ratio retracement.
5. Fifteen-completed-D1-bar exit.
6. Twenty-four-day stale survivor repair.
7. New entry only when flat and the broker week is unconsumed.

## Reputable-Source Gate Findings

- R1: `PASS_WITH_COMPOSITE_STATE_TRANSLATION_AND_CFD_RISK`.
- R2: `PASS` for the exact locked mechanical contract.
- R3: `PASS_WITH_SYNCHRONIZATION_CONTINUOUS_CFD_AND_LEGGING_RISK`.
- R4: `PASS`; structural native arithmetic only and no prohibited trained
  signal or external runtime feed.

## Framework Alignment

- No-Trade: exact host/slot/input, weekly clock, synchronized history,
  statistics, break, score, quote, spread, stop, lot, notional, package, and
  consumed-week guards.
- Trade Entry: contrarian score side, opposite equal-notional legs, shared
  fixed risk, frozen stops, and frozen halfway target.
- Trade Management: target crossing, bar/time limits, orphan, direction,
  magic, duplicate, stop, and persisted-state repair before entry gates.
- Trade Close: framework pair close, per-leg broker stops, and kill switch.

## Kill Criteria

Retire or fail the unchanged candidate on any of:

- zero Q02 packages or fewer than five completed packages in any full
  post-warm-up year;
- nonpositive governed Q02 economics;
- wrong weekly clock, endpoint, synchronization, return order, block
  membership, Pearson/Fisher arithmetic, scale, displacement, score, side,
  target, or attempt behavior;
- orphaned, duplicated, same-direction, stopless, wrong-magic, missing-state,
  or cross-EA position handling;
- aggregate fixed-risk, notional, stop, lifecycle, or determinism defect; or
- downstream portfolio-correlation rejection.

No result-dependent window, threshold, score, side, target, risk, stop, hold,
spread, or gate change may rescue this identity.

## Validation Plan

1. Reference-test exact synchronization, 81-close/80-return counts, oldest-to-
   newest ordering, disjoint blocks, and no-current-bar behavior.
2. Reference-test Pearson, transform-only clamp, Fisher statistic, four break
   boundaries, relative mean/sample scale, five-return score, equality cases,
   and invalid variance.
3. Static-test weekly attempt and target persistence, opposite sides,
   half-risk sizing, equal notionals, atomicity, stop presence, target/bar/time
   exits, and restart/orphan repair.
4. Lint card, G0 decision, execution contract, spec, symbol scope, magics,
   resolver, setfile, array bounds, performance, and MAE hook.
5. Compile through the governed compile path and require zero compiler
   errors/warnings plus strict build PASS.
6. If CPU is below the explicit ceiling, record the successful build to create
   exactly one logical-basket Q02 item. Do not enqueue component legs or start
   a tester manually.

## Version History

| Version | Date | Change | Authority |
|---|---|---|---|
| v1 | 2026-08-30 | Initial XAU/XAG disjoint-correlation-break relative-value card | OWNER commodity/energy portfolio mission |
| v2 | 2026-08-30 | Pre-Q02 Q01 advisory amendment: allow zero modeled .DWX spread, retain caps, reject crossed quotes | Same OWNER mission; G0 decision amendment |

## Pipeline Phase Status

- Q00 source: APPROVED and committed before extraction.
- G0 card: APPROVED for branch-only build/Q01/Q02 scope.
- Q01: NOT BUILT at card approval.
- Q02: NOT ENQUEUED pending source-fresh governed compile and capacity check.
- Q03+: deterministic pipeline only after Q02 evidence.

## Safety Boundary

Authorized: deterministic magic allocation, one branch-only V5 source build,
one exact D1 `RISK_FIXED` logical-basket setfile/manifest, strict Q01
validation, governed compile, and one paced Q02 enqueue below the CPU ceiling.

Forbidden: manual tester runs; component-leg Q02 rows; live/demo/shadow/
stress/optimization setfiles; terminal control; AutoTrading; `T_Live`; deploy
or live manifests; portfolio-gate changes; portfolio admission; correlation
waivers; or certification claims.
