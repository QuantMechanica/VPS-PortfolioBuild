---
card_schema_version: 2
type: strategy
strategy_id: BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026_S01
variant_id: BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026_S01
source_id: BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026
ea_id: QM5_41062
slug: xauxag-wgap-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41062_xauxag-wgap-fade_card.md
execution_contract_status: APPROVED
created: 2026-08-20
created_by: Research+Development
last_updated: 2026-08-20
g0_status: APPROVED
g0_decision: decisions/2026-08-20_qm5_41062_xauxag_opposed_weekend_gap_fade_g0.md
source_approval: decisions/2026-08-20_xauxag_opposed_weekend_gap_fade_source_approval.md
source_author: "Karol Borowski, Karol Lukasik, Brian M. Lucey, Edel Tully, and Karsten Schweikert"
source_authors: "Karol Borowski; Karol Lukasik; Brian M. Lucey; Edel Tully; Karsten Schweikert"
source_citation: "Borowski and Lukasik (2017), Journal of Management and Financial Sciences 27, 59-86; Lucey and Tully (2006), Applied Financial Economics 16(4), 319-333; Schweikert (2018), Journal of Banking & Finance 88, 44-51."
source_citations:
  - type: academic_paper
    citation: "Borowski, K. and Lukasik, M. (2017), Analysis of Selected Seasonality Effects in the Following Metal Markets, Journal of Management and Financial Sciences 27, 59-86."
    location: "Governed complete-read record strategy-seeds/sources/BOROWSKI-LUKASIK-METALS-2017/source.md; Sections 4.3 and 5; Tables 5 and 7"
    quality_tier: B
    role: precious_metals_weekend_observation_clock
  - type: academic_paper
    citation: "Lucey, B. M. and Tully, E. (2006), Seasonality, risk and return in daily COMEX gold and silver data 1982-2002, Applied Financial Economics 16(4), 319-333."
    location: "Governed complete-author-copy record strategy-seeds/sources/LUCEY-TULLY-DOW-2006/source.md; DOI 10.1080/09603100500386586"
    quality_tier: B
    role: adverse_monday_metals_evidence_and_carrier_clock
  - type: academic_paper
    citation: "Schweikert, K. (2018), Are gold and silver cointegrated? New evidence from quantile cointegrating regressions, Journal of Banking & Finance 88, 44-51."
    location: "Governed record strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md; DOI 10.1016/j.jbankfin.2017.11.010"
    quality_tier: B
    role: state_dependent_gold_silver_relative_value_lineage
strategy_mechanic: synchronized-prior-friday-close-to-current-monday-open-xau-xag-strict-opposed-log-gap-one-session-ratio-fade-equal-notional-basket
sources:
  - "[[sources/BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/weekend-gap-reversion]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/log-weekend-gap]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver-ratio, market-neutral-basket, weekend-gap, event-reversion, atr-hard-stop, next-d1-exit, symmetric-long-short, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41062_XAU_XAG_WGAPFADE_D1
symbol: QM5_41062_XAU_XAG_WGAPFADE_D1
host_symbol: XAUUSD.DWX
companion_symbol: XAGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [410620000, 410620001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately five to twenty completed paired packages per full post-warm-up year after exact Monday/Friday synchronization and strict component-gap opposition; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify a one-session gold/silver opposed-weekend-gap ratio fade outside the certified XAU/SP500/NDX/XNG book. Verify exact synchronized Friday/Monday endpoints, current-open-only chronology, strict component opposition, two-sided fade mapping, durable Monday attempt, aggregate fixed risk, atomic basket repair, and next-D1 lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, synchronized_friday_monday_endpoints, current_open_only, strict_opposed_component_gaps, two_sided_fade_mapping, persistent_monday_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_d1_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses named peer-reviewed metals-calendar and state-dependent gold/silver relationship lineages while disclosing that the opposed-gap conjunction is an untested QM translation; R2 locks exact synchronized Friday/Monday endpoints, current opens, strict component opposition, two-sided fade mapping, durable attempt, aggregate fixed risk, equal notional, hard stops, spreads, and next-D1 lifecycle; R3 uses registered native XAU/XAG D1 histories and active slots 0/1 with synchronization and CFD-basis risks explicit; R4 is deterministic timestamp, OHLC, logarithm, ATR, quote, position, deal, and terminal-state arithmetic without a banned signal, trained output, external feed, grid, or martingale; canonical dedup and manual family review found no exact identity."
---

# QM5_41062 XAU/XAG Opposed Weekend-Gap Fade

## Hypothesis

When gold and silver open a broker Monday with strictly opposite gaps from
their synchronized prior Friday closes, the gold/silver ratio has experienced
a discrete weekend dislocation rather than a common precious-metals move.
Fading both component gaps for one D1 session may capture short-horizon
relative reversion while suppressing broad metal beta.

The candidate is a logical two-leg package intended to add a return driver
outside the certified XAU/SP500/NDX/XNG book. Equal notional is an execution
target, not proof of neutrality. Q02 must establish density and economics, and
unchanged Q09 alone may establish realized book correlation.

## Source Traceability And Claim Boundary

The approved joined source packet is
`strategy-seeds/sources/BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026/source.md`,
authorized before card extraction at
`decisions/2026-08-20_xauxag_opposed_weekend_gap_fade_source_approval.md` and
durably committed as `fec22cf8d`.

Borowski and Lukasik supply the precious-metals Friday-close-to-Monday-open
observation and unequal sample weekend behavior. Lucey and Tully supply both
metals on a Monday calendar and binding adverse evidence that individual
futures first-moment effects are weak and non-robust. Schweikert supplies a
state-dependent gold/silver relationship lineage.

None of the authors tests opposite-signed weekend gaps, this fade direction,
a Darwinex continuous-CFD basket, equal-notional sizing, fixed cash risk, ATR
stops, spread caps, attempt state, or the next-D1 lifecycle. No source return,
profit factor, Sharpe ratio, drawdown, trade count, transaction cost, hedge
ratio, CFD equivalence, threshold, stop, hold, or portfolio-correlation
statistic transfers. Every implementation choice below is a pre-result QM
falsification choice.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,549 registry rows and 625 root
cards and returned `CLEAN`. Manual semantic review fixes the boundaries:

- `QM5_20019_xauxag-wkend` always buys XAU and sells XAG before the weekend,
  then exits Monday. This card first observes the complete weekend move,
  requires strict component opposition, and can trade either direction.
- `QM5_20095_auag-mon-diff` unconditionally buys XAU and sells XAG on Monday.
  This card is conditional, two-sided, and flat on same-sign or zero gaps.
- `QM5_20157_xau-xag-ratio`, `QM5_20161_xauxag-ols-rv`,
  `QM5_20263_xauxag-mad-rv`, and `QM5_20268_xauxag-qtail-rv` estimate rolling
  centers, residuals, robust scales, or tails. This card estimates none.
- `QM5_20275_gsr-runfade` requires five consecutive same-sign daily relative
  returns. This card uses exactly one Friday-close-to-Monday-open event and
  the individual component signs are load-bearing.
- `QM5_41030`, `QM5_41039`, `QM5_41040`, and `QM5_41057` decompose complete
  weeks or months into overnight/session relative flows. This card reads no
  within-day session return and closes at the next D1 boundary.
- `QM5_12533` is only the validated logical-basket manifest/order recipe; its
  signal is an EURJPY/GBPJPY cointegration spread.
- `QM5_12567_cum-rsi2-commodity` is a single-symbol long-only two-day
  oscillator pullback and has no intermetal, weekend, or paired logic.

The exact XAU/XAG carrier, synchronized Friday/Monday endpoints, strict
opposed component gaps, two-sided contrarian mapping, one Monday attempt,
equal-notional aggregate-risk package, and next-D1 exit are jointly
load-bearing. Verdict:
`CLEAN_XAUXAG_OPPOSED_WEEKEND_GAP_ONE_SESSION_FADE_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host: `XAUUSD.DWX`, D1, slot 0, magic `410620000`.
- Exact companion: `XAGUSD.DWX`, D1, slot 1, magic `410620001`.
- Logical symbol: `QM5_41062_XAU_XAG_WGAPFADE_D1`.
- Formation: immediately prior synchronized Friday closes and current
  synchronized Monday opens.
- Decision: first executable Monday D1 tick within 180 minutes of bar open.
- Ordinary exit: first synchronized later D1 boundary, normally Tuesday.
- Expected cadence: five to twenty completed packages/year; retire below five.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1` for the complete package.

## Formula

Let `F` be the immediately prior broker-Friday D1 bar and `M` the current
broker-Monday D1 bar. Both legs must have identical `F` and `M` timestamps,
and `M-F` must span exactly the intervening calendar weekend. Define:

```text
g_xau = ln(XAU_open(M) / XAU_close(F))
g_xag = ln(XAG_open(M) / XAG_close(F))
```

With positive finite prices and finite non-zero gaps:

```text
g_xau > 0 and g_xag < 0 => SELL XAU, BUY XAG
g_xau < 0 and g_xag > 0 => BUY XAU, SELL XAG
otherwise                => FLAT
```

No current high, low, close, tick-return magnitude, fitted center, beta,
scale, quantile, channel, trend, oscillator, volume, or event feed enters.

## Rules

The entry, exit, filter, management, and risk rules below are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XAUUSD.DWX` D1 bar while attached to EA
   ID 41062 and magic slot zero.
2. Repair malformed, orphaned, duplicated, same-side, stopless, notional-
   invalid, later-bar, or stale owned exposure before entry-only gates.
3. Require the raw current host D1 bar date to equal the broker date and be a
   genuine Monday. Require the companion current D1 timestamp to equal the
   host timestamp. Reject delayed attachment beyond 180 minutes.
4. Require both shift-one timestamps to match exactly, be the immediately
   preceding broker Friday, and be exactly three calendar days before the
   Monday timestamp. Holiday, missing, duplicated, shifted, or asynchronous
   endpoint patterns fail closed.
5. Read only current bar opens and prior bar closes for both symbols. Require
   all four prices positive and finite. Compute the two log gaps exactly as
   defined above.
6. Require both gaps finite and non-zero with strictly opposite signs. Same-
   sign gaps, either zero, equality, invalid logs, and missing data are flat.
7. SELL XAU/BUY XAG only for positive XAU and negative XAG gaps. BUY XAU/SELL
   XAG only for negative XAU and positive XAG gaps. Signal magnitude does not
   alter side or size.
8. Once strict opposition exists, persist the current broker-Monday date
   before spread, quote, ATR, sizing, news, or order gates. A rejection,
   failure, stop, repair, or restart may not retry that Monday.
9. Require no owned exposure, executable side-specific quotes, and no
   genuinely positive spread wider than 1,500 XAU points or 500 XAG points.
   A modeled zero `.DWX` spread is valid.
10. Require valid completed-bar `ATR(20,D1)` for both legs and attach one
    frozen hard stop at `3.0 * ATR` on each. Size the package so combined
    normalized stop risk cannot exceed the single `RISK_FIXED=1000` budget.
11. Target one-to-one absolute entry notional. Round down only and reject a
    resulting mismatch above 20 percent. Use no take-profit.
12. Submit the two market legs once. If either leg fails or the resulting
    composition/notional contract is invalid, immediately flatten all owned
    exposure. No pending order, retry, one-leg fallback, scale-in, grid,
    martingale, pyramid, hedge overlay, or second entry exists.

## 5. Exit Rules

1. Broker hard stops and framework kill-switch closure remain authoritative.
2. Immediately flatten an orphan, duplicate, same-side, wrong-symbol, wrong-
   magic, missing-stop, invalid-volume, or notional-invalid package.
3. Close both legs on the first synchronized host/companion D1 boundary later
   than the package entry boundary, normally broker Tuesday.
4. Close after four elapsed calendar days as a final stale guard.
5. Framework Friday close remains enabled at broker hour 21 as an emergency
   safety path, not the ordinary lifecycle.
6. No target, gap-fill-price exit, signal reversal, trailing stop, break-even
   move, partial exit, discretionary close, or intentional weekend hold is
   authorized.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41062, slot zero, and both registered magics.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF for Q02; lifecycle repair is never
  delayed by an entry-only gate.
- Current Monday/prior Friday chronology, synchronized timestamps, positive
  finite prices, strict opposed gaps, durable attempt, side-specific trade
  mode, spread, quote, ATR, sizing, stop geometry, and notional match all fail
  closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, rolling center, fitted hedge ratio, or
  manual signal is read at runtime.

## 7. Trade Management Rules

- Own exactly one `XAUUSD.DWX` position under magic `410620000` and one
  opposite-side `XAGUSD.DWX` position under magic `410620001`.
- Persist the last attempted broker-Monday date so restart cannot create a
  second attempt in the same week.
- Manage malformed, later-boundary, stale, and kill-switch exits on every tick
  before entry evaluation.
- Freeze both original hard stops; never widen, trail, or remove them.
- Do not retry, add, pyramid, grid, martingale, partially close, add a third
  hedge, or reverse.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_entry_dow` | 1 | broker Monday |
| `strategy_prior_dow` | 5 | immediately prior broker Friday |
| `strategy_entry_grace_minutes` | 180 | new-D1 execution window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.0 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal absolute entry notional |
| `strategy_max_notional_mismatch_pct` | 20.0 | lot-step mismatch ceiling |
| `strategy_max_hold_days` | 4 | stale repair only |
| `strategy_xau_max_spread_points` | 1500 | XAU cost guard |
| `strategy_xag_max_spread_points` | 500 | XAG cost guard |
| `qm_friday_close_enabled` | true | emergency safety guard |
| `qm_friday_close_hour_broker` | 21 | broker close boundary |

No gap threshold, weekday, endpoint, direction, ratio, stop, spread, hold, or
lifecycle sweep is authorized.

## Author Claims

The sources supply only the weekend/Monday observation clock and a related,
state-dependent precious-metals carrier. This card does not claim source
replication, profitability, density, continuous-CFD equivalence, exact beta
neutrality, portfolio admission, or realized decorrelation.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` for the combined package.
- Frozen hard stops: `3.0 * ATR(20,D1)` from completed data on each leg.
- No target and no signal-strength sizing.
- Major risks are weekend jumps, one-leg fills, stop-risk asymmetry, lot-step
  notional mismatch, gold/silver beta drift, CFD/futures boundary basis,
  financing, spread, sparse opposed gaps, and overlap with the XAU book.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Acceptance And Retirement

Q02 retires rather than tunes on zero trades, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong or
asynchronous weekday endpoints, any current-bar high/low/close leakage, same-
sign or zero-gap entry, wrong fade direction, duplicate attempt, one-leg
survivor, aggregate-risk breach, notional mismatch above 20 percent, missing
hard stop, next-D1 exit failure, nondeterminism, or invalid fixed-risk mode.

No weak result may be rescued by adding a magnitude threshold, changing the
Friday/Monday endpoints, accepting same-sign gaps, estimating a beta, adding a
trend/season filter, changing the fade side, widening stops, or extending the
hold. Any such change creates a new identity and requires a new source/card
decision.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, synchronized endpoints, gaps, opposition, side, attempt, spreads, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers and basket order helper |
| malformed/orphan/notional, later-D1, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus package lifecycle helper |
| emergency Friday and survivor repair | Trade Close | strategy lifecycle helper plus framework Friday close |
| kill switch, ownership, magic resolver, aggregate fixed-risk mode | Framework No-Trade | standard framework orchestration plus foreign-magic registration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Validation Plan

Q01 must prove:

1. exact synchronized Monday/current and Friday/prior timestamps, including
   rejection of Tuesday, Thursday, holiday, delayed, and mismatched inputs;
2. current-open/prior-close log gaps only, strict sign opposition, zero and
   same-sign rejection, and both contrarian direction mappings;
3. persisted Monday attempts prevent retry after downstream failure and
   restart;
4. equal-notional down-rounding stays within 20 percent and aggregate
   normalized stop risk never exceeds one fixed-risk budget;
5. atomic broken-package repair and first-later-D1/four-day exits remain
   reachable; and
6. strict compile, card lint, build checks, setfile schema, basket manifest,
   magic resolver, and static Q01 validation pass.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-20 | initial opposed-weekend-gap XAU/XAG card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-20 | APPROVED | `decisions/2026-08-20_qm5_41062_xauxag_opposed_weekend_gap_fade_g0.md` |
| Q01 Build Validation | - | NOT_RUN | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one
logical D1 `RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue
only below tester and CPU ceilings. It does not authorize a manual backtest,
terminal control, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio-gate change, portfolio
admission, decorrelation claim, or correlation waiver.
