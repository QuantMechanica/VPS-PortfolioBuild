---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-WOPEN-MOM-2026_S01
variant_id: MOP-WTI-WOPEN-MOM-2026_S01
source_id: MOP-WTI-WOPEN-MOM-2026
ea_id: QM5_41019
slug: wti-wopen-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41019_wti-wopen-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-16_wti_week_opening_momentum_g0.md
source_approval: decisions/2026-08-16_wti_week_opening_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence and retrieval hash in strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_return_sign_continuation_family_and_wti_membership
strategy_mechanic: exact-friday-monday-tuesday-wti-opening-segment-return-sign-entry-on-wednesday-with-friday-close
sources:
  - "[[sources/MOP-WTI-WOPEN-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/week-opening-information-segment]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/closed-price-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, time-series-momentum, week-opening-segment, weekly-rebalance, atr-hard-stop, friday-close, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410190000
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
q01_status: PENDING
q02_status: PENDING
review_focus: "Falsify an exact-clock WTI week-opening return-sign continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify weekday continuity, completed endpoints, no late restart entry, and Friday flattening; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_weekday_sequence, completed_price_endpoints, wednesday_decision_clock, weekly_attempt_state, no_late_restart_entry, risk_mode_dual, friday_close_enabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 peer-reviewed complete-read WTI momentum lineage with disclosed weekly-horizon translation; R2 exact weekday sequence, endpoints, sign, timing, no-late-entry and lifecycle; R3 native XTI D1; R4 deterministic with no banned signal or trained logic; canonical dedup CLEAN and nearby families manually separated."
---

# WTI Fixed Week-Opening Segment Momentum

## Hypothesis

The sign of WTI's completed return over the opening segment of a full broker
week may persist through the remainder of that week as physical-market news,
inventory expectations, and positioning are incorporated gradually. The
candidate measures the exact prior-Friday-close to Tuesday-close return,
enters once on Wednesday in that direction, and exits at Friday close.

This is a falsifiable weekly-horizon translation. The source does not test
this exact two-session formation, fixed Wednesday clock, WTI-only continuous
CFD, Friday lifecycle, or the QM portfolio.

## Source Traceability And Claim Boundary

The sole governed source packet is
`strategy-seeds/sources/MOP-WTI-WOPEN-MOM-2026/source.md`, approved before
extraction in
`decisions/2026-08-16_wti_week_opening_momentum_source_approval.md` at commit
`e6bc3ffff`.

Moskowitz, Ooi, and Pedersen supply the own-return-sign continuation family
and WTI membership in their commodity-futures universe. The paper uses rolled
futures excess returns, monthly horizons, volatility scaling, and diversified
portfolios. It does not establish a WTI-only weekly-opening result.

The Friday-Monday-Tuesday sequence, Friday and Tuesday endpoints, Wednesday
entry, 180-minute restart boundary, continuous-CFD carrier, Friday close,
hard stop, fixed-dollar risk, spread cap, and persistent attempt ledger are
disclosed QM choices. No source return, alpha, coefficient, significance,
trade density, drawdown, cost, CFD equivalence, decorrelation, or portfolio
result transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker returned `CLEAN` across 4,506 EA-
registry rows and 602 root-card files for the slug, strategy ID, author set,
and complete mechanic. Manual review separates the closest families:

- `QM5_41013_wti-mopen-mom` forms on the first five sessions of a broker
  month, decides on the sixth, and holds to the next month. This card owns an
  exact weekly segment and Friday close.
- `QM5_12965_wti-week-orb` constructs Monday's high/low range and waits for a
  buffered breakout with trend, range, and close-location filters. This card
  uses no range breakout or signal indicator and decides only on Wednesday
  from the opening segment's net return sign.
- `QM5_13049_xti-1w-mom-vol` evaluates rolling thresholded five-D1 returns,
  requires a realized-volatility percentile state, and exits on reversal or
  time. This card uses an exact Friday-to-Tuesday segment, sign only, and a
  fixed Friday close.
- `QM5_20154_wti-wed-trend` uses a completed 252-D1 return state on Wednesday.
  This card uses only the current broker week's completed opening segment.
- `QM5_20217_wti-wkend-mom` trades a Monday gap outside Friday's range plus a
  volatility buffer and exits on the next D1 bar. This card enters Wednesday
  and uses neither a gap, range, nor volatility signal.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback rather than
  a fixed-clock WTI weekly continuation.

Verdict:
`CLEAN_WTI_FIXED_WEEK_OPENING_SEGMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

- Evaluate the entry path only on a new `XTIUSD.DWX` D1 bar.
- Require the current bar's broker weekday to be Wednesday.
- Read exactly the three immediately preceding completed D1 bars and require
  them, newest first, to be Tuesday, Monday, and prior Friday.
- Require their broker dates to be exactly one, two, and five calendar days
  before the current Wednesday. Missing or shifted holiday sessions consume
  no attempt on non-Wednesdays and consume the Wednesday flat once observed;
  they are never substituted.
- Derive the attempt key as the exact current Wednesday `yyyymmdd`.
- If no durable current-Wednesday attempt exists, persist the key before
  history validation, return calculation, news, spread, quote, ATR, sizing,
  or order gates. Never retry the Wednesday.
- Compute elapsed time from the current Wednesday D1 bar timestamp. If it is
  negative or greater than 180 minutes, consume the attempt flat and never
  backfill the week after a late restart.
- Require positive, finite Tuesday and prior-Friday completed closes.
- Compute `opening_return = log(TuesdayClose / PriorFridayClose)`. Monday close
  is a continuity observation only; the current Wednesday price is excluded.
- BUY at market when `opening_return > 0`; SELL at market when
  `opening_return < 0`; consume flat on exact zero or invalid arithmetic.
- Require a valid `ATR(20,D1)` from the prior completed bar and place one
  frozen hard stop at `3.5 * ATR`; use no take-profit.
- Require no owned position, a valid positive quote, and no genuinely
  positive spread wider than 1,500 points. A zero modeled `.DWX` spread is
  valid.
- Use magic slot 0 only. Signal magnitude never scales risk.

## 5. Exit Rules

- Framework Friday close is enabled and closes the position at broker hour
  21. Management must remain reachable before any entry-only gate.
- Close owned exposure on a Sunday, Monday, or Tuesday D1 bar when its open
  time precedes that bar, treating it as stale carry from a prior week.
- Close after six calendar days as a final stale-position guard.
- Close malformed exposure that lacks one valid WTI position, direction,
  positive volume, positive open price, or valid open time.
- The frozen broker hard stop and framework kill switch remain active
  throughout the hold.
- No target, opposite-signal exit, trailing stop, break-even move, partial
  exit, or discretionary close is authorized.

## 6. Filters (No-Trade Module)

- Exact host contract: `XTIUSD.DWX`, D1, EA ID 41019, magic slot 0.
- Exact locked risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Both news axes are OFF because the signal uses only native completed prices;
  management and exit remain reachable regardless of entry clearance.
- Friday close is ON at broker hour 21.
- Strategy-specific weekday, date, history, endpoint, arithmetic, timing,
  spread, quote, ATR, attempt, and one-position checks fail closed.
- No external data, futures curve, inventory, volume, open interest, event
  calendar, analyst forecast, file, API, or manual runtime input is used.

## 7. Trade Management Rules

- One position per magic and at most one consumed attempt per exact Wednesday.
- Persist the attempt before every fallible entry condition.
- On restart after the 180-minute entry window, consume the exact Wednesday
  flat if no attempt record exists; never backfill a late entry.
- Corroborate the attempt ledger against owned entry deal history so a stop,
  rejection, restart, or blocked framework gate cannot create re-entry.
- Close malformed or stale exposure before the news and entry path, retrying
  on later ticks until flat.
- No scale-in, pyramid, grid, martingale, partial close, adaptive parameter,
  PnL-dependent state, or trained output.

## Parameters To Test

| parameter | default | declared range | role |
|---|---:|---|---|
| `strategy_entry_grace_minutes` | 180 | [180] | locked Wednesday restart boundary |
| `strategy_atr_period` | 20 | [20] | completed-bar hard-stop estimate |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 6 | [6] | final stale guard beyond Friday close |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

The weekday sequence, calendar offsets, endpoints, sign map, entry grace,
attempt behavior, direction, stop, spread, and Friday lifecycle are locked.
A failed baseline may not be rescued by moving the clock, changing the
formation, adding a magnitude or regime filter, changing direction, widening
risk, or retrying a consumed week.

## Author Claims

No verbatim performance claim is imported. The paper is used only for the
own-return-sign continuation family and WTI membership. The exact weekly-
opening realization is a QM hypothesis whose economics and density must be
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
`PORTFOLIO_WEIGHT=1`. Risk is sized only from the frozen server-side stop.
The absolute formation return never changes lots or the risk budget.

Q02 must retire on zero trades, fewer than five completed positions per full
year, nondeterministic weekday sequencing, current-bar leakage, late restart
entries, repeated attempts, weekend carry past repair, risk-mode mismatch, or
nonpositive governed economics. Q09 alone may establish realized correlation
with the certified book.

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
- [x] Exact and fuzzy dedup clean; all nearby WTI families manually separated.

## Framework Alignment

- no_trade: exact WTI/D1/ID/slot, locked risk/news/Friday inputs, history,
  quote, spread, attempt, and one-position guards.
- trade_entry: exact weekday/date sequence, completed log-return sign,
  180-minute entry boundary, frozen ATR stop, and consumed Wednesday attempt.
- trade_management: close prior-week, six-day stale, or malformed exposure
  before entry-only gates and retry until flat.
- trade_close: framework Friday close, `QM_TM_ClosePosition` repair path,
  broker hard stop, and kill switch.
- news hook: both axes OFF and never suspends management.

## Implementation Notes

- Build only `XTIUSD.DWX` D1, slot 0. Do not expand the carrier universe.
- Use the framework new-bar gate exactly once in the entry path. Management
  runs on every tick before the news/entry gate.
- A bounded three-bar `CopyRates` read is allowed only behind that new-bar
  gate for the bespoke weekday sequence. Do not hand-roll a per-EA bar-change
  tracker.
- Persist the consumed `yyyymmdd` state with a terminal global variable and
  corroborate it with owned deal history.
- Create exactly one D1 `backtest` setfile. Do not create demo, shadow, live,
  stress, or optimization setfiles.
- Estimated complexity: medium. Data requirement: standard native D1 history.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial fixed week-opening momentum extraction | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED | `decisions/2026-08-16_wti_week_opening_momentum_g0.md` |
| Q01 Build Validation | pending | PENDING | branch-only build not yet validated |
| Q02 Baseline Screening | pending | PENDING | not yet enqueued |

## Safety Boundary

Research/backtest only. This card does not authorize a manual tester, live,
demo, shadow, stress, or optimization setfile; AutoTrading; `T_Live`; a
deploy or T_Live manifest; portfolio admission; a portfolio-gate edit; or a
correlation waiver.
