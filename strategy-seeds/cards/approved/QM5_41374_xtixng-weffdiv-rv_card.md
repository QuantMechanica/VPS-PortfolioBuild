---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XTIXNG-WEFFDIV-RV-20260907_S01
variant_id: AI-CODEX-XTIXNG-WEFFDIV-RV-20260907_S01
source_id: AI-CODEX-XTIXNG-WEFFDIV-RV-20260907
ea_id: QM5_41374
slug: xtixng-weffdiv-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41374_xtixng-weffdiv-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-07
created_by: Research+Development
last_updated: 2026-09-07
g0_status: APPROVED
g0_decision: decisions/2026-09-07_qm5_41374_xtixng_weekly_efficiency_divergence_reversion_g0.md
source_approval: decisions/2026-09-07_xtixng_weekly_efficiency_divergence_reversion_source_approval.md
source_author: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis"
source_authors: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis"
source_citation: "Villar and Joutz (2006), U.S. EIA; Ramberg and Parsons (2012), The Energy Journal 33(2), DOI 10.5547/01956574.33.2.2; Fuertes, Miffre, and Rallis (2010), Journal of Banking & Finance 34(10), DOI 10.1016/j.jbankfin.2010.04.009."
source_citations:
  - type: government_research
    citation: "Villar, J. A. and Joutz, F. L. (2006). The Relationship Between Crude Oil and Natural Gas Prices. U.S. Energy Information Administration."
    location: "Complete-read packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: oil_gas_economic_link_and_instability
  - type: peer_reviewed_paper
    citation: "Ramberg, D. J. and Parsons, J. E. (2012). The Weak Tie Between Natural Gas and Oil Prices. The Energy Journal 33(2), 13-35."
    location: "DOI 10.5547/01956574.33.2.2; complete-read packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: weak_time_varying_relationship_and_adverse_evidence
  - type: peer_reviewed_trading_paper
    citation: "Fuertes, A.-M., Miffre, J., and Rallis, G. (2010). Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals. Journal of Banking & Finance 34(10), 2530-2548."
    location: "DOI 10.1016/j.jbankfin.2010.04.009; complete-read packet strategy-seeds/sources/FMR-MOMTS-2010/source.md"
    quality_tier: A
    role: commodity_relative_return_lineage_only
strategy_mechanic: synchronized-completed-week-independent-absolute-body-to-range-efficiency-strict-opposite-outer-terciles-fade-high-efficiency-leg-body-sign-opposed-equal-notional-xti-xng-package-one-week-hold
sources: ["[[sources/AI-CODEX-XTIXNG-WEFFDIV-RV-20260907]]"]
concepts: ["[[concepts/oil-gas-relative-value]]", "[[concepts/weekly-efficiency-divergence]]", "[[concepts/market-neutral-basket]]"]
indicators: ["[[indicators/completed-week-body-range-efficiency]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, oil-gas-relative-value, market-neutral-basket, weekly-efficiency-divergence, high-efficiency-leg-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41374_XTI_XNG_WEFFDIV_RV_D1
symbol: QM5_41374_XTI_XNG_WEFFDIV_RV_D1
host_symbol: XTIUSD.DWX
companion_symbol: XNGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [413740000, 413740001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eight to eighteen completed paired packages per full post-warm-up year after strict efficiency divergence, synchronization, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_RULE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: 30 D1 history bars; 3-5 synchronized completed-week sessions; independent abs(close-open)/(high-low) efficiency; strict 1/3 and 2/3 thresholds; nonzero body; 180-minute entry grace; 3.5*ATR(20,D1) frozen stops; equal notionals; 20% mismatch ceiling; 10-day stale exit; 1500/3000-point spread ceilings."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: COMPILE_PENDING_CPU_CEILING
q02_status: NOT_ENQUEUED_CPU_CEILING
force_build: true
review_focus: "Falsify a completed-week XTI/XNG body-range-efficiency divergence fade outside the certified XAU/SP500/NDX/XNG book. Verify synchronized OHLC, independent efficiencies, strict outer-tercile divergence, high-efficiency body-sign fade, durable weekly attempt, aggregate fixed risk, atomic repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xti_xng_carrier, immediately_preceding_monday_anchor, synchronized_completed_d1_ohlc, three_to_five_week_sessions, independent_body_range_efficiencies, strict_opposite_outer_terciles, high_efficiency_body_sign_fade, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 preserves complete reputable oil/gas and commodity evidence plus adverse instability while disclosing the untested efficiency-divergence translation; R2 locks OHLC aggregation, exact ratios, strict thresholds, direction, lifecycle, and risk; R3 uses registered native XTI/XNG D1 data; R4 uses deterministic non-trained arithmetic. No exact or fuzzy repository duplicate exists; outright weekly body momentum, completed-week close-location, multi-session path efficiency, residual, ratio, return-sign, and flow siblings do not own the paired independent efficiency-tercile divergence fade."
---

# QM5_41374 XTI/XNG Weekly Efficiency-Divergence Reversion

## Hypothesis

Oil and natural gas retain economic links but frequently express shocks with
different directional efficiency. When one leg traverses most of its completed
weekly range from open to close while the other finishes with little net body,
fading the directional leg against the choppy companion for one week may
capture short-lived relative overshoot. This is market-neutral by construction
intent only; Q09 alone may establish realized correlation.

## Source-defined rules

Villar and Joutz establish economic oil/gas links and instability. Ramberg and
Parsons document a weak, shifting tie. Fuertes, Miffre, and Rallis provide
commodity relative-return research lineage. None defines the body/range state,
thresholds, contrarian side, or this CFD implementation.

## QM interpretations

The synchronized weekly OHLC aggregation, independent absolute body/range
efficiencies, strict divergence state, body-sign fade, equal-notional pair,
hard stops, and one-week hold are explicit QM translations. Their efficacy is
unproven and must be falsified without parameter rescue.

## Rules

### Market, clock, and data

- Host `XTIUSD.DWX`, companion `XNGUSD.DWX`, slots 0/1, D1 only.
- On the first tradable bar of a new Monday-anchored broker week, consume one
  durable attempt before every fallible gate.
- From a bounded 30-bar buffer, aggregate the exact immediately preceding
  synchronized completed week; require three to five unique sessions.
- Missing, asynchronous, duplicate, current-week, nonpositive, nonfinite, or
  invalid-range data consumes the week flat.

### Entry Rules

For each leg calculate `e=abs(week_close-week_open)/(week_high-week_low)` and
require a positive body, positive range, finite `e`, and `0<e<=1`.

- XTI `e>2/3`, XNG `e<1/3`: fade the XTI completed-week body and trade XNG in
  the opposite direction.
- XNG `e>2/3`, XTI `e<1/3`: fade the XNG completed-week body and trade XTI in
  the opposite direction.
- Equality, two high states, two low states, interior states, or zero body are
  flat. The low-efficiency leg's body direction is ignored.

Open one opposed equal-absolute-notional package with aggregate
`RISK_FIXED=1000`, independent frozen `3.5*ATR(20,D1)` hard stops, XTI/XNG
spread ceilings of 1500/3000 points, and no target.

## Exit Rules

- Broker hard stops and the framework kill switch are authoritative.
- Flatten malformed, orphaned, duplicated, same-side, stopless, wrong-magic,
  wrong-symbol, invalid-volume, or over-20%-notional-mismatch exposure.
- Close both legs on the first tick of the next broker week or after ten
  calendar days as stale repair.
- No signal exit, retry, target, trail, break-even, partial, scale-in, grid,
  martingale, pyramid, or discretionary close.

## Filters (No-Trade Module)

Exact identity, symbols, D1, magics, fixed-risk mode, finite bounded stress,
synchronized bars, prior-week membership, finite positive OHLC, strict
efficiency state, durable attempt, spreads, quotes, ATR, stop geometry, and
notional match all fail closed. News and Friday-close inputs remain disabled
but are not equality-pinned by the strategy guard.

## Trade Management Rules

Own exactly one XTI leg under magic `413740000` and one opposite XNG leg under
magic `413740001`, or flatten all owned exposure. Persist the last attempted
week across restart. Preserve hard stops and package atomicity.

## Parameters To Test

There is no sweep. Q02 uses only the locked baseline in frontmatter. No
post-result change may rescue a weak or sparse result.

## Author Claims

The sources support an unstable oil/gas relationship and commodity-relative
research context. They do not claim that this conjunction is profitable,
neutral, dense, or decorrelated.

## Risk

Persistent decoupling, regional gas shocks, price gaps, one-leg fills,
lot-step mismatch, continuous-CFD basis and financing, spread, and low density
can dominate. One aggregate fixed-risk budget and per-leg hard stops bound the
planned package loss but do not eliminate execution or gap risk.

## Strategy Allowability Check

- [x] R1 reputable sources pass with explicit translation risk.
- [x] R2 endpoints, state, side, attempt, risk, and lifecycle are fixed.
- [x] R3 registered native XTI/XNG D1 data is available with synchronization risk.
- [x] R4 deterministic arithmetic only; no ML or banned logic.
- [x] Repository dedup found no exact or fuzzy match; external Wiki coverage limit is recorded.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| week clock, synchronization, OHLC, efficiencies, state, attempt, costs, ATR | Trade Entry | deterministic helpers and basket order helper |
| orphan/notional, later-week, stale repair | Trade Management | atomic package lifecycle helper |
| framework reason mapping | Trade Close | no separate signal exit |
| kill switch, ownership, magics, aggregate risk | Framework No-Trade | standard framework plus foreign magic |
| news OFF | News hooks | runtime framework setting; never strategy-pinned |

## Validation Plan

Q01 must prove week anchors across month/year boundaries, synchronized OHLC,
3-5 session acceptance, exact efficiency arithmetic, strict boundary and side
fixtures, no current-week leakage, durable attempts, aggregate-risk sizing,
equal-notional rounding, atomic repair, next-week/stale exits, card lint,
mandatory framework-input pin audit, strict compile, set schema, basket
manifest, resolver identity, and static artifact validation.

Q02 alone measures density and economics. Q09 alone may establish correlation.

## Failure Conditions And Safety Boundary

Retire on zero packages, fewer than five packages in any full post-warm-up
year, nonpositive governed economics, arithmetic or leakage defect, invalid
risk, missing stop, broken atomicity, wrong lifecycle, or nondeterminism.

Authorized: branch-only build, strict Q01, three fixed-risk backtest presets,
and one paced logical Q02 enqueue below the CPU ceiling. Forbidden: manual
backtests, terminal control, live/demo/shadow/stress/optimization presets,
portfolio-gate edits, correlation waivers, portfolio admission, deploy/live
manifests, `T_Live`, AutoTrading, or live use.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-07 | initial weekly efficiency-divergence card | G0 | APPROVED; build pending |
| v1 build | 2026-09-07 | audited source-only build and compile handoff | Q01 | COMPILE_PENDING; Q02 stopped at CPU ceiling |

