---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MRANGE-MIGRATE-MOM-2026_S01
variant_id: MOP-WTI-MRANGE-MIGRATE-MOM-2026_S01
source_id: MOP-WTI-MRANGE-MIGRATE-MOM-2026
ea_id: QM5_41102
slug: wti-mrange-migrate-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41102_wti-mrange-migrate-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-22
created_by: Research+Development
last_updated: 2026-08-22
g0_status: APPROVED
g0_decision: decisions/2026-08-22_qm5_41102_wti_monthly_range_migration_momentum_g0.md
source_approval: decisions/2026-08-22_wti_monthly_range_migration_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-MRANGE-MIGRATE-MOM-2026/source.md"
    quality_tier: A
    role: monthly_own_price_continuation_and_wti_carrier_lineage
strategy_mechanic: normalized-month-boundary-wti-two-consecutive-completed-monthly-ohlc-packages-strict-higher-high-higher-low-or-lower-high-lower-low-auction-range-migration-continuation-one-month-hold
sources:
  - "[[sources/MOP-WTI-MRANGE-MIGRATE-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-month-auction-range-migration]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-high-low-structure]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, completed-month-range-migration, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411020000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-9 completed WTI positions per full post-warm-up year after exact monthly history, strict two-endpoint migration, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_MONTHLY_RANGE_STATE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a direct-WTI completed-month auction-range migration trend outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact month boundaries, two consecutive completed monthly high-low packages, 17-23 sessions each, strict HH+HL or LH+LL state, mixed/equality flat, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_month_bar, consecutive_calendar_months, completed_monthly_ohlc, bounded_month_session_counts, strict_two_endpoint_range_migration, equality_and_mixed_flat, no_current_month_leakage, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized WTI sleeve; R1 complete-read peer-reviewed WTI monthly-continuation source with range-state translation risk; R2 locked monthly high-low packages and lifecycle; R3 registered native XTI D1; R4 deterministic native arithmetic; no exact identity"
---

# QM5_41102 WTI Completed-Month Auction-Range Migration Momentum

## Hypothesis

When both endpoints of crude oil's completed monthly auction range migrate in
the same direction versus the parent month, the whole price-discovery region
has shifted rather than merely printing a close-to-close fluctuation.
Following a strict higher-high/higher-low state long or a strict lower-high/
lower-low state short for the next broker month may capture a structural WTI
trend outside the certified XAU/SP500/NDX/XNG book.

The WTI carrier is economically different from the current certified book,
but that does not establish profitability or decorrelation. Q02 owns
frequency and baseline economics; unchanged Q09 alone may establish realized
portfolio correlation.

## Source Traceability And Claim Boundary

The sole source of record is
`strategy-seeds/sources/MOP-WTI-MRANGE-MIGRATE-MOM-2026/source.md`, authorized
before extraction by
`decisions/2026-08-22_wti_monthly_range_migration_momentum_source_approval.md`
at commit `e74e9ab06`. The complete parent source hash is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons, explicitly test one-month formation/holding rules within pooled
commodities, and include WTI in their futures universe. They do not test a
monthly higher-high/higher-low or lower-high/lower-low auction state, a
continuous CFD, fixed-dollar ATR risk, or the QM book. Every high/low range-
state, execution, and risk choice below is a declared QM interpretation.

No source return, WTI-only alpha, profit factor, drawdown, trade count,
transaction cost, CFD equivalence, neutrality, or correlation statistic is
imported.

## Non-Duplicate Decision

The canonical pre-allocation checker included author and mechanic fields,
scanned 4,591 registry identities, 1,270 repository cards, and 45 Strategy-
Wiki nodes. It found no exact identity and returned the expected fuzzy weekly
family. After allocation, the exact hit must be solely reserved `QM5_41102`.
Manual semantic review fixes the boundaries:

- `QM5_41089_wti-wrange-migrate-mom` uses two completed broker weeks and a
  one-week hold. This card aggregates roughly a full month of sessions into
  each package, decides at most twelve times/year, and holds the next month.
- `QM5_41101_xng-wrange-migrate-mom` is a weekly natural-gas carrier. No XNG
  or weekly result transfers to this direct-WTI monthly test.
- `QM5_20187_wti-tsmom1m` reads two completed month-end closes and trades the
  resulting return sign. This card never reads a close and requires joint
  migration of aggregate monthly highs and lows.
- `QM5_20008_wti-month-ch3` compares one completed month-end close with three
  prior month-end closes. This card has no close channel and compares two
  complete high/low packages only.
- `QM5_41064_wti-mflip-mom` requires an adjacent monthly return-sign change.
  This card has no return, close, or flip condition.
- weekly outside-settlement, midpoint-overlap, and close-breakout cards use
  different endpoints and a different clock.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback beneath a slow trend filter. This card is symmetric,
  oscillator-free, direct WTI, monthly, and structural.

The exact WTI carrier, two consecutive completed broker-calendar monthly
high/low packages, 17-to-23 sessions each, strict `HH+HL` long / `LH+LL`
short state, equality/inside/outside/mixed flat rule, first-new-month entry,
durable attempt, fixed risk, and next-month exit are jointly load-bearing.
Verdict:
`CLEAN_WTI_COMPLETED_MONTH_TWO_ENDPOINT_AUCTION_RANGE_MIGRATION_CONTINUATION_AFTER_HORIZON_AND_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Target symbol and host: exact `XTIUSD.DWX`.
- Timeframe: exact D1; magic slot 0; planned magic `411020000`.
- Decision: first tradable normalized D1 bar of a new broker-calendar month,
  within 180 elapsed raw-session minutes.
- Formation: the two immediately preceding consecutive completed calendar-
  month high/low packages, with 17 through 23 completed sessions each.
- Normal exit: first tick whose normalized broker month is later than the
  open position's month.
- Expected frequency: approximately 5-9 completed positions/year; Q02 must
  prove at least five per full post-warm-up year or retire.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `H0` and `L0` be the newest completed month's aggregate high and low, and
`H1` and `L1` its consecutive parent's aggregate high and low:

```text
H0 > H1 and L0 > L1  => BUY XTIUSD.DWX
H0 < H1 and L0 < L1  => SELL XTIUSD.DWX
otherwise             => FLAT
```

All values complete before the decision month begins. The current D1 open,
high, low, close, volume, and tick price never enter the signal. Equality at
either endpoint, an inside or outside month, or one-up/one-down mixed
migration is flat. Migration distance never changes eligibility or risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XTIUSD.DWX` D1 bar under EA 41102 and
   magic slot zero.
2. Repair malformed, later-month, or stale owned exposure before entry-only
   gates.
3. Select label offset zero when the raw current D1 date equals broker date,
   or `+1` day only when it is exactly one calendar day behind. Apply the same
   convention to every historical bar and reject every other or mixed state.
4. Require the normalized current label to be the first completed-session
   label observed for its broker month and require the newest completed bar to
   belong to the immediately previous calendar month.
5. Require attachment within 180 elapsed minutes of raw D1 bar open. Persist
   the current `yyyymm` attempt before history, signal, spread, quote, ATR,
   sizing, news, or order gates. Never retry that month.
6. Require no owned position and no same-magic entry deal already recorded in
   the current broker month.
7. Within a fixed 90-bar buffer, reconstruct exactly the immediately completed
   month and its parent. Require exact calendar adjacency, strict reverse-time
   bar order, 17 through 23 unique sessions per month, positive finite OHLC,
   and strict positive aggregate ranges.
8. Aggregate maximum high and minimum low independently for each month. Buy
   only when both newest endpoints are strictly higher. Sell only when both
   are strictly lower. Equality, inside/outside geometry, or mixed migration
   stays flat.
9. Require a valid executable quote and no genuinely positive spread wider
   than 1,500 points. Modeled zero `.DWX` spread is valid.
10. Attach one frozen hard stop at `3.5 * ATR(20,D1)` from completed data and
    size one position to `RISK_FIXED=1000`. Use no take-profit.
11. Submit one slot-zero market order once. No pending order, retry, scale-in,
    grid, martingale, pyramid, hedge, or second entry exists.

## 5. Exit Rules

1. Broker hard stop and framework kill-switch closure remain authoritative.
2. Immediately flatten duplicate, wrong-symbol, wrong-magic, missing-stop,
   invalid-volume, or invalid-open-time exposure.
3. Close on the first tick whose normalized broker `yyyymm` is later than the
   position-open broker month.
4. Close after forty elapsed calendar days as a stale safety repair.
5. No Friday close, target, signal flip, trail, break-even move, partial exit,
   discretionary close, or intentional hold beyond the next month.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41102, slot zero, and registered magic.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Uniform label normalization, first-month-bar clock, 180-minute grace,
  consecutive months, session counts, OHLC aggregation, strict range state,
  durable attempt, spread, quote, ATR, sizing, and stop geometry fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `411020000`.
- Persist the last attempted `yyyymm` across restart.
- Manage malformed, later-month, stale, and kill-switch exits before entry.
- Freeze the original hard stop; never widen, trail, or remove it.
- Do not retry, add, pyramid, grid, martingale, partially close, hedge, or
  reverse inside the month.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | exact first-month-bar execution window |
| `strategy_history_bars` | 90 | bounded D1 monthly-OHLC buffer |
| `strategy_required_months` | 2 | exact consecutive completed packages |
| `strategy_min_month_bars` | 17 | minimum sessions in each completed month |
| `strategy_max_month_bars` | 23 | maximum sessions in each completed month |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve full-month identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply monthly own-price continuation lineage,
one-month formation/hold tests, and WTI membership. They do not supply the
monthly high/low range-migration state.

## QM Interpretations

`MOP-WTI-MRANGE-MIGRATE-MOM-2026_S01` fixes completed monthly high/low
packages, strict two-endpoint comparisons, equality/mixed-state rejection,
continuous-CFD month boundaries and label normalization, session-count bounds,
entry grace, persistent attempt, fixed-dollar ATR risk, spread cap, and
lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later normalized broker-month closure.
4. Forty-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 OHLC/timestamps, broker time, symbol metadata,
quotes, completed-bar ATR, framework position/deal state, and persistent
terminal-global attempt state. No external dataset or calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are false monthly continuation, weekend/month-end gaps,
  continuous-CFD roll basis, XTI session-label ambiguity, financing, spread,
  density below the floor, range-state source translation, and realized book
  overlap.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, wrong
or mixed labels, nonconsecutive months, invalid session counts or OHLC, entry
at equality or a mixed/inside/outside state, wrong side, current-month
leakage, late or repeated attempt, missing hard stop, wrong next-month close,
nondeterminism, or invalid fixed-risk mode.

Changing the WTI carrier, month packages, range comparisons, direction,
attempt clock, risk, stop, or lifecycle requires a new identity, binary,
complete stream reconciliation, and portfolio requalification. A failed
result may not be rescued by accepting equality or mixed states, adding a
close or current-month gate, reversing the side, shortening the hold, or
adding season, return, close-location, volatility, volume, moving-average,
inventory, event, or external state.

## Strategy Allowability Check

- [x] R1: one bounded source ID with named peer-reviewed authors, DOI,
  complete-paper evidence, durable retrieval hash, and explicit WTI
  membership; monthly range-state translation risk is disclosed.
- [x] R2: exact clock, labels, months, sessions, high/low aggregation, strict
  comparisons, side, attempt, hard stop, spread, and lifecycle are mechanical.
- [x] R3: registered `XTIUSD.DWX` D1 plus native V5 execution state supplies
  all runtime inputs; energy-label and continuous-CFD basis risk remain open.
- [x] R4: deterministic timestamp, OHLC, comparison, ATR, quote, position,
  deal-history, and terminal-state arithmetic only; no prohibited mechanism.
- [x] Dedup: no monthly WTI identity collision; weekly horizon siblings and
  adjacent monthly close/return families are explicitly separated.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, month clock, sessions, high/low aggregation, strict range state, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-month and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-month-bar
and 180-minute clock; month adjacency across year boundaries; two consecutive
completed monthly packages; 17/20/23-session acceptance and 16/24-session
rejection; exact high/low aggregation; long and short migrations; equality,
inside, outside, and both mixed states flat; no current-bar leakage;
persistent monthly attempts; fixed-risk frozen-stop sizing; next-month and
stale repair; card lint; strict compile; setfile schema; resolver identity;
and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-22 | initial WTI completed-month range-migration card | Q00 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| Q00 Research Intake | 2026-08-22 | APPROVED | `decisions/2026-08-22_qm5_41102_wti_monthly_range_migration_momentum_g0.md` |
| Q01 Build Validation | - | PENDING | approved build has not yet entered |
| Q02 Baseline Screening | - | NOT_QUEUED | requires Q01 PASS and fresh capacity check |

## Safety Boundary

This card may authorize a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or `T_Live` manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
