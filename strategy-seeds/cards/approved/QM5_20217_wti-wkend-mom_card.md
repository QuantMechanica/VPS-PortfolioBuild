---
card_schema_version: 2
ea_id: QM5_20217
slug: wti-wkend-mom
type: strategy
strategy_id: CHAN-TGIF-WTI-WKENDMOM-2026_S01
variant_id: CHAN-TGIF-WTI-WKENDMOM-2026_S01
source_id: CHAN-TGIF-WTI-WKENDMOM-2026
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20217_wti-wkend-mom_card.md
execution_contract_status: DRAFT
created: 2026-08-05
created_by: Research+Development
last_updated: 2026-08-16
source_authors: "Ernest P. Chan; Seth A. Hoelscher; Cedric Mbanga; Walt A. Nelson"
strategy_mechanic: genuine-monday-wti-opening-gap-directional-continuation-beyond-prior-friday-extreme-plus-lagged-90d-volatility
source_citation: "Chan (2013), Algorithmic Trading, Wiley, Chapter 7 Example 7.1; Hoelscher, Mbanga, and Nelson (2017), Journal of Finance Issues 16(1), 47-68."
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading."
    location: "Chapter 7, Example 7.1, printed pp. 156-157; complete governed source strategy-seeds/sources/SRC05/source.md; bounded raw extraction lines 7012-7066."
    quality_tier: A
    role: primary_mechanic
  - type: peer_reviewed_paper
    citation: "Hoelscher, S. A., Mbanga, C., and Nelson, W. A. (2017). TGIF? The Weekend Effect in Energy Commodities. Journal of Finance Issues 16(1), 47-68."
    location: "DOI 10.58886/jfi.v16i1.2264; complete official-paper review strategy-seeds/sources/TGIF-WTI-WEEKEND-2017/source.md."
    quality_tier: B
    role: wti_weekend_target_market
sources:
  - "[[sources/CHAN-TGIF-WTI-WKENDMOM-2026]]"
concepts:
  - "[[concepts/opening-gap-momentum]]"
  - "[[concepts/crude-oil-weekend-effect]]"
indicators:
  - "[[indicators/lagged-return-volatility]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, opening-gap-momentum, weekend-effect, symmetric-long-short, next-bar-exit, atr-hard-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 6-18 genuine-Monday WTI opening-gap packages/year after the prior-extreme plus 0.1-times-lagged-volatility threshold; Q02 must prove at least five/year on average or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
q02_work_item_id: 4eaf26f4-d7e7-4915-9e3f-9f0c4213d157
review_focus: "Falsify whether weekend-only WTI opening-gap continuation survives the FSTX/GBPUSD source-to-WTI substitution, D1 attachment, CFD roll/basis, gaps, costs, and realized correlation while adding a crude-oil clock absent from the certified XAU/SP500/NDX/XNG book."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode, source_carrier_substitution, genuine_weekend_sequence, completed_history_only, restart_safe_attempt, next_d1_exit, friday_close, q02_frequency_floor, cfd_futures_basis, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER 2026-08-05 commodity/energy sleeve mission: R1 Tier-A executable book rule plus peer-reviewed WTI weekend evidence; R2 locked genuine-Monday sequence, lagged 90-return volatility, source 0.1 threshold, direction, attempt state, stop, and next-D1 exit; R3 registered native XTIUSD.DWX D1 route; R4 deterministic native arithmetic only. Deterministic dedup CLEAN across 4,274 registry rows and 390 cards plus manual source-parent and opposite-direction WTI gap review."
---

# QM5_20217 WTI Weekend Opening-Gap Momentum

## Hypothesis

Weekend closures can concentrate information and stop orders at the reopen.
When Monday WTI opens beyond Friday's entire range by Chan's lagged volatility
threshold, the first session may continue in the gap direction as clustered
stops cascade or weekend information diffuses.

This is a direct-crude, once-per-week decision clock unlike the certified
XAU, SP500, NDX, and XNG carriers. It is a falsifiable candidate, not a claim
of profitability, decorrelation, certification, or portfolio admission.

## Source traceability and claim boundary

The approved composite packet is
`strategy-seeds/sources/CHAN-TGIF-WTI-WKENDMOM-2026/source.md`.

Chan supplies the exact opening-gap direction, prior-session high/low
reference, `0.1` multiplier, lagged 90-session close-to-close volatility, and
same-session exit. His tested carriers are FSTX and GBPUSD, not WTI.
Hoelscher, Mbanga, and Nelson document a WTI weekend/Monday return structure,
but do not test opening-gap continuation or this threshold.

The WTI carrier, genuine Friday-to-Monday restriction, D1 first-tick entry,
ATR stop, fixed cash risk, spread ceiling, and next-D1 exit are QM
translations. No source return, Sharpe ratio, PF, drawdown, trade count, CFD
basis, or portfolio-correlation estimate is imported.

## Formula

At a genuine Monday D1 bar, use exactly 91 completed D1 closes to form 90
arithmetic returns:

```text
r[j] = Close[j] / Close[j+1] - 1, j = 1..90
mean90 = sum(r[j]) / 90
stdret90 = sqrt(sum((r[j] - mean90)^2) / 89)
upper = FridayHigh * (1 + 0.10 * stdret90)
lower = FridayLow  * (1 - 0.10 * stdret90)
```

- `MondayOpen > upper`: BUY WTI.
- `MondayOpen < lower`: SELL WTI.
- Equality, invalid arithmetic, nonpositive OHLC, zero volatility, or an
  unordered threshold remains flat for the consumed week.

The current Monday open is known at attachment. Every high, low, close, and
return used by the signal is completed. There is no intrabar recomputation,
moving average, oscillator, regression, trained model, or external input.

## Non-duplicate decision

The canonical checker returned `CLEAN` with no exact or fuzzy match. Manual
review resolves the material neighbors:

- `QM5_9151` applies Chan's opening-gap family to GDAXI, UK100, and GBPUSD H1
  sessions. This card is the first exact WTI D1 carrier and permits decisions
  only at a genuine Friday-to-Monday boundary.
- registry-only `QM5_1029` has no magic mapping or build and is not WTI.
- `QM5_12750` sells a positive WTI Monday gap and targets Friday close;
  `QM5_12779` buys a negative gap and targets Friday close. Both fade the gap.
  This card buys positive breakaway gaps and sells negative breakaway gaps,
  with no fill target.
- `QM5_12596` is an unconditional Monday short. `QM5_20117` is a Thursday-
  surge Friday reversal. Neither reads the Monday open against Friday's full
  range and lagged volatility.
- `QM5_12567` is a two-day commodity oscillator pullback, not a weekend or
  prior-extreme continuation rule.

The WTI carrier, genuine weekend sequence, prior-range break, lagged
volatility buffer, same-direction entry, and one-session lifecycle are jointly
load-bearing. Removing the carrier/weekend restriction recreates the source
parent; reversing direction recreates the existing WTI gap-fill family.

## Markets, timeframe, and cadence

- Carrier: exact `XTIUSD.DWX`, D1, slot 0, magic `202170000`.
- Decision: first observed tick within five minutes of a broker-calendar
  Monday D1 bar immediately following a completed Friday D1 bar.
- Maximum cadence: one consumed decision per genuine Monday.
- Expected cadence: approximately 6-18 completed packages/year after warm-up;
  retire below five/year on average.
- Ordinary hold: Monday open to the first following D1 boundary.

## Rules

The entry, exit, filter, and management rules below are the complete baseline.
No baseline sweep or post-result rescue is authorized.

## 4. Entry Rules

1. Require exact `XTIUSD.DWX`, D1, EA ID `20217`, magic slot 0, and every
   frozen baseline input.
2. Evaluate only on a current broker-calendar Monday whose immediately prior
   completed D1 bar is Friday. Missing Monday sessions never shift to Tuesday.
3. Require the first observed tick within five minutes of the Monday D1 bar
   open. A late initialization consumes the missed week and stays flat.
4. Persist the Monday `YYYYMMDD` attempt before history, signal, spread,
   quote, news, stop, risk, or order gates. A rejection, stop, blocked gate,
   or restart cannot retry that Monday.
5. Reject when an owned position or owned entry deal already exists for the
   current Monday.
6. Load exactly 91 completed D1 closes and compute the 90 arithmetic returns,
   sample standard deviation, and thresholds defined above.
7. BUY only when Monday open is strictly above the upper threshold; SELL only
   when it is strictly below the lower threshold.
8. Require a nonnegative current spread no greater than 2,500 points, a valid
   executable quote, completed `ATR(20,D1)`, and a valid normalized stop.
9. Attach a frozen broker hard stop `3.0 * ATR(20,D1)` from executable entry.
   There is no take-profit.
10. Open at most one position for magic `202170000`. No pending order,
    duplicate entry, same-week retry, scale-in, or pyramid is authorized.

## 5. Exit Rules

1. Close on the first following D1 bar before evaluating another entry.
2. Close after two elapsed calendar days as a stale repair if the next-bar
   exit did not execute.
3. Close duplicate, wrong-symbol, or wrong-magic owned composition.
4. Framework Friday close remains enabled at broker hour 21 as a fail-safe.
5. Broker hard stops and the framework kill switch remain authoritative.
6. No fill target, take-profit, reversal exit, trail, break-even, partial
   close, grid, martingale, scale-in, pyramid, or discretionary exit exists.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol, timeframe, ID, slot, risk contract, news
  contract, Friday-close contract, or unlocked strategy input.
- Fail closed outside a genuine Friday-to-Monday boundary, beyond the
  five-minute attachment window, with an invalid attempt state, insufficient
  completed history, nonpositive OHLC, invalid sample variance, zero
  volatility, invalid thresholds, an in-band/equal open, invalid ATR/quote/
  stop, or negative/excess spread.
- Q02 locks news temporal OFF, compliance NONE, and legacy news mode OFF.
- Runtime may not read futures curves, contracts, inventory, WPSR, OPEC, COT,
  volume, open interest, options, CSV, APIs, analyst forecasts, external
  calendars, news text, discretionary inputs, or trained output.

## 7. Trade Management Rules

- One position maximum for magic `202170000` and one consumed attempt per
  genuine Monday.
- Lifecycle exits execute before entry-only gates and retry on every tick of
  the following bar if a close is rejected.
- Terminal-persistent attempt state plus owned deal history prevents restart
  re-entry; future-dated tester state is cleared on initialization.
- The original server-side stop is never moved.
- No hedge, averaging, scale-in, pyramid, grid, martingale, random path,
  adaptive fit, or discretionary override exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 90 | [90] | source return-volatility window |
| `strategy_entry_z` | 0.10 | [0.10] | source prior-extreme volatility multiplier |
| `strategy_session_offset_min` | 61.6 | [61.6] | XTIUSD.DWX tick-measured maximum |
| `strategy_entry_grace_minutes` | 10 | [10] | tight window around the session-tick anchor |
| `strategy_min_stub_ticks` | 20 | [20] | reject thin weekend/holiday D1 stubs |
| `strategy_min_attach_ticks` | 20 | [20] | minimum ticks within 5 minutes of the qualifying tick |
| `strategy_atr_period` | 20 | [20] | completed-bar hard-stop estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 2 | [2] | next-D1 stale repair |
| `strategy_max_spread_points` | 2500 | [2500] | WTI entry spread ceiling |

The 90-return sample, sample-variance denominator, `0.10` multiplier, prior
Friday high/low reference, symmetric continuation direction, genuine Monday
clock, and next-D1 exit are locked.

## Risk and kill criteria

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. `RISK_FIXED` is the stop-normalized loss budget, not a
fixed notional amount.

Retire on zero trades or fewer than five completed packages/year on average;
nonpositive governed economics; a wrong weekday, direction, threshold, or
history window; current-bar leakage; shifted holiday entry; duplicate attempt;
hold beyond the stale guard; missing hard stop; invalid risk mode;
nondeterminism; or later correlation rejection. Do not rescue a failure by
changing the threshold, lookback, weekday, direction, carrier, hold, or exit.

Primary risks are the FSTX/GBPUSD-to-WTI substitution, D1-bar attachment,
weekend news jumps, gap reversal, thin reopen liquidity, WTI tails and rolls,
continuous-CFD basis, slippage, financing, source-sample decay, sparse density,
and overlap with other directional oil systems.

## Strategy Allowability Check

- [x] R1: Tier-A named-author book with exact code and complete governed text,
  plus a peer-reviewed full-text WTI weekend paper with DOI.
- [x] R2: fixed calendar sequence, completed sample, formula, directions,
  attempt state, hard stop, exit, and stale repair.
- [x] R3: registered native `XTIUSD.DWX` D1 route and no external runtime data.
- [x] R4: deterministic OHLC/calendar/variance/ATR arithmetic only; no ML,
  banned indicator, external feed, grid, martingale, scale-in, or pyramid.
- [x] Dedup: deterministic CLEAN plus manual carrier-parent and opposite-WTI-
  gap-family differentiation.

## Framework Alignment

- No-trade: exact host/D1/EA/slot, locked inputs, genuine weekend, attachment,
  attempt, history, variance, threshold, spread, quote, ATR, and state guards.
- Trade entry: one source-direction Monday market order with frozen ATR stop.
- Trade management: first-following-D1 close, stale repair, and composition
  cleanup before entry-only gates.
- Trade close: framework close helper, Friday fail-safe, broker stop, and kill
  switch.

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does not authorize
a manual backtest, live/demo/shadow setfile, AutoTrading, T_Live, a deploy or
T_Live manifest, portfolio admission, portfolio-gate change, portfolio KPI,
correlation waiver, or downstream promotion.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-05 | initial WTI weekend opening-gap momentum card | G0 | APPROVED; build pending |
| v2 | 2026-08-05 | initial framework implementation | Q01 | PASS; strict compile and build checks |
| v3 | 2026-08-05 | paced baseline handoff | Q02 | ENQUEUED; screening pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-05 | APPROVED; R1-R4 PASS | this card, governed source packet, and durable decision |
| Q01 Build Validation | 2026-08-05 | PASS; 0 compile errors/warnings and 0 build failures/warnings | D:/QM/reports/framework/21/build_check_20260805_000513.json |
| Q02 Baseline Screening | 2026-08-05 | ENQUEUED; no screening verdict claimed | work item 4eaf26f4-d7e7-4915-9e3f-9f0c4213d157 |

## OWNER-approved session-tick entry-clock amendment (2026-08-16)

This amendment supersedes every earlier raw-D1-label/five-minute entry-clock
description in this card. No formation, signal, direction, exit, sizing,
risk, consumed-attempt, or original advance/never-shift mechanic changes.

- Anchor the qualifying window at
  `D1_bar_open + strategy_session_offset_min`, not the raw D1 label.
- `strategy_session_offset_min = 61.6` minutes: conservative tick-measured maximum for `XTIUSD.DWX`.
- `strategy_entry_grace_minutes = 10`, measured tightly around that anchor.
- `strategy_min_stub_ticks = 20`; a thin weekend/holiday D1 stub consumes
  the card's original attempt/date/window flat.
- `strategy_min_attach_ticks = 20` within five minutes after the qualifying
  tick; failure consumes the original attempt/date/window flat.
- Preserve this card's existing advance-versus-never-shift semantics exactly.
