---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XTIXNG-WRELVOTE-FLIP-CONT-20260906_S01
variant_id: AI-CODEX-XTIXNG-WRELVOTE-FLIP-CONT-20260906_S01
source_id: AI-CODEX-XTIXNG-WRELVOTE-FLIP-CONT-20260906
ea_id: QM5_41372
slug: xtixng-wrelvote-flip-cont
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41372_xtixng-wrelvote-flip-cont_card.md
execution_contract_status: APPROVED
created: 2026-09-06
created_by: Research+Development
last_updated: 2026-09-06
g0_status: APPROVED
g0_decision: decisions/2026-09-06_qm5_41372_xtixng_weekly_relative_vote_flip_continuation_g0.md
source_approval: decisions/2026-09-06_xtixng_weekly_relative_vote_flip_continuation_source_approval.md
source_author: "Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis; Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_authors: "Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis; Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_citation: "Fuertes, Miffre, and Rallis (2010), Journal of Banking & Finance 34(10), DOI 10.1016/j.jbankfin.2010.04.009; Villar and Joutz (2006), U.S. EIA; Ramberg and Parsons (2012), The Energy Journal 33(2), DOI 10.5547/01956574.33.2.2."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Fuertes, A.-M., Miffre, J., and Rallis, G. (2010). Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals. Journal of Banking & Finance 34(10), 2530-2548."
    location: "DOI 10.1016/j.jbankfin.2010.04.009; complete-read governed packet strategy-seeds/sources/FMR-MOMTS-2010/source.md"
    quality_tier: A
    role: commodity_relative_return_continuation_lineage
  - type: government_research
    citation: "Villar, J. A. and Joutz, F. L. (2006). The Relationship Between Crude Oil and Natural Gas Prices. U.S. Energy Information Administration."
    location: "Complete-read governed packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: oil_gas_physical_economic_link_and_instability
  - type: peer_reviewed_paper
    citation: "Ramberg, D. J. and Parsons, J. E. (2012). The Weak Tie Between Natural Gas and Oil Prices. The Energy Journal 33(2), 13-35."
    location: "DOI 10.5547/01956574.33.2.2; complete-read governed packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: weak_time_varying_oil_gas_relationship_and_adverse_evidence
strategy_mechanic: normalized-week-boundary-xti-xng-five-synchronized-completed-week-endpoints-four-adjacent-relative-log-returns-overlapping-older-and-newer-three-week-strict-sign-majorities-strict-majority-flip-newest-majority-winner-continuation-equal-notional-one-week-hold
sources:
  - "[[sources/AI-CODEX-XTIXNG-WRELVOTE-FLIP-CONT-20260906]]"
concepts: ["[[concepts/oil-gas-relative-value]]", "[[concepts/overlapping-relative-vote-transition]]", "[[concepts/market-neutral-basket]]"]
indicators: ["[[indicators/completed-week-relative-log-return]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, oil-gas-relative-value, market-neutral-basket, overlapping-three-week-vote, fresh-majority-flip, relative-winner-continuation, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41372_XTI_XNG_WRELVOTE_FLIP_CONT_D1
symbol: QM5_41372_XTI_XNG_WRELVOTE_FLIP_CONT_D1
host_symbol: XTIUSD.DWX
companion_symbol: XNGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [413720000, 413720001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eight to sixteen completed paired packages per full post-warm-up year after the strict overlapping-majority flip, synchronization, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_RELATIVE_VOTE_FLIP_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
review_focus: "Falsify a fresh XTI/XNG overlapping three-week relative-majority flip continuation outside the certified XAU/SP500/NDX/XNG book. Verify five consecutive synchronized endpoints, four strict relative-return signs, exact vote overlap, strict majority reversal, new-winner continuation, durable attempt, aggregate fixed risk, atomic repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xti_xng_carrier, immediately_preceding_five_monday_anchors, synchronized_completed_d1_closes, three_to_five_week_sessions, four_adjacent_relative_returns, strict_nonzero_return_differences, exact_overlapping_three_week_votes, strict_vote_flip, newest_majority_continuation, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 preserves complete reputable commodity-momentum and oil/gas relationship evidence plus adverse instability while disclosing the untested weekly vote-flip translation; R2 locks endpoints, votes, direction, lifecycle, and risk; R3 uses registered native XTI/XNG D1 data; R4 uses deterministic non-trained arithmetic. No exact duplicate exists; one-/two-week fuzzy siblings do not own the overlapping three-week majority-flip state."
---

# QM5_41372 XTI/XNG Weekly Relative-Vote Flip Continuation

## Hypothesis

A fresh reversal in the overlapping three-week majority of XTI-minus-XNG
weekly relative returns may identify a new short-lived energy leader. The EA
follows that new relative majority for one week with opposed XTI/XNG legs. The
carrier is market-neutral by construction intent only; Q09 alone may establish
realized correlation and the sources do not establish this exact edge.

## Source-defined rules

Fuertes, Miffre, and Rallis support commodity-relative momentum as a research
lineage, but do not define this weekly XTI/XNG rule. Villar and Joutz establish
an economic oil/gas relationship; Ramberg and Parsons document that the link is
weak and time varying. No cited source transfers a result, endpoint rule, vote,
threshold, holding period, risk rule, or CFD implementation to this card.

## QM interpretations

The synchronized five-week reconstruction, four relative-return signs,
overlapping three-week majority flip, continuation direction, one-week hold,
and equal-notional CFD basket are explicit QM translations. Their only
authorization is the approved G0 decision; Q02 must falsify the translation
without parameter rescue.

## Rules

### Market, clock, and data

- Host exact `XTIUSD.DWX` D1; companion exact `XNGUSD.DWX` D1; slots 0/1.
- On the first tradable bar of a new Monday-anchored broker week, consume one
  durable attempt before all fallible gates.
- Reconstruct the final synchronized closes of exactly the five immediately
  preceding consecutive weeks; each must contain three to five sessions.
- Missing, asynchronous, duplicate, current-week, nonpositive, nonfinite, or
  nonconsecutive data consumes the week flat.

### Entry

Order endpoints oldest to newest and calculate four adjacent relative log
returns `d[i] = log(XTI[i+1]/XTI[i]) - log(XNG[i+1]/XNG[i])`. Require every
`abs(d[i]) > 1e-10`. Define `old_vote` from `d0,d1,d2` and `new_vote` from
`d1,d2,d3`, adding `+1` for positive and `-1` for negative.

- `old_vote < 0` and `new_vote > 0`: buy XTI and sell XNG.
- `old_vote > 0` and `new_vote < 0`: sell XTI and buy XNG.
- Otherwise consume the week flat.

Open an equal-absolute-notional package with aggregate `RISK_FIXED=1000`,
independent frozen `3.5*ATR(20,D1)` hard stops, XTI/XNG spread ceilings of
1500/3000 points, and no target. Return magnitude never sizes or filters risk.

### Exit and management

- Close both legs at the first tick of the next broker week or after ten
  calendar days as a stale repair.
- Repair any orphan, malformed direction, missing stop, or excessive notional
  mismatch by flattening all owned exposure.
- No signal exit, retry, target, trail, break-even, partial, scale-in, grid,
  martingale, or pyramid.

## Framework execution overrides

There is no Parameters to Test list or sweep. Q02 uses only the locked defaults;
no optimization or rescue range is authorized: `history_bars_d1=50`, weekly
sessions `3..5`, epsilon `1e-10`, entry grace 180 minutes, ATR `20` at `3.5x`,
equal-notional target `1.0`, maximum notional mismatch `20%`, stale hold 10
days, spread caps 1500/3000, and order deviation 20 points. Framework inputs
use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`; news and Friday
close remain disabled and are not configuration-pinned.

## Exit precedence

The framework kill switch is absolute. Next, any orphan, malformed direction,
missing stop, or excessive notional mismatch closes the full package. The
ten-day stale repair precedes the ordinary first-tick-of-next-week exit. No
signal exit, target, trailing rule, Friday override, or discretionary close is
part of the strategy contract.

## Runtime data dependencies

Runtime requires native DarwinexZero `XTIUSD.DWX` and `XNGUSD.DWX` D1 bars,
positive synchronized completed-week closes, valid quotes and symbol metadata,
and enough XTI ATR history for both hard-stop distances. Missing, nonfinite,
asynchronous, duplicate, or nonconsecutive data consumes the weekly attempt
flat. No external calendar, model, alternative dataset, or future data is used.

## Reputable-source criteria

- R1: PASS with disclosed vote-flip translation risk and no transferred result.
- R2: PASS; all data, state, entry, direction, risk, and lifecycle rules fixed.
- R3: PASS with synchronization and continuous-CFD basis risk.
- R4: PASS; deterministic native arithmetic only and no trained component.

## Non-duplicate boundary

`QM5_41367` uses one completed common-shock week. `QM5_41368`–`41371` use
two common-sign weeks and classify relative-leader switch/persistence. This EA
does not require common outright direction and instead owns five endpoints,
four relative-return signs, and a reversal between overlapping three-week
majorities. Outright trend, robust-statistic, calendar, event, ratio, OLS, and
RSI families do not implement this state transition.

## Falsification and requalification

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Retire on zero packages, fewer than five completed
packages in any full post-warm-up year, or nonpositive economics. Do not alter
carrier, endpoints, overlap, vote, direction, risk, stop, or lifecycle to
rescue a failed result. Equal notional is not proof of factor neutrality. Any
future source, parameter, carrier, timeframe, lifecycle, or risk change needs a
new variant, renewed deterministic deduplication, OWNER G0 approval, rebuild,
and full requalification from Q01.

## Framework alignment

- no_trade: exact identity, host/timeframe, locked strategy inputs, fixed-risk
  mode, finite bounded stress input, history, synchronization, position, quote,
  spread, and durable-attempt guards.
- trade_entry: cached vote-flip direction and atomic opposed-leg package under
  one fixed-risk budget.
- trade_management: pair integrity, notional tolerance, orphan repair,
  next-week exit, and stale close.
- trade_close: framework close helper, broker hard stops, and no Friday-close
  override.

## Safety boundary

Authorized only for a branch build, strict Q01, three fixed-risk backtest
presets (one logical basket plus two implementation legs), and one paced
logical Q02 handoff if CPU permits. No manual tester, optimization, live/demo/
shadow/stress preset, AutoTrading, `T_Live`, deploy/live manifest, portfolio
gate, portfolio admission, or correlation waiver is authorized.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-06 | initial overlapping relative-vote flip card | G0 | APPROVED; build pending |
| v1-build | 2026-09-06 | OWNER commodity-sleeve branch build | Q01 | PACER input-pin audit PASS; governed compile `e0781e04-0d31-48de-a5ba-227e47965c2d` returned `COMPILE_OK`; Q02 not enqueued because the 97% CPU stop ceiling was observed |
