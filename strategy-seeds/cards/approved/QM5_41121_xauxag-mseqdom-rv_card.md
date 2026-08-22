---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026_S01
variant_id: SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026_S01
source_id: SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026
ea_id: QM5_41121
slug: xauxag-mseqdom-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41121_xauxag-mseqdom-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-23
created_by: Research+Development
last_updated: 2026-08-23
g0_status: APPROVED
g0_decision: decisions/2026-08-23_qm5_41121_xauxag_monthly_sequence_dominance_reversion_g0.md
source_approval: decisions/2026-08-23_xauxag_monthly_sequence_dominance_reversion_source_approval.md
source_author: "Karsten Schweikert; Alfred Cowles 3rd; Herbert E. Jones; CME Group"
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; Alfred Cowles 3rd; Herbert E. Jones; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Cowles and Jones (1937), Econometrica 5(3), 280-294, DOI 10.2307/1905515; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: academic_paper
    citation: "Schweikert, Karsten (2018), Are gold and silver cointegrated? New evidence from quantile cointegrating regressions, Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete-read packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_long_run_relation
  - type: academic_paper
    citation: "Yaya, OlaOluwa S.; Vo, Xuan Vinh; and Olayinka, Hammed A. (2021), Gold and silver prices, their stocks and market fear gauges: Testing fractional cointegration using a robust approach, Resources Policy 72, 102045."
    location: "DOI 10.1016/j.resourpol.2021.102045; governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: supporting_fractional_cointegration_lineage
  - type: academic_paper
    citation: "Cowles, Alfred 3rd and Jones, Herbert E. (1937), Some A Posteriori Probabilities in Stock Market Action, Econometrica 5(3), 280-294."
    location: "DOI 10.2307/1905515; complete Yale primary PDF and hash recorded in strategy-seeds/sources/SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026/source.md"
    quality_tier: A
    role: sequence_and_reversal_definition_only
  - type: exchange_research
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md; bounded extraction strategy-seeds/sources/SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026/source.md"
    quality_tier: A
    role: ratio_definition_and_intermarket_spread_carrier
strategy_mechanic: synchronized-immediately-completed-calendar-month-seventeen-to-twenty-three-chronological-gold-minus-silver-log-ratio-nonzero-adjacent-return-signs-exhaustive-sequence-reversal-inclusive-majority-net-displacement-contrarian-next-month-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-ratio-reversion]]"
  - "[[concepts/completed-month-sequence-dominance]]"
  - "[[concepts/market-neutral-commodity-basket]]"
indicators:
  - "[[indicators/completed-month-sequence-reversal-count]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver-ratio, relative-value-basket, completed-month-sequence-dominance, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41121_XAU_XAG_MSEQDOM_RV_D1
symbol: QM5_41121_XAU_XAG_MSEQDOM_RV_D1
host_symbol: XAUUSD.DWX
companion_symbols: [XAGUSD.DWX]
symbol_slot_map: {XAUUSD.DWX: 0, XAGUSD.DWX: 1}
magic_map: {XAUUSD.DWX: 411210000, XAGUSD.DWX: 411210001}
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 6-8 completed XAU/XAG basket packages per full post-warm-up year from the fixed inclusive sequence-majority state; Q02 must prove at least five in every full year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_ASSET_SEQUENCE_AND_DIRECTION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a completed-month gold/silver sequence-dominance fade outside the certified XAU/SP500/NDX/XNG book. Verify exact synchronized 17-23-session month membership, chronological nonzero ratio returns, exhaustive same-sign sequence versus opposite-sign reversal transitions, inclusive majority, net-month contrarian sides, durable monthly attempt, aggregate fixed risk, atomic basket repair, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, synchronized_first_tradable_month_bar, immediately_completed_calendar_month, bounded_month_session_count, chronological_ratio_close_order, nonzero_adjacent_relative_returns, exhaustive_sequence_reversal_accounting, inclusive_sequence_majority, net_month_contrarian_direction, persistent_month_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_month_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 Tier A peer-reviewed gold/silver and sequence-method DOI lineage plus official CME carrier with cross-asset and direction translation disclosed; R2 locks synchronized month history, nonzero return signs, exhaustive sequence/reversal arithmetic, inclusive majority, inverse net sides, attempt, aggregate risk, atomicity and lifecycle; R3 native XAU/XAG D1; R4 deterministic arithmetic with no banned signal; pre-allocation dedup CLEAN and post-allocation only self-hits."
---

# QM5_41121 XAU/XAG Completed-Month Sequence-Dominance Reversion

## Hypothesis

Gold and silver share a long-run precious-metals factor but have different
monetary, safe-haven, and industrial sensitivities. When the synchronized
gold/silver log-ratio path produces at least as many same-sign adjacent daily
sequences as opposite-sign reversals during a completed calendar month, that
chronological persistence may mark an extended relative move. Fading the
month's net ratio displacement for the next broker month may capture a
structural, low-frequency intermetal reversion effect.

This is one opposite-leg relative-value package rather than another outright
XAU, index, or XNG direction. Equal-notional construction is a target, not
proof of profitability, neutrality, or decorrelation. Q02 owns frequency and
baseline economics; Q09 alone may establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026/source.md`,
authorized before extraction by
`decisions/2026-08-23_xauxag_monthly_sequence_dominance_reversion_source_approval.md`
at commit `91e138677`. The bounded extraction was committed at `b7cd42641`.
The complete governed-record and primary-paper hashes are
`4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`,
`2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
and `4C7D4FCF2E5CB7C25BCB06B9B503E4D1560759197F5C29EA47B4AD23B9B2155C`.

Schweikert documents state-dependent gold/silver cointegration evidence, the
supporting paper documents fractional-cointegration lineage, CME defines the
gold/silver ratio and intermarket spread carrier, and Cowles-Jones define
same-sign sequences and opposite-sign reversals. They do not test an
XAU/XAG within-month sequence-majority exhaustion fade, continuous CFDs,
equal-notional fixed-dollar risk, or the QM book. Cowles-Jones study equities
and associate sequence excess with persistence, not contrarian action. All
month, count, direction, execution, and risk choices below are declared QM
interpretations.

No source return, probability, density, threshold, hedge ratio, profit factor,
drawdown, transaction cost, CFD equivalence, neutrality, or correlation
statistic is imported.

## Non-Duplicate Decision

The fail-closed pre-allocation checker scanned 4,620 registry identities,
1,289 repository cards, and 45 Strategy-Wiki nodes. It found no exact or fuzzy
candidate match and returned `CLEAN`. The post-allocation scan covered 4,621
registry identities and found only the expected reserved `QM5_41121` slug and
strategy-ID self-hits.

Manual semantic review fixes the load-bearing boundaries:

- `QM5_20275_gsr-runfade` requires a fresh terminal run of five consecutive
  same-sign D1 relative returns. This card counts every sign transition in one
  completed month and does not require a terminal run.
- `QM5_41078_xauxag-wstreak3-rv` uses three completed weekly ratio directions.
  This card uses the full daily transition path within one month and an
  inclusive sequence/reversal majority.
- `QM5_41112_xauxag-mdaybreadth-rv` counts return signs without chronology.
  This card is path-order dependent: permuting an identical sign multiset can
  change its sequence/reversal verdict.
- `QM5_41113_xauxag-mhalfagree-rv` and
  `QM5_41116_xauxag-mthirdvote-rv` use fixed block return sums. This card
  ignores magnitude after sign and uses no block aggregation.
- `QM5_41120_xauxag-mopen-residence-rv` counts close levels against one fixed
  first-close anchor. This card counts adjacent return-sign states.
- rolling ratio and residual systems estimate a center, regression, scale,
  score, or empirical tail. This card estimates none.
- `QM5_12533` supplies the validated logical-basket manifest/order recipe but
  trades an EURJPY/GBPJPY cointegration package.
- certified `QM5_12567_cum-rsi2-commodity` is a single-symbol, long-only,
  two-day XNG oscillator pullback.

The exact paired carrier, immediately completed calendar month,
17-to-23-session synchronization, chronological nonzero relative-return signs,
exhaustive sequence/reversal transitions, fixed inclusive sequence majority,
contrarian net-month package, consumed monthly attempt, equal-notional
aggregate-risk package, and next-month exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_SEQUENCE_DOMINANCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host: exact `XAUUSD.DWX`, D1, slot 0, planned magic `411210000`.
- Companion: exact `XAGUSD.DWX`, D1, slot 1, planned magic `411210001`.
- Logical tester symbol: `QM5_41121_XAU_XAG_MSEQDOM_RV_D1`.
- Decision clock: first synchronized tradable D1 bar of each new broker month,
  within 180 elapsed minutes of the raw host-bar open.
- Formation: immediately completed broker-calendar month only, with 17 through
  23 synchronized close pairs.
- Hold: until the first tick of a later broker month, with a forty-calendar-day
  stale repair.
- Expected cadence: approximately six to eight completed packages/year;
  retire below five in any full year.
- Q02 risk: aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

For chronological synchronized completed-month pairs `i=0..n-1`:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[j] = s[j] - s[j-1], j=1..n-1

all r[j] finite and nonzero, otherwise FLAT

sequences = count(sign(r[j]) == sign(r[j-1]), j=2..n-1)
reversals = count(sign(r[j]) != sign(r[j-1]), j=2..n-1)

sequences + reversals must equal n-2
sequences >= reversals must hold

net = s[n-1] - s[0]

net > 0 => SELL XAU / BUY XAG
net < 0 => BUY XAU / SELL XAG
net == 0 or nonqualifying => FLAT
```

For `n=17..23`, there are 16 through 22 returns and 15 through 21 sign
transitions. Equality qualifies only when the transition count is even.
Sequence surplus and net magnitude have no effect on risk or lifecycle.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Attach only to exact `XAUUSD.DWX`, D1, with `XAGUSD.DWX` selected and
   synchronized on the current raw D1 timestamp.
2. On a first-new-month bar, derive current and immediately completed
   `yyyymm` keys across year boundaries. Entry is eligible only within 180
   elapsed minutes of the host bar open.
3. Repair malformed, orphaned, duplicated, same-side, stopless,
   notional-invalid, later-month, or stale owned exposure before entry gates.
4. Persist the current decision month before history, signal, news, spread,
   quote, ATR, sizing, or order gates. Any later failure consumes the month.
5. Load a reverse-time 45-bar buffer for both legs. Require exact matching,
   unique, descending timestamps; positive finite closes; no current-month
   observation; 17 through 23 bars in the completed month; and one adjacent
   older pair proving the month was not truncated.
6. Reverse the ratios into chronological order, form all adjacent returns,
   reject an exact-zero/nonfinite return, and count each adjacent sign
   transition exactly once. Require `sequences+reversals=n-2` and
   `sequences>=reversals`.
7. Compute only the completed-month net ratio displacement. Upper net opens
   SELL XAU / BUY XAG; lower net opens BUY XAU / SELL XAG. Exact zero and
   every rejected state remain consumed flat.
8. Size both legs as one equal-absolute-notional package. Combined normalized
   frozen-stop risk must not exceed `RISK_FIXED=1000`; maximum notional
   mismatch is 20 percent.
9. Freeze a `3.5*ATR(20,D1)` stop on each leg. Submit no target. If either leg
   fails, immediately close any opened sibling; never retry that month.

## 5. Exit Rules

1. Close both legs at the first tick whose broker month is later than the
   package entry month.
2. Close both legs after forty calendar days as stale-state repair.
3. Close all owned legs immediately if the package is malformed, orphaned,
   duplicated, same-side, stopless, nonfinite, or outside the 20-percent
   notional-mismatch tolerance.
4. Broker hard stops remain active per leg. One stopped leg causes the next
   management pass to close the orphaned sibling.
5. No target, trailing stop, partial close, scale-in, reversal, or retry.

## 6. Filters (No-Trade Module)

- Framework kill switch and symbol guard always apply.
- Both news axes are deliberately OFF for the native completed-price baseline.
- Friday close is deliberately OFF because the approved lifecycle spans the
  full broker month.
- Reject late attachment, late first-month bars, asynchronous current bars,
  missing history, invalid labels, invalid prices, zero relative returns,
  non-exhaustive transition counts, spread-cap breaches, invalid ATR, invalid
  quotes, invalid volume, invalid stop distance, or notional mismatch.
- Never substitute a symbol, timeframe, month, threshold, or single-leg order.

## 7. Trade Management Rules

- Exactly zero or two owned positions are valid.
- Register and manage both governed magics as one logical package.
- Validate sides, stops, volumes, notionals, entry month, and stale age on
  every management pass.
- Atomic repair and lifecycle exits precede all entry filters.
- Persist one `yyyymm` attempt so restart or rejection cannot create an extra
  monthly option.
- No add, grid, martingale, pyramid, hedge overlay, or discretionary override.

## Parameters To Test

This baseline has no optimization surface; every value is locked to one set:

| Input | Value | Contract role |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_history_bars_d1` | 45 | bounded synchronized load |
| `strategy_min_month_sessions` | 17 | completed-month lower bound |
| `strategy_max_month_sessions` | 23 | completed-month upper bound |
| `strategy_entry_grace_minutes` | 180 | raw first-bar grace |
| `strategy_sequence_inclusive` | `true` | fixed `sequences>=reversals` rule |
| `strategy_atr_period_d1` | 20 | per-leg stop volatility |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal-notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | package rejection bound |
| `strategy_max_hold_days` | 40 | stale repair |
| `strategy_xau_max_spread_points` | 1500 | host spread ceiling |
| `strategy_xag_max_spread_points` | 500 | companion spread ceiling |
| `strategy_deviation_points` | 20 | bounded order deviation |
| `RISK_FIXED` | 1000 | aggregate backtest cash-risk budget |
| `RISK_PERCENT` | 0 | inactive backtest risk mode |
| `PORTFOLIO_WEIGHT` | 1 | canonical baseline weight |

## Source-Defined Rules

The reputable sources support a potentially state-dependent long-run
gold/silver relation, an intermarket ratio/spread carrier, and a named method
for separating same-sign sequences from opposite-sign reversals. They do not
define the within-month threshold, fade direction, or execution values.

## QM Interpretations

The calendar-month window, session-count bounds, nonzero-return requirement,
inclusive sequence majority, contrarian net direction, CFD mapping,
fixed-risk basket, ATR stops, spread caps, notional tolerance, attempt state,
and lifecycle are pre-result QM falsification choices.

## Framework Execution Overrides

- Friday close: disabled for the approved monthly hold.
- News temporal mode: OFF.
- News compliance profile: NONE.
- Logical basket: two opposite legs under one aggregate risk budget.

## Exit Precedence

1. Framework kill switch and broker hard stops.
2. Broken-package atomic repair.
3. First-later-month lifecycle exit.
4. Forty-day stale repair.
5. No signal exit.

## Runtime Data Dependencies

- Native `XAUUSD.DWX` and `XAGUSD.DWX` D1 rates.
- Native symbol metadata, ticks, ATR, positions, deals, broker time, and
  terminal global variables.
- No external price, futures, inventory, calendar, or model feed.

## Risk

Backtests must use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg receives a frozen ATR stop, while package sizing
caps the sum of normalized stop risks at the single fixed-cash budget and
targets equal absolute USD notionals. This controls intended initial stop risk;
it does not guarantee fills, gap loss, neutrality, or final loss.

No live preset is authorized. No position add, partial close, target, trailing
stop, grid, martingale, or pyramid is permitted.

## Reputable-Source Gate Findings

- R1: `PASS_WITH_CROSS_ASSET_SEQUENCE_AND_DIRECTION_TRANSLATION_RISK`.
- R2: `PASS` for exact synchronized history, sign/transition arithmetic,
  inclusive majority, net sides, attempt, aggregate risk, and lifecycle.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`.
- R4: `PASS` for deterministic native arithmetic and prohibited-mechanic ban.

## Falsification And Requalification

Q02 retires at zero completed packages, below five packages in any full
post-warm-up year, nonpositive governed economics, or any synchronization,
month, ordering, zero-return, sign, transition-count, majority, net-direction,
attempt, risk, atomicity, lifecycle, or determinism defect.

Changing the inclusive majority, assigning zero returns a sign, reversing
sides, changing the month bounds or hold, or adding a fitted center, scale,
magnitude, volatility, volume, event, calendar, external, or prior-result state
creates a new strategy identity and requires new approval.

## Framework Alignment

| Card rule | V5 module |
|---|---|
| exact symbols, period, news/Friday contract, kill switch | No-Trade / initialization |
| month clock, synchronized history, sequence state, pair sizing/open | Trade Entry |
| atomic repair, notional validation, next-month and stale exit | Trade Management |
| broker hard stop; no independent signal exit | Trade Close |

## Validation Plan

1. Card schema and G0 lints.
2. Post-allocation exact self-hit review and registry/magic validation.
3. Deterministic reference tests for every `n=17..23`, all-positive,
   all-negative, alternating, inclusive-tie, reversal-dominant, net-zero,
   exact-zero-return, malformed history, month/year boundaries, attempt
   persistence, and aggregate sizing states.
4. SPEC validation, build guardrails, basket symbol-scope validation, and
   strict governed compile/Q01.
5. Exactly one logical-basket `RISK_FIXED` Q02 enqueue when fresh capacity is
   below the hard ceiling. No manual tester run.

## Pipeline History

- 2026-08-23: reputable source approval committed at `91e138677`.
- 2026-08-23: bounded source extraction committed at `b7cd42641`.
- 2026-08-23: canonical pre-allocation dedup `CLEAN`.
- 2026-08-23: deterministic registry reserved `QM5_41121` at `9b19a5024`.

## Pipeline Phase Status

- Q00/G0: `APPROVED`.
- Q01: `PENDING_BUILD`.
- Q02: `NOT_QUEUED`.
- Q03+: not authorized by this card decision.

## Safety Boundary

This card authorizes one branch-only V5 build, governed magic allocation,
strict Q01, one fixed-risk logical-basket setfile, and one paced Q02 enqueue.
It does not authorize a manual backtest, demo/shadow/live/stress/optimization
preset, AutoTrading, `T_Live`, deploy or T_Live manifest mutation, portfolio-
gate mutation, portfolio admission, correlation waiver, decorrelation claim,
or live use.
