---
card_schema_version: 2
ea_id: QM5_20230
slug: wti-seas-gap
type: strategy
strategy_id: BURAKOV-CHAN-WTI-SEASGAP-2026_S01
variant_id: BURAKOV-CHAN-WTI-SEASGAP-2026_S01
source_id: BURAKOV-CHAN-WTI-SEASGAP-2026
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20230_wti-seas-gap_card.md
execution_contract_status: DRAFT
created: 2026-08-05
created_by: Research+Development
last_updated: 2026-08-16
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Ernest P. Chan; Seth A. Hoelscher; Cedric Mbanga; Walt A. Nelson"
strategy_mechanic: genuine-monday-wti-prior-friday-range-volatility-breakaway-continuation-only-in-fixed-physical-season-direction
source_citation: "Burakov, Freidin, and Solovyev (2018), International Journal of Energy Economics and Policy 8(2), 121-126; Chan (2013), Algorithmic Trading, Wiley, Chapter 7 Example 7.1; Hoelscher, Mbanga, and Nelson (2017), Journal of Finance Issues 16(1), 47-68."
source_citations:
  - type: peer_reviewed_open_access_paper
    citation: "Burakov, D., Freidin, M., and Solovyev, Y. (2018). The Halloween Effect on Energy Markets: An Empirical Study. International Journal of Energy Economics and Policy 8(2), 121-126."
    location: "Methods alternative two and WTI Tables 2-3; complete governed review strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md"
    quality_tier: B
    role: fixed_physical_season_direction
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading."
    location: "Chapter 7, Example 7.1, printed pp. 156-157; bounded complete-read review strategy-seeds/sources/CHAN-TGIF-WTI-WKENDMOM-2026/source.md"
    quality_tier: A
    role: opening_gap_momentum_mechanic
  - type: peer_reviewed_paper
    citation: "Hoelscher, S. A., Mbanga, C., and Nelson, W. A. (2017). TGIF? The Weekend Effect in Energy Commodities. Journal of Finance Issues 16(1), 47-68."
    location: "DOI 10.58886/jfi.v16i1.2264; complete official-paper review strategy-seeds/sources/TGIF-WTI-WEEKEND-2017/source.md"
    quality_tier: B
    role: wti_weekend_target_market
sources:
  - "[[sources/BURAKOV-CHAN-WTI-SEASGAP-2026]]"
concepts:
  - "[[concepts/wti-seasonal-direction]]"
  - "[[concepts/opening-gap-momentum]]"
  - "[[concepts/crude-oil-weekend-effect]]"
indicators:
  - "[[indicators/lagged-return-volatility]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, opening-gap-momentum, weekend-effect, agreement-filter, next-bar-exit, atr-hard-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202300000
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 4-10 genuine-Monday, season-agreeing WTI breakaway-gap packages/year after warm-up; Q02 must prove at least five/year on average or retire."
expected_trades_per_year_per_symbol: 7
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
q02_status: NOT_STARTED
review_focus: "Falsify whether fixed WTI physical-season direction filters genuine weekend breakaway continuation into a sparse direct-crude clock absent from the certified XAU/SP500/NDX/XNG book; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode, source_carrier_substitution, fixed_season_map, genuine_weekend_sequence, completed_history_only, restart_safe_attempt, next_d1_exit, friday_close, q02_frequency_floor, cfd_futures_basis, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER 2026-08-05 commodity/energy sleeve mission: R1 complete peer-reviewed WTI physical-season and weekend records plus Tier-A executable opening-gap lineage; R2 locked season map, genuine Monday sequence, lagged 90-return volatility, source 0.10 threshold, agreement-only direction, attempt state, hard stop, spread cap, and next-D1 exit; R3 registered native XTIUSD.DWX D1 route; R4 deterministic native arithmetic only. No exact identity across 4,287 registry rows and 403 cards; three expected wti-seas-* fuzzy matches and the all-season gap parent are manually resolved by information object, decision clock, direction gate, and lifecycle."
---

# QM5_20230 WTI Physical-Season / Weekend Breakaway Gap

## Hypothesis

WTI's November-May versus June-October return asymmetry reflects recurring
heating demand, refinery transitions, inventory cycles, driving-season flows,
producer hedging, and weather risk. Weekend closures can concentrate new
information and stop orders at the reopen. A Monday breakaway gap may be more
likely to continue when its direction agrees with the fixed WTI physical
season than when it fights that slow calendar prior.

This is a direct-crude, once-per-week decision clock unlike the certified
XAU, SP500, NDX, and XNG carriers. It is a falsifiable interaction, not a
profitability, significance, decorrelation, certification, or portfolio-
admission claim.

## Source Traceability And Claim Boundary

The approved composite packet is
`strategy-seeds/sources/BURAKOV-CHAN-WTI-SEASGAP-2026/source.md`.

Burakov, Freidin, and Solovyev supply the fixed positive November-May and
negative June-October WTI directions. Chan supplies the exact opening-gap
continuation direction, prior-session high/low reference, `0.10` multiplier,
lagged 90-session close-to-close volatility, and same-session exit. His tested
carriers are FSTX and GBPUSD, not WTI. Hoelscher, Mbanga, and Nelson document
a WTI weekend/Monday return clock but do not test the threshold or the
physical-season interaction.

The WTI carrier, genuine Friday-to-Monday restriction, D1 first-tick
attachment, season gate, ATR stop, fixed cash risk, spread ceiling, and next-
D1 exit are QM translations. No source return, Sharpe ratio, profit factor,
drawdown, trade count, CFD basis, or portfolio-correlation estimate is
imported.

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

- November-May and `MondayOpen > upper`: BUY WTI.
- June-October and `MondayOpen < lower`: SELL WTI.
- A gap opposing the season, an in-band/equal open, invalid arithmetic,
  nonpositive OHLC, zero volatility, or unordered thresholds remains flat for
  the consumed Monday.

The current Monday open is known at attachment. Every high, low, close, and
return used by the threshold is completed. There is no intrabar
recomputation, moving average, oscillator, regression, trained output, or
external input.

## Non-Duplicate Decision

The canonical checker found no exact slug or strategy-ID identity and
returned three expected fuzzy `wti-seas-*` family matches. Manual review fixes
the material boundaries:

- `QM5_20217_wti-wkend-mom` is the all-season source parent. It buys upside
  and sells downside threshold gaps in every month. This candidate rejects
  every gap whose direction disagrees with the separately sourced fixed
  physical-season map. The map is a load-bearing information object frozen
  before testing, not a threshold tune or post-result rescue.
- `QM5_20226_wti-seas-dow` trades signed ordinary weekday sessions from
  completed prior-day sequences; it does not require a Friday-to-Monday gap,
  a prior-range break, or lagged 90-return volatility.
- `QM5_20227_wti-seas-mom1` and `QM5_20229_wti-seas-rev1` decide only at
  broker-month boundaries from completed month-end returns and hold month to
  month. This candidate decides at genuine Monday reopens and exits at the
  next D1 boundary.
- `QM5_20046_wti-halloween-ls` takes unconditional month-long seasonal
  exposure and reads no weekend-gap state.
- `QM5_12750` and `QM5_12779` fade WTI gaps toward Friday's close. This
  candidate follows only a season-agreeing break beyond Friday's full range.
- `QM5_12567` is a two-day commodity oscillator pullback, not a physical-
  season or weekend breakaway system.

The WTI carrier, fixed season map, genuine weekend sequence, prior-range
break, lagged-volatility buffer, agreement-only continuation direction, and
one-session lifecycle are jointly load-bearing.

## Markets, Timeframe, And Cadence

- Carrier: exact `XTIUSD.DWX`, D1, slot 0, magic `202300000`.
- Decision: first observed tick within five minutes of a broker-calendar
  Monday D1 bar immediately following a completed Friday D1 bar.
- Winter map: November-May, BUY threshold gaps only.
- Summer map: June-October, SELL threshold gaps only.
- Maximum cadence: one consumed decision per genuine Monday.
- Planning cadence: approximately 4-10 completed packages/year after warm-up;
  retire below five/year on average.
- Ordinary hold: Monday open to the first following D1 boundary.

## Rules

The entry, exit, filter, and management rules below are the complete baseline.
No baseline sweep, neighboring-session substitution, unconditional gap
fallback, or post-result rescue is authorized.

## 4. Entry Rules

1. Require exact `XTIUSD.DWX`, D1, EA ID `20230`, magic slot 0, and every
   frozen baseline input.
2. Evaluate only on a current broker-calendar Monday whose immediately prior
   completed D1 bar is Friday. Missing Monday sessions never shift to Tuesday.
3. Require the first observed tick within five minutes of the Monday D1 bar
   open. A late initialization consumes the missed Monday and remains flat.
4. Persist the Monday `YYYYMMDD` attempt before history, signal, season,
   spread, quote, news, stop, sizing, or order gates. No rejection or restart
   can retry that date.
5. Reject when an owned position or owned entry deal already exists for the
   current Monday.
6. Load exactly 91 completed D1 closes and compute the 90 arithmetic returns,
   sample standard deviation, and thresholds defined above.
7. Map the current broker month to BUY for November-May and SELL for June-
   October. Continue only when the strict threshold-cross direction agrees
   with that map. Every opposing or flat state remains flat.
8. Require a nonnegative spread no greater than 2,500 points, a valid
   executable quote, completed `ATR(20,D1)`, and a valid normalized stop.
9. Attach a frozen broker hard stop `3.0 * ATR(20,D1)` from executable entry.
   There is no take-profit.
10. Open at most one position for magic `202300000`. No pending order,
    duplicate entry, same-week retry, scale-in, or pyramid is authorized.

## 5. Exit Rules

1. Close on the first following D1 bar before evaluating another entry.
2. Close after two elapsed calendar days as a stale repair if the next-bar
   exit did not execute.
3. Close duplicate composition or a direction that disagrees with the fixed
   season at the package's Monday open.
4. Framework Friday close remains enabled at broker hour 21 as a fail-safe.
5. Broker hard stops and the framework kill switch remain authoritative.
6. No fill target, take-profit, reversal exit, trail, break-even, partial
   close, grid, martingale, scale-in, pyramid, or discretionary exit exists.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol, timeframe, ID, slot, risk contract, news
  contract, Friday-close contract, season-map input, or other unlocked
  strategy input.
- Fail closed outside a genuine Friday-to-Monday boundary, beyond the five-
  minute attachment window, with invalid attempt state, insufficient
  completed history, nonpositive OHLC, invalid sample variance, zero
  volatility, invalid thresholds, an in-band or season-opposing open, invalid
  ATR/quote/stop, or negative/excess spread.
- Q02 locks news temporal OFF, compliance NONE, and legacy news mode OFF.
- Runtime may not read futures curves, inventory, WPSR, OPEC, COT, volume,
  open interest, options, CSV, APIs, analyst forecasts, external calendars,
  news text, discretionary inputs, or trained output.

## 7. Trade Management Rules

- One position maximum for magic `202300000` and one consumed attempt per
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
| `strategy_winter_first_month` | 11 | [11] | seasonal BUY interval start |
| `strategy_winter_last_month` | 5 | [5] | seasonal BUY interval end |
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

The fixed season partition, 90-return sample, sample-variance denominator,
`0.10` multiplier, Friday high/low reference, agreement-only direction,
genuine Monday clock, and next-D1 exit are locked. Changing any one requires a
new card and full pipeline run.

## Risk And Kill Criteria

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. `RISK_FIXED` is a stop-normalized loss budget, not fixed
notional exposure. No live-risk mode is authorized.

Retire on zero trades or fewer than five completed packages/year on average;
nonpositive governed economics; a wrong month, weekday, direction, threshold,
or history window; current-bar leakage beyond the known Monday open; shifted
holiday entry; duplicate attempt; hold beyond the stale guard; missing hard
stop; invalid risk mode; nondeterminism; or later correlation rejection. Do
not rescue a failure by changing the threshold, lookback, season map,
weekday, direction, carrier, hold, or exit.

Primary risks are the FSTX/GBPUSD-to-WTI substitution, untested source
interaction, D1-bar attachment, filter-induced under-frequency, weekend news
jumps, gap reversal, thin reopen liquidity, WTI tails and rolls, continuous-
CFD basis, slippage, financing, source-sample decay, and overlap with other
directional oil systems.

## Strategy Allowability Check

- [x] R1 reputable: peer-reviewed open WTI seasonality, Tier-A executable
  opening-gap logic, and peer-reviewed WTI weekend evidence with durable
  complete-read repository records.
- [x] R2 mechanical: fixed season map, calendar sequence, completed sample,
  formula, agreement direction, attempt state, hard stop, exit, and stale
  repair.
- [x] R3 testable: registered native `XTIUSD.DWX` D1 route and no external
  runtime data.
- [x] R4 compliant: deterministic OHLC/calendar/variance/ATR arithmetic only;
  no ML, banned indicator, external feed, grid, martingale, scale-in, or
  pyramid.
- [x] Dedup: no exact identity; all-season gap parent, three fuzzy seasonal
  siblings, gap-fill systems, and oscillator neighbor are manually resolved.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, fixed-risk/news/Friday contracts, locked
  season inputs, genuine weekend, attachment, attempt, history, variance,
  threshold, agreement direction, spread, quote, ATR, and state guards.
- trade_entry: one season-agreeing Monday market order with frozen ATR stop.
- trade_management: first-following-D1 close, wrong-direction cleanup, stale
  repair, and composition cleanup before entry-only gates.
- trade_close: framework close helper, Friday fail-safe, broker stop, and kill
  switch.

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does not authorize
a manual backtest; live, demo, or shadow setfile; AutoTrading; `T_Live`; a
deploy or T_Live manifest; portfolio admission; portfolio-gate change;
portfolio KPI edit; correlation waiver; or downstream promotion.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-05 | initial WTI physical-season / weekend breakaway interaction | G0 | APPROVED; build pending |
| v2 | 2026-08-05 | initial V5 framework implementation | Q01 | PASS; strict compile and build checks |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-05 | APPROVED; R1-R4 PASS | `decisions/2026-08-05_qm5_20230_wti_seas_gap_g0.md` |
| Q01 Compile / Static Validation | 2026-08-05 | PASS | `framework/build/compile/20260805_193626/QM5_20230_wti-seas-gap.compile.log`; `D:/QM/reports/framework/21/build_check_20260805_193626.json`; `D:/QM/reports/pipeline/QM5_20230/P1/P1_QM5_20230_result.json` |
| Q02 Baseline Screening | - | NOT_STARTED | - |

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
