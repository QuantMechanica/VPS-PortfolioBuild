---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XTIXNG-WALT3-RV-20260907_S01
variant_id: AI-CODEX-XTIXNG-WALT3-RV-20260907_S01
source_id: AI-CODEX-XTIXNG-WALT3-RV-20260907
ea_id: QM5_41373
slug: xtixng-walt3-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41373_xtixng-walt3-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-07
created_by: Research+Development
last_updated: 2026-09-07
g0_status: APPROVED
g0_decision: decisions/2026-09-07_qm5_41373_xtixng_weekly_alternation_reversion_g0.md
source_approval: decisions/2026-09-07_xtixng_weekly_alternation_reversion_source_approval.md
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
strategy_mechanic: normalized-week-boundary-xti-xng-four-synchronized-completed-week-endpoints-three-adjacent-relative-log-returns-strict-sign-alternation-newest-relative-winner-fade-equal-notional-one-week-hold
sources:
  - "[[sources/AI-CODEX-XTIXNG-WALT3-RV-20260907]]"
concepts: ["[[concepts/oil-gas-relative-value]]", "[[concepts/weekly-sign-alternation]]", "[[concepts/market-neutral-basket]]"]
indicators: ["[[indicators/completed-week-relative-log-return]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, oil-gas-relative-value, market-neutral-basket, three-week-sign-alternation, newest-winner-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41373_XTI_XNG_WALT3_RV_D1
symbol: QM5_41373_XTI_XNG_WALT3_RV_D1
host_symbol: XTIUSD.DWX
companion_symbol: XNGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [413730000, 413730001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eight to sixteen completed paired packages per full post-warm-up year after strict three-week alternation, synchronization, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_ALTERNATION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED
review_focus: "Falsify a strict three-completed-week XTI/XNG relative-sign alternation fade outside the certified XAU/SP500/NDX/XNG book. Verify four consecutive synchronized completed-week endpoints, three strict relative-return signs, exact alternation, newest-winner fade, durable weekly attempt, aggregate fixed risk, atomic package repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xti_xng_carrier, immediately_preceding_four_monday_anchors, synchronized_completed_d1_closes, three_to_five_week_sessions, three_adjacent_relative_returns, strict_nonzero_return_differences, exact_sign_alternation, newest_winner_reversion, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 preserves complete reputable oil/gas and commodity evidence plus adverse instability while disclosing the untested weekly alternation translation; R2 locks endpoints, signs, direction, lifecycle, and risk; R3 uses registered native XTI/XNG D1 data; R4 uses deterministic non-trained arithmetic. No exact duplicate exists; two-return magnitude, outright common-shock, leader-state, and four-return majority-vote siblings do not own the three-return strict alternation fade."
---

# QM5_41373 XTI/XNG Weekly Alternation Reversion

## Hypothesis

Three strict weekly reversals in the XTI-minus-XNG relative leader may identify
a short-lived choppy oil/gas state. The EA fades the newest relative winner for
one week with opposed XTI/XNG legs. This is market-neutral by construction
intent only; Q09 alone may establish realized correlation and the sources do
not establish the exact edge.

## Source-defined rules

Villar and Joutz establish economic oil/gas links and instability. Ramberg and
Parsons document a weak, shifting relationship. Fuertes, Miffre, and Rallis
provide commodity relative-return research lineage. None defines weekly sign
alternation, a contrarian side, or this CFD implementation.

## QM interpretations

The four-week endpoint reconstruction, three strict relative-return signs,
alternation state, newest-winner fade, equal-notional pair, hard stops, and
one-week hold are explicit QM translations. Their efficacy must be falsified
without parameter rescue.

## Rules

### Market, clock, and data

- Host `input strategy_host_symbol=XTIUSD.DWX`; companion
  `input strategy_companion_symbol=XNGUSD.DWX`; slots 0/1; D1 only.
- On the first tradable bar of a new Monday-anchored broker week, consume one
  durable attempt before every fallible gate.
- Reconstruct the final synchronized closes of exactly the four immediately
  preceding consecutive weeks; each must contain three to five sessions.
- Missing, asynchronous, duplicate, current-week, nonpositive, nonfinite, or
  nonconsecutive data consumes the week flat.

### Entry

Order endpoints oldest to newest and calculate three adjacent relative log
returns `d[i] = log(XTI[i+1]/XTI[i]) - log(XNG[i+1]/XNG[i])`. Require every
`abs(d[i]) > 1e-10`.

- `d0>0, d1<0, d2>0`: sell XTI and buy XNG.
- `d0<0, d1>0, d2<0`: buy XTI and sell XNG.
- Otherwise consume the week flat.

Open an equal-absolute-notional package with one aggregate
`RISK_FIXED=1000` budget, independent frozen `3.5*ATR(20,D1)` hard stops,
XTI/XNG spread ceilings of 1500/3000 points, and no target. Return magnitude
never sizes or filters risk.

## Risk

The basket has one aggregate risk budget, split across the two opposed legs;
it does not allocate `RISK_FIXED` independently to each order. Per-leg lots
are derived from the frozen ATR stop distance and then reduced until absolute
notionals are within 20%. If either valid leg cannot be sized or opened, the
package stays flat or immediately repairs back to flat. Equal notional does
not establish market neutrality, and Q09 correlation remains a separate gate.

### Exit and management

- Close both legs at the first tick of the next broker week or after ten
  calendar days as stale repair.
- Flatten all owned exposure on an orphan, malformed direction, missing stop,
  or more than 20% absolute-notional mismatch.
- No signal exit, retry, target, trail, break-even, partial, scale-in, grid,
  martingale, or pyramid.

## Framework execution overrides

There is no Parameters to Test list or sweep. Q02 uses locked defaults only:
`history_bars_d1=45`, weekly sessions `3..5`, epsilon `1e-10`, entry grace 180
minutes, ATR `20` at `3.5x`, equal-notional target `1.0`, maximum notional
mismatch `20%`, stale hold 10 days, spread caps 1500/3000, and order deviation
20 points. Framework inputs use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. News and Friday close remain disabled but are not
configuration-pinned.

## Exit precedence

The framework kill switch is absolute. Next, malformed or orphaned exposure,
missing stops, and excessive notional mismatch flatten the package. The
ten-day stale repair precedes the ordinary next-week exit. There is no signal
exit, target, trailing rule, Friday override, or discretionary close.

## Runtime data dependencies

Runtime uses only native DarwinexZero XTI/XNG D1 bars supplied through inputs,
positive synchronized completed-week closes, valid quotes and symbol
metadata, and enough ATR history for hard stops. Missing or invalid data
consumes the weekly attempt flat. No external calendar, alternative dataset,
model, or future observation is used.

## Reputable-source criteria

- R1: PASS with disclosed alternation-translation risk and no transferred
  result.
- R2: PASS; all data, state, entry, direction, risk, and lifecycle rules fixed.
- R3: PASS with synchronization and continuous-CFD basis risk.
- R4: PASS; deterministic native arithmetic only and no trained component.

## Non-duplicate boundary

`QM5_41358` uses two opposite relative returns plus an overshoot inequality;
`QM5_41359` and `QM5_41360` use two-return magnitude states; `QM5_41361` uses
individual-leg common direction; `QM5_41368` uses two common-sign outright
weeks and leader switching; `QM5_41372` uses four relative returns and an
overlapping majority-vote flip. This EA uniquely requires exactly three
strictly alternating relative-return signs, ignores magnitude beyond epsilon,
and fades the newest sign.

## Falsification and requalification

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Retire on zero packages, fewer than five completed
packages in any full post-warm-up year, or nonpositive economics. Do not alter
the carrier, endpoints, sign state, direction, risk, stop, or lifecycle to
rescue failure. Any future change needs a new variant, dedup, OWNER approval,
rebuild, and full Q01+ requalification.

## Framework alignment

- no_trade: exact input-driven identity, host/timeframe, locked strategy
  inputs, fixed-risk mode, finite bounded stress input, history,
  synchronization, position, quote, spread, and durable-attempt guards.
- trade_entry: cached alternating-sign direction and atomic opposed-leg
  package under one fixed-risk budget.
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
| v1 | 2026-09-07 | initial strict three-week alternation card | G0 | APPROVED; build pending |
