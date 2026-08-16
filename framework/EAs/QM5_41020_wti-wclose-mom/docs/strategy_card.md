---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-WCLOSE-MOM-2026_S01
variant_id: MOP-WTI-WCLOSE-MOM-2026_S01
source_id: MOP-WTI-WCLOSE-MOM-2026
ea_id: QM5_41020
slug: wti-wclose-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41020_wti-wclose-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-16_wti_week_closing_momentum_g0.md
source_approval: decisions/2026-08-16_wti_week_closing_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence and retrieval hash in strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_return_sign_continuation_family_and_wti_membership
strategy_mechanic: exact-prior-tuesday-wednesday-thursday-friday-wti-closing-segment-return-sign-entry-on-monday-with-wednesday-exit
sources:
  - "[[sources/MOP-WTI-WCLOSE-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/week-closing-information-segment]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/closed-price-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, time-series-momentum, week-closing-segment, weekly-rebalance, atr-hard-stop, time-exit, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410200000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 45-52 completed WTI positions per full post-warm-up year before holiday exclusions; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 48
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_HORIZON_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: PENDING
review_focus: "Falsify an exact-clock WTI week-closing return-sign continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify weekday continuity, completed endpoints, no late restart entry, and first-Wednesday flattening; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_weekday_sequence, completed_price_endpoints, monday_decision_clock, weekly_attempt_state, no_late_restart_entry, risk_mode_dual, friday_close_failsafe, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 peer-reviewed complete-read WTI momentum lineage with disclosed weekly-horizon translation; R2 exact weekday sequence, endpoints, sign, timing, no-late-entry and lifecycle; R3 native XTI D1; R4 deterministic with no banned signal or trained logic; exact dedup clean and the sole fuzzy family sibling manually separated."
---

# WTI Fixed Week-Closing Segment Momentum

## Hypothesis

The sign of WTI's completed return over the closing segment of a full broker
week may persist through the opening sessions of the next week as physical-
market information and positioning continue to adjust. The candidate measures
the exact prior-Tuesday-close to prior-Friday-close return, enters once on the
following Monday in that direction, and exits at the first Wednesday D1
boundary.

This is a falsifiable weekly-horizon translation. The source does not test
this exact three-session formation, fixed Monday clock, WTI-only continuous
CFD, Wednesday lifecycle, or the QM portfolio.

## Source Traceability And Claim Boundary

The sole governed source packet is
`strategy-seeds/sources/MOP-WTI-WCLOSE-MOM-2026/source.md`, approved before
extraction in
`decisions/2026-08-16_wti_week_closing_momentum_source_approval.md` at commit
`db5a2c257`.

Moskowitz, Ooi, and Pedersen supply the own-return-sign continuation family and
WTI membership in their commodity-futures universe. The paper uses rolled
futures excess returns, monthly horizons, volatility scaling, and diversified
portfolios. It does not establish a WTI-only weekly-closing result.

The Tuesday-through-Friday sequence, Tuesday and Friday endpoints, Monday
entry, 180-minute restart boundary, Wednesday exit, continuous-CFD carrier,
hard stop, fixed-dollar risk, spread cap, and persistent attempt ledger are
disclosed QM choices. No source return, alpha, coefficient, significance,
trade density, drawdown, cost, CFD equivalence, decorrelation, or portfolio
result transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,507 EA-registry rows and
603 root-card files. It found no exact match and raised only the expected fuzzy
family match to `wti-wopen-mom`; manual review separates the mechanics:

- `QM5_41019_wti-wopen-mom` forms from prior Friday through Tuesday, enters
  Wednesday, and exits Friday. This card forms over the disjoint prior
  Tuesday-through-Friday segment, enters Monday, and exits Wednesday; signal
  endpoints, entry clock, and owned holding segment do not overlap.
- `QM5_20217_wti-wkend-mom` trades a Monday gap beyond Friday's range plus a
  volatility buffer and exits on the next D1 bar. This card excludes the gap
  from its signal, uses completed close-to-close sign without a magnitude
  threshold, and holds through Tuesday.
- `QM5_20149_wti-montrend` and `QM5_20173_wti-mon-bullfade` gate a one-session
  Monday trade with a 252-D1 trend state. This card is symmetric and uses only
  the prior Tuesday-to-Friday segment.
- `QM5_13049_xti-1w-mom-vol` uses a rolling five-D1 return above a 1.25%
  magnitude threshold, a twenty-D1 volatility-rank gate, any-new-day timing,
  and a seven-day or reversal exit. This card is sign-only, exact-clock, and
  exits Wednesday.
- `QM5_20029_wti-monfri-daily` unconditionally shorts Monday and buys Friday.
  This card conditionally buys or sells Monday and never enters Friday.
- `QM5_12965_wti-week-orb`, `QM5_13075_xti-inweek-brk`, and
  `QM5_13095_xti-outweek-fade` use weekly range geometry, levels, and extra
  trend/range filters. This card uses only two completed close endpoints and
  their sign.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers. This card is a fixed-clock WTI continuation with no
  oscillator or cross-carrier allocation.

Registry row `21503,xti-weekly-tsmom-lowvol` has no card, EA directory,
setfile, or magic row in this branch and therefore is not an already-built
mechanic. Its family-level name remains disclosed; the exact endpoints,
sign-only rule, Monday clock, and Wednesday exit are load-bearing here.

Verdict:
`CLEAN_WTI_FIXED_WEEK_CLOSING_SEGMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

- Evaluate the entry path only on a new `XTIUSD.DWX` D1 bar.
- Require the current broker clock, not the raw D1 label, to be Monday.
- Support native same-day D1 labels and the factory energy convention that
  labels a session with the preceding calendar date. When the current label
  is 24-48 hours behind the broker clock, normalize it and all four completed
  labels by the same +1 calendar day before weekday/date checks. Apply no
  other offset, holiday shift, or bar substitution.
- Read exactly the four immediately preceding completed D1 bars and require
  them, newest first, to be Friday, Thursday, Wednesday, and Tuesday.
- Require their normalized broker dates to be exactly three, four, five, and
  six calendar days before the current Monday. Missing or shifted holiday
  sessions consume no attempt on non-Mondays and consume the Monday flat once
  observed; they are never substituted.
- Derive the attempt key as the exact current Monday `yyyymmdd`.
- If no durable current-Monday attempt exists, persist the key before history
  validation, return calculation, news, spread, quote, ATR, sizing, or order
  gates. Never retry the Monday.
- Compute elapsed time since the executable session open as broker time minus
  the raw D1 label modulo one day. If it is negative or greater than 180
  minutes, consume the attempt flat and never backfill the week after a late
  restart. Derive the attempt key from the unshifted broker-clock Monday.
- Require positive, finite prior-Friday and prior-Tuesday completed closes.
- Compute `closing_return = log(PriorFridayClose / PriorTuesdayClose)`.
  Intervening Wednesday/Thursday closes are continuity observations only; the
  current Monday price is excluded.
- BUY at market when `closing_return > 0`; SELL at market when
  `closing_return < 0`; consume flat on exact zero or invalid arithmetic.
- Require a valid `ATR(20,D1)` from the prior completed bar and place one
  frozen hard stop at `3.5 * ATR`; use no take-profit.
- Require no owned position, a valid positive quote, and no genuinely positive
  spread wider than 1,500 points. A zero modeled `.DWX` spread is valid.
- Use magic slot 0 only. Signal magnitude never scales risk.

## 5. Exit Rules

- On the first genuine broker-Wednesday D1 bar after entry, close the owned
  position before any entry-only news or spread gate and retry on later ticks
  until flat.
- Close owned exposure observed on Thursday or Friday if its open time
  precedes that bar, treating it as stale carry past the authorized Wednesday
  boundary.
- Close after five calendar days as a final stale-position guard.
- Close malformed exposure that lacks one valid WTI position, direction,
  positive volume, positive open price, or valid open time.
- Framework Friday close remains enabled at broker hour 21 as an additional
  fail-safe; it is not the ordinary strategy exit.
- The frozen broker hard stop and framework kill switch remain active
  throughout the hold.
- No target, opposite-signal exit, trailing stop, break-even move, partial
  exit, or discretionary close is authorized.

## 6. Filters (No-Trade Module)

- Exact host contract: `XTIUSD.DWX`, D1, EA ID 41020, magic slot 0.
- Exact locked risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Both news axes are OFF because the signal uses only native completed prices;
  management and exit remain reachable regardless of entry clearance.
- Friday close is ON at broker hour 21 only as a stale-position fail-safe.
- Strategy-specific weekday, date, history, endpoint, arithmetic, timing,
  spread, quote, ATR, attempt, and one-position checks fail closed.
- No external data, futures curve, inventory, volume, open interest, event
  calendar, analyst forecast, file, API, or manual runtime input is used.

## 7. Trade Management Rules

- One position per magic and at most one consumed attempt per exact Monday.
- Persist the attempt before every fallible entry condition.
- On restart after the 180-minute entry window, consume the exact Monday flat
  if no attempt record exists; never backfill a late entry.
- Corroborate the attempt ledger against owned entry deal history so a stop,
  rejection, restart, or blocked framework gate cannot create re-entry.
- Close malformed or out-of-lifecycle exposure before the news and entry path,
  retrying on later ticks until flat.
- No scale-in, pyramid, grid, martingale, partial close, adaptive parameter,
  PnL-dependent state, or trained output.

## Parameters To Test

| parameter | default | declared range | role |
|---|---:|---|---|
| `strategy_entry_grace_minutes` | 180 | [180] | locked Monday restart boundary |
| `strategy_atr_period` | 20 | [20] | completed-bar hard-stop estimate |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 5 | [5] | final stale guard beyond Wednesday exit |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

The weekday sequence, calendar offsets, endpoints, sign map, entry grace,
attempt behavior, direction, stop, spread, and Wednesday lifecycle are locked.
A failed baseline may not be rescued by moving the clock, changing the
formation, adding a magnitude or regime filter, changing direction, widening
risk, or retrying a consumed week.

## Author Claims

No verbatim performance claim is imported. The paper is used only for the
own-return-sign continuation family and WTI membership. The exact weekly-
closing realization is a QM hypothesis whose economics and density must be
measured by the unchanged pipeline.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-ordering estimate, not evidence.
- `expected_dd_pct: 30.0` reflects crude-oil gap and false-continuation risk.
- `expected_trade_frequency`: approximately 45-52 positions per full year
  before holiday and fail-closed exclusions.
- `risk_class: high`.
- `ml_required: false`.

## Risk

Backtests use one fixed budget: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is sized only from the frozen server-side stop. The
absolute formation return never changes lots or the risk budget.

Q02 must retire on zero trades, fewer than five completed positions per full
year, nondeterministic weekday sequencing, current-bar leakage, late restart
entries, repeated attempts, carry past the Wednesday repair boundary,
risk-mode mismatch, or nonpositive governed economics. Q09 alone may
establish realized correlation with the certified book.

## Strategy Allowability Check

- [x] R1: one peer-reviewed JFE source with DOI, complete-paper review,
  retrieval hash, WTI membership, and the weekly translation disclosed.
- [x] R2: exact weekday sequence, date offsets, endpoints, sign, timing,
  attempt, risk, stop, spread, and exits are deterministic.
- [x] R3: registered `XTIUSD.DWX` D1 history supplies every runtime input.
- [x] R4: deterministic native arithmetic, one position per magic, and no
  prohibited trained or adaptive logic.
- [x] No signal indicator: entry uses two completed closes, exact calendar
  positions, and a logarithmic return sign. ATR is risk plumbing only.
- [x] Exact identity dedup clean; the sole fuzzy weekly family sibling and all
  nearby WTI families are manually separated.

## Framework Alignment

- no_trade: exact WTI/D1/ID/slot, locked risk/news/Friday inputs, history,
  quote, spread, attempt, and one-position guards.
- trade_entry: exact weekday/date sequence, completed log-return sign,
  180-minute entry boundary, frozen ATR stop, and consumed Monday attempt.
- trade_management: close first-Wednesday, Thursday/Friday stale, five-day
  stale, or malformed exposure before entry-only gates and retry until flat.
- trade_close: `QM_TM_ClosePosition(..., QM_EXIT_STRATEGY)`, framework Friday
  fail-safe, broker hard stop, and kill switch.
- news hook: both axes OFF and never suspends management.

## Implementation Notes

- Build only `XTIUSD.DWX` D1, slot 0. Do not expand the carrier universe.
- Use the framework new-bar gate exactly once in the entry path. Management
  runs on every tick before the news/entry gate.
- A bounded four-bar `CopyRates` read is allowed only behind that new-bar gate
  for the bespoke weekday sequence. Do not hand-roll a per-EA bar-change
  tracker.
- Normalize a known prior-date energy D1 label only by applying the same +1
  calendar day to the current and four completed labels. Broker time remains
  authoritative for the Monday decision and persistent attempt date.
- Persist the consumed `yyyymmdd` state with a terminal global variable and
  corroborate it with owned deal history.
- Create exactly one D1 `backtest` setfile. Do not create demo, shadow, live,
  stress, or optimization setfiles.
- Estimated complexity: medium. Data requirement: standard native D1 history.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial fixed week-closing momentum extraction | G0 | APPROVED |
| v2 | 2026-08-16 | V5 build, calendar-label fixtures, strict compile, and deterministic validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED | `decisions/2026-08-16_wti_week_closing_momentum_g0.md` |
| Q01 Build Validation | 2026-08-16 | PASS; compiler and build check 0 errors, 0 warnings; reference tests 9/9 PASS | `D:\QM\reports\framework\21\build_check_20260816_025236.json`; compile summary `D:\QM\reports\compile\20260816_024658\summary.csv` |
| Q02 Baseline Screening | pending | PENDING | not yet enqueued |

## Safety Boundary

Research/backtest only. This card authorizes one branch-only non-live build,
strict Q01, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It
authorizes no manual backtest, live/demo/shadow/stress/optimization setfile,
AutoTrading, `T_Live`, deploy/T_Live manifest, portfolio admission,
portfolio-gate change, or correlation waiver.
