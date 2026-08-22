---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MINSIDE-BODY-MOM-2026_S01
variant_id: MOP-WTI-MINSIDE-BODY-MOM-2026_S01
source_id: MOP-WTI-MINSIDE-BODY-MOM-2026
ea_id: QM5_41107
slug: wti-minside-body-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41107_wti-minside-body-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-22
created_by: Research+Development
last_updated: 2026-08-22
g0_status: APPROVED
g0_decision: decisions/2026-08-22_qm5_41107_wti_monthly_inside_body_momentum_g0.md
source_approval: decisions/2026-08-22_wti_monthly_inside_body_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-MINSIDE-BODY-MOM-2026/source.md"
    quality_tier: A
    role: monthly_own_price_continuation_and_wti_carrier_lineage
strategy_mechanic: normalized-month-boundary-wti-two-consecutive-completed-monthly-ohlc-packages-newest-strictly-inside-parent-range-newest-own-open-close-body-sign-continuation-one-month-hold
sources:
  - "[[sources/MOP-WTI-MINSIDE-BODY-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-inside-month]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-ohlc]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-inside-month, own-month-body-direction, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411070000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 2-6 completed WTI positions per full post-warm-up year after exact monthly history, strict containment, body inequality, and execution gates; Q02 must prove at least two/year or retire."
expected_trades_per_year_per_symbol: 4
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_MONTHLY_INSIDE_BODY_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a direct-WTI completed inside-month body continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact month boundaries, two consecutive completed monthly OHLC packages, 17-23 sessions each, strict full containment, contained-month own-body direction, equality/non-inside flat, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_month_bar, consecutive_calendar_months, completed_monthly_ohlc, bounded_month_session_counts, strict_full_containment, contained_month_own_body_sign, equality_and_noninside_flat, no_current_month_leakage, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized WTI sleeve; R1 complete-read peer-reviewed WTI monthly-continuation source with inside-month translation risk; R2 locked monthly OHLC containment/body/attempt/risk/lifecycle; R3 registered native XTI D1; R4 deterministic native arithmetic; no foreign identity collision"
---

# QM5_41107 WTI Completed-Month Inside-Body Momentum

## Hypothesis

When a completed WTI monthly auction is strictly contained within its parent
month but still closes directionally away from its own opening price, that
direction may represent pressure accumulating during compression. Following
the contained month's own body direction for the next broker month may capture
a low-frequency structural crude-oil continuation effect.

This is a direct physical-energy price carrier outside the certified
XAU/SP500/NDX/XNG book. That carrier difference does not establish
profitability or decorrelation. Q02 owns frequency and baseline economics;
unchanged Q09 alone may establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-WTI-MINSIDE-BODY-MOM-2026/source.md`, authorized
before extraction by
`decisions/2026-08-22_wti_monthly_inside_body_momentum_source_approval.md` at
commit `dca99885d`. The bounded extraction was committed at `1bf582724`. The
complete parent source hash is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons, explicitly test one-month formation/holding rules within pooled
commodities, and include WTI in their futures universe. They do not test a
WTI-only completed inside month, contained-month candle body, continuous CFD,
fixed-dollar ATR risk, or the QM book. Every containment, execution, and risk
choice below is a declared QM interpretation.

No source return, WTI-only alpha, profit factor, drawdown, trade count,
transaction cost, CFD equivalence, neutrality, or correlation statistic is
imported.

## Non-Duplicate Decision

The canonical pre-allocation checker included author and mechanic fields plus
the explicit Company Reference Wiki root. It scanned 4,596 registry
identities, 1,275 repository cards, and 45 Strategy-Wiki nodes. It found no
exact identity and returned only the expected inside/body-family matches.
Manual semantic review fixes the boundaries:

- `QM5_41091_wti-winside-body-mom` uses two completed broker weeks,
  three-to-five sessions per package, and a one-week hold. This card uses two
  completed calendar months, 17-to-23 sessions per package, and a one-month
  hold. Formation sample, auction horizon, turnover, financing exposure, and
  lifecycle are jointly different; no weekly result transfers.
- `QM5_41102_wti-mrange-migrate-mom` requires both high and low to migrate in
  the same direction beyond the parent and deliberately excludes opens and
  closes. This card requires the opposite range relation, strict containment,
  and derives side from the contained month's own open and close.
- `QM5_41106_wti-mbody-dominance-mom` reads one completed month, has no parent
  geometry, and requires a strict majority body share. This card reads two
  months, requires strict containment, and has no body-share threshold.
- `QM5_20187_wti-tsmom1m` reads two month-end closes and follows every nonzero
  return sign. This card reads the newest month's first open and final close
  only after its entire range is strictly inside its parent.
- `QM5_13075_xti-inweek-brk` waits for current-week price to break an inside-
  week extreme and adds channel and exit filters. This card consumes no
  current-month signal OHLC and enters only at the new-month boundary.
- `QM5_12810_wti-month-orb` trades a breakout of the new month's first five
  D1 bars, not a completed inside-month body; and
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not symmetric monthly WTI continuation.

The exact WTI carrier, two consecutive completed calendar-month OHLC
packages, 17-to-23-session contract, strict full containment, contained-month
own-body sign, equality-flat rules, consumed monthly attempt, fixed risk, and
full-next-month hold are jointly load-bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_STRICT_INSIDE_BODY_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Target symbol and host: exact `XTIUSD.DWX`.
- Timeframe: exact D1; magic slot 0; planned magic `411070000`.
- Decision: first tradable normalized D1 bar of a new broker-calendar month,
  within 180 elapsed raw-session minutes.
- Formation: the two immediately preceding consecutive completed calendar-
  month packages, with 17 through 23 completed sessions each.
- Normal exit: first tick whose normalized broker month is later than the
  position-open month.
- Expected frequency: approximately 2-6 completed positions/year; Q02 must
  prove at least two per full post-warm-up year or retire.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `O0`, `C0`, `H0`, and `L0` be the newest completed month's first open,
final close, aggregate high, and aggregate low. Let `H1` and `L1` be its
consecutive parent's aggregate high and low:

```text
inside = H0 < H1 && L0 > L1
body0  = C0 - O0

inside && body0 > 0  => BUY
inside && body0 < 0  => SELL
otherwise            => FLAT
```

All values complete before the decision month begins. The current D1 open,
high, low, close, volume, and tick price never enter the signal. Equal highs,
equal lows, equal open/close, non-inside geometry, zero range, or invalid
history is flat. Containment width and body magnitude never change eligibility
or risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XTIUSD.DWX` D1 bar under EA 41107 and
   magic slot zero.
2. Repair malformed, later-month, or stale owned exposure before entry-only
   gates.
3. Select label offset zero when the raw current D1 date equals broker date,
   or `+1` day only when it is exactly one calendar day behind. Apply the same
   convention to every historical bar and reject every other or mixed state.
4. Derive current, immediately completed, and parent `yyyymm` values from
   normalized time. Require the prior two months to be consecutive across
   year boundaries and prove that the newest completed bar is older than the
   current month.
5. Require attachment within 180 elapsed minutes of raw current D1 bar open.
   Persist the current decision `yyyymm` before history, signal, spread,
   quote, ATR, sizing, news, or order gates. Never retry that month.
6. Require no owned position and no same-magic entry deal already recorded in
   the current broker month.
7. Within a fixed 70-bar buffer, reconstruct exactly the immediately
   completed month and its parent. Require 17 to 23 unique bars per month,
   strict reverse-time order, positive finite OHLC, valid high/low geometry,
   exact month membership, and no current-month observation.
8. Aggregate each month's chronologically first open, final close, maximum
   high, and minimum low. Require strict `H0<H1 && L0>L1`.
9. Buy only when strict containment holds and `C0>O0`. Sell only when strict
   containment holds and `C0<O0`. Every equality, invalid, or non-inside
   state consumes the month flat.
10. Require a valid executable quote and no genuinely positive spread wider
    than 1,500 points. Modeled zero `.DWX` spread is valid.
11. Attach one frozen hard stop at `3.5 * ATR(20,D1)` from completed data and
    size one position to `RISK_FIXED=1000`. Use no take-profit.
12. Submit one slot-zero market order once. No pending order, retry, scale-in,
    grid, martingale, pyramid, hedge, or second entry exists.

## 5. Exit Rules

1. Broker hard stop and framework kill-switch closure remain authoritative.
2. Immediately flatten duplicate, wrong-symbol, wrong-magic, missing-stop,
   invalid-volume, or invalid-open-time exposure.
3. Close on the first tick whose normalized broker `yyyymm` is later than the
   position-open `yyyymm`.
4. Close after forty elapsed calendar days as a stale safety repair.
5. No Friday close, target, signal exit, trail, break-even move, partial exit,
   discretionary close, or intentional hold beyond the next broker month.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41107, slot zero, and registered magic.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes, legacy news mode, and Friday close are OFF; lifecycle repair
  is never delayed by an entry-only gate.
- Uniform label normalization, first-month-bar clock, 180-minute grace,
  consecutive months, monthly session counts, OHLC aggregation, strict
  containment, own-body sign, durable attempt, spread, quote, ATR, and sizing
  fail closed.
- Runtime cannot read a futures chain, inventory, volume, open interest,
  event feed, external file, API, regression, trained output, prior-result
  state, or manual signal.

## 7. Trade Management Rules

- Own at most one exact `XTIUSD.DWX` slot-zero position under magic
  `411070000`.
- Persist the last attempted decision `yyyymm` across restart; clear only a
  future-dated tester residue at initialization.
- Manage malformed, later-month, stale, and kill-switch exits on every tick
  before entry evaluation.
- Freeze the original hard stop; never widen, trail, remove, or replace it.
- Do not retry, add, pyramid, grid, martingale, partially close, hedge, or
  reverse inside the month.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_bars_d1` | 70 | bounded two-month buffer |
| `strategy_min_month_sessions` | 17 | complete-month lower bound |
| `strategy_max_month_sessions` | 23 | complete-month upper bound |
| `strategy_entry_grace_minutes` | 180 | first-month-bar window |
| `strategy_atr_period_d1` | 20 | completed-bar range estimate |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | entry cost guard |
| `qm_friday_close_enabled` | false | full-month identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive value |

Strict containment, body-side mapping, two-month package count,
17-to-23-session bounds, boundary entry, one-attempt rule, and next-month exit
are not parameters.

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply monthly own-return-sign continuation and
explicit WTI carrier lineage. They do not supply completed-month OHLC
aggregation, an inside-month gate, or CFD lifecycle.

## QM Interpretations

`MOP-WTI-MINSIDE-BODY-MOM-2026_S01` fixes the exact prior two calendar months,
completed monthly OHLC aggregation, strict full containment, contained-month
own-body direction, continuous-CFD clock, durable attempt, fixed risk, spread
cap, stop, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later broker-month closure.
4. Forty-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 timestamps and OHLC, broker time, symbol metadata,
quotes, completed-bar ATR, framework position/deal state, and persistent
terminal global-variable attempt state. No external runtime dataset exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are false continuation, compression failure, month-end gaps,
  continuous-CFD basis, financing, energy-label drift, strict-session
  sparsity, spread, density below the floor, source translation, and realized
  overlap with other momentum sleeves.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_MONTHLY_INSIDE_BODY_TRANSLATION_RISK | Named peer-reviewed DOI, complete-read evidence, durable hash, and explicit WTI membership; the monthly inside-body gate is disclosed as an untested QM translation. |
| R2 | PASS | Clock, label, two completed months, monthly OHLC, strict containment, body side, attempt, risk, and lifecycle are deterministic. |
| R3 | PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK | Registered native WTI D1 supplies all runtime inputs; Q02 owns label, density, cost, and CFD-basis sufficiency. |
| R4 | PASS | Native deterministic arithmetic and state only; no trained signal, banned indicator, external runtime feed, grid, or martingale. |

## Falsification And Requalification

Q02 retires rather than tunes on zero positions, fewer than two completed
positions per full post-warm-up year, nonpositive governed economics, wrong
label or month membership, invalid session count, current-month leakage,
incorrect monthly OHLC, accepting containment equality, wrong body side,
duplicate monthly attempt, invalid risk mode, missing stop, wrong lifecycle,
or nondeterminism.

Requalification requires a new OWNER-approved card version before accepting
equality, dropping either containment bound, changing direction or hold,
changing history/session bounds, or adding volatility, volume, season,
weekday, moving-average, breakout, event, inventory, external-data, or prior-
result gates. No post-result parameter salvage is authorized.

## Framework Alignment

| Card rule | V5 owner | Implementation target |
|---|---|---|
| Exact host, period, risk, news, Friday, frozen inputs | No-Trade | `Strategy_NoTradeFilter` plus framework initialization |
| Month label, adjacency, two OHLC packages, containment, body side, attempt, ATR sizing | Trade Entry | `Strategy_EntrySignal` |
| Frozen stop and malformed-position repair | Trade Management | `Strategy_ManageOpenPosition` plus pre-entry lifecycle repair |
| Next-month and forty-day stale exits | Trade Close | `Strategy_ExitSignal` |
| Native-price declaration; news OFF/OFF | News hook | `Strategy_NewsFilterHook` |

## Build Acceptance Contract

The build must prove exact identity, deterministic monthly aggregation, both
strict containment comparisons, all equality and non-inside cases, both body
directions, malformed and nonconsecutive history rejection, no current-month
OHLC leakage, durable attempt timing, fixed-risk stop sizing, next-month/stale
exits, card lint, strict compile/build checks, setfile schema, resolver
identity, and a deterministic reference test suite before Q02 handoff.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1-card | 2026-08-22 | new OWNER-authorized WTI structural sleeve | Q00 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| Q00 Research Intake | 2026-08-22 | APPROVED | this card plus declared decision record |
| Q01 Build and Spec | - | PENDING | - |
| Q02 Baseline | - | NOT_QUEUED | - |

No Q11 portfolio or live decision is made by this card.
