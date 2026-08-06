---
card_schema_version: 2
type: strategy
strategy_id: BURAKOV-BIANCHI-WTI-SEAS52W-2026_S01
variant_id: BURAKOV-BIANCHI-WTI-SEAS52W-2026_S01
source_id: BURAKOV-BIANCHI-WTI-SEAS52W-2026
ea_id: QM5_20241
slug: wti-seas-anchor
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20241_wti-seas-anchor_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
g0_status: APPROVED
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Robert J. Bianchi; Michael E. Drew; Jian Hua Fan"
source_citation: "Burakov, Freidin, and Solovyev (2018), The Halloween Effect on Energy Markets; Bianchi, Drew, and Fan (2016), Commodities momentum: A behavioural perspective."
source_citations:
  - type: peer_reviewed_paper
    citation: "Burakov, D., Freidin, M., and Solovyev, Y. (2018). The Halloween Effect on Energy Markets: An Empirical Study. International Journal of Energy Economics and Policy 8(2), 121-126."
    location: "Complete official six-page paper; methods alternative two and WTI Tables 2-3; governed packet strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md"
    quality_tier: B
    role: primary_physical_season_direction
  - type: peer_reviewed_paper
    citation: "Bianchi, R. J., Drew, M. E., and Fan, J. H. (2016). Commodities momentum: A behavioural perspective. Journal of Banking & Finance."
    location: "DOI https://doi.org/10.1016/j.jbankfin.2016.06.010; governed packet strategy-seeds/sources/BIANCHI-COMM-52W-2016/source.md"
    quality_tier: A
    role: primary_52_week_anchor
strategy_mechanic: monthly-wti-physical-season-and-52-week-closing-anchor-concordance
sources:
  - "[[sources/BURAKOV-WTI-HALLOWEEN-2018]]"
  - "[[sources/BIANCHI-COMM-52W-2016]]"
concepts:
  - "[[concepts/energy-seasonality]]"
  - "[[concepts/52-week-high-anchor]]"
indicators:
  - "[[indicators/rolling-high-low]]"
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, seasonality, anchor-momentum, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202410000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated 5-7 completed monthly WTI packages/year after 252 completed D1 bars; Q02 must prove or retire density."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_STARTED
review_focus: "Falsify a direct WTI season/anchor agreement package. It is neither the unconditional physical-season sleeve nor the year-round 52-week anchor parent. Q09 alone may establish realized decorrelation from XAU/SP500/NDX/XNG."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_d1_anchor_window, physical_season_direction, quarterly_confirmation, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-06_qm5_20241_wti_seas_anchor_g0.md: R1 two governed peer-reviewed source lineages with complete-read records; R2 locked two-season map, 252-D1 closing-extreme location, 63-D1 return threshold, strict agreement, persisted monthly attempt, ATR stop, monthly rollover, and stale exit; R3 registered XTIUSD.DWX D1 history; R4 deterministic native price arithmetic only. Deterministic dedup scanned 4,298 registry rows and 415 canonical cards with CLEAN exact/fuzzy result; manual mechanic review is clean. The concordance is a QM hypothesis and no source efficacy transfers."
---

# QM5_20241 WTI Seasonal 52-Week Anchor

## Hypothesis

WTI's physical demand, storage, and refinery cycle can create a persistent
November-May positive state and June-October negative state, while commodity
investors can anchor expectations to recent annual price extremes. Requiring
those two independent structural states to agree may isolate a lower-overlap
crude-oil sleeve: winter longs only near the annual closing high with positive
quarterly confirmation, and summer shorts only near the annual closing low
with negative quarterly confirmation.

This is direct crude-oil exposure, not a claim of portfolio decorrelation or
efficacy. Q02 owns frequency and economics; unchanged Q09 alone may measure
realized overlap after survival.

## Source Traceability And Claim Boundary

The governed packet is
`strategy-seeds/sources/BURAKOV-BIANCHI-WTI-SEAS52W-2026/source.md`.
Burakov, Freidin, and Solovyev supply the WTI physical-season direction.
Bianchi, Drew, and Fan supply the commodity 52-week anchor lineage; the
governed WTI parent translates it to completed D1 closing-extreme proximity
plus a 63-D1 same-direction return.

Neither paper tests this agreement rule, the Darwinex continuous CFD, fixed
dollar risk, ATR stop, spread cap, restart ledger, costs, financing, or the QM
portfolio. No source performance or correlation statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,298 EA-registry rows and 415 cards and
returned `CLEAN`, with no exact identity or fuzzy match above threshold.
Manual review resolves the nearest systems:

- `QM5_12780_wti-52w-anchor` applies the anchor every month and has no
  physical-season agreement state.
- `QM5_20046_wti-halloween-ls` maps season directly to direction and has no
  price-location or 63-D1 confirmation state.
- `QM5_20135_wti-winter-trend` can buy or sell in November-May from a raw
  252-D1 return sign. This card never shorts winter and also expresses the
  June-October short state, conditional on annual-extreme proximity and a
  separate 63-D1 threshold.
- `QM5_20141_wti-sumtrend` is a weekly July-November short keyed to raw
  252-D1 return and Friday exit, not this monthly two-season anchor rule.
- `QM5_20231_wti-seas-mom12` uses one cumulative twelve-calendar-month
  return, not annual closing-extreme location plus a quarterly threshold.
- `QM5_20222_wti-seas-sign` counts monthly signs and has no price anchor.
- `QM5_12567_cum-rsi2-commodity` is an XNG two-day oscillator pullback.

The two-season map, closing-extreme location, separate 63-D1 return threshold,
agreement-only entry, disagreement-flat state, and monthly lifecycle are
jointly load-bearing. Verdict:
`CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot: 0; allocated magic `202410000`.
- Decision clock: first processed D1 bar of each broker-month transition.
- Formation: 252 completed D1 closes for the high/low anchor and an exact
  completed 63-D1 log return ending at the newest close.
- Expected cadence: 5-7 completed packages/year after warm-up; retire below
  five per full post-warm-up year.
- Runtime data: native MT5 D1 rates, framework ATR, spread, executable quotes,
  positions, deals, broker calendar, and contract metadata only.

## Formula

At the start of broker month `t`, let `C0` be the newest completed D1 close,
`H252`/`L252` the maximum/minimum across the newest 252 completed D1 closes,
and `C63` the completed close exactly 63 D1 intervals before `C0`:

```text
location_high = C0 / H252
location_low  = C0 / L252
confirm_63    = ln(C0 / C63)
```

- Current month November-May, `location_high >= 0.94`, and
  `confirm_63 >= +0.02`: BUY WTI.
- Current month June-October, `location_low <= 1.08`, and
  `confirm_63 <= -0.02`: SELL WTI.
- Equality outside those inclusive thresholds, invalid history, or
  disagreement remains flat for the consumed month.

## Rules

The rules below are the complete authorized Q02 baseline. Every signal
parameter is locked; no direction, threshold, horizon, season, carrier, or
retry sweep is authorized.

## 4. Entry Rules

1. Require exact EA ID `20241`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, stop, sizing, or order gates. A flat, rejected, failed,
   stopped, or blocked attempt cannot retry during that month.
4. Reject an owned position or any same-month entry deal for the magic.
5. Load exactly 252 completed D1 closes, require valid positive prices, and
   calculate the trailing closing high/low including the newest close.
6. Calculate `ln(C0/C63)` from the same synchronized completed-bar array.
7. BUY only in November-May when `C0/H252 >= 0.94` and return `>= +0.02`.
8. SELL only in June-October when `C0/L252 <= 1.08` and return `<= -0.02`.
9. Require spread in `[0,1500]` points, valid quote, completed ATR(20,D1),
   valid stop geometry, and V5 fixed-risk sizing.
10. Open at most one market position with a frozen `3.5 * ATR(20,D1)` hard
    stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement risk.
2. Close after forty elapsed calendar days as a stale guard.
3. Close any wrong-symbol position owned by this magic immediately.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the monthly source hold spans weekends.
6. No intramonth signal reversal, target, trail, break-even, partial close,
   scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol, timeframe, EA ID, slot, unlocked input,
  invalid month key, non-boundary bar, consumed attempt, owned exposure,
  same-month entry history, missing or nonpositive close, invalid extrema or
  logarithm, season/anchor disagreement, excessive spread, invalid quote,
  unavailable ATR, or invalid stop.
- Both news axes are locked OFF for the native-price baseline. Lifecycle exits
  are processed before entry-only gates.
- Runtime may not read a futures curve, inventory release, volume, open
  interest, external file, API, analyst input, trained output, or portfolio
  result.

## 7. Trade Management Rules

- Preserve the original broker stop; do not move it.
- Close older-month, wrong-symbol, or forty-day-stale exposure before
  evaluating a new entry.
- Maintain at most one position and one consumed attempt per broker month.
  Restart recovery combines a persistent marker with position and deal
  history; a future-dated tester marker is deleted at initialization.
- No randomness, adaptive fit, external state, grid, martingale, partial
  close, scale-in, or pyramiding.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_winter_first_month` | 11 | [11] | positive physical-season start |
| `strategy_winter_last_month` | 5 | [5] | positive physical-season end |
| `strategy_anchor_lookback_d1` | 252 | [252] | completed closing-extreme window |
| `strategy_confirm_lookback_d1` | 63 | [63] | completed return confirmation |
| `strategy_anchor_long_min` | 0.94 | [0.94] | minimum high proximity for winter long |
| `strategy_anchor_short_max` | 1.08 | [1.08] | maximum low distance for summer short |
| `strategy_confirm_min_return_pct` | 2.0 | [2.0] | absolute 63-D1 log-return threshold |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

## Author Claims

The energy source reports a stronger historical November-May WTI leg in its
1985-2016 IMF sample. The commodity source provides behavioural 52-week-anchor
lineage. Neither claims that their conjunction works on `XTIUSD.DWX`, that the
declared thresholds generate five trades/year, or that this candidate
diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, rolls, financing, and sharp
reversals can dominate a slow monthly signal; annual anchors can fail during
regime changes; the agreement gate can collapse density; and direct crude
exposure may correlate with the incumbent book.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full
  post-warm-up year.
- Fail on a wrong season, wrong anchor window, wrong 63-D1 interval,
  wrong-side entry, repeat monthly attempt, hold beyond forty days, missing
  hard stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing months, direction, thresholds, horizons,
  carrier, stop, hold, spread cap, or retry policy.

## Strategy Allowability Check

- [x] R1: two named-author peer-reviewed sources with durable complete-read
  records and reproducible citations.
- [x] R2: fixed season, completed D1 anchor, return threshold, persisted
  attempt, hard stop, rollover, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 and native V5 execution state only.
- [x] R4: deterministic logarithm/extreme/calendar/ATR arithmetic; no
  prohibited trained model, banned indicator, external feed, grid, or
  martingale.
- [x] Dedup: deterministic CLEAN plus manual neighbor resolution.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked inputs, news/Friday contract, and
  cheap parameter guards.
- trade_entry: monthly attempt persistence, bounded completed-rate load,
  season/anchor agreement, spread/quote/ATR/stop checks, and one market order.
- trade_management: older-month, wrong-symbol, and stale exits before
  entry-only gates.
- trade_close: broker hard stop, framework kill switch, and deterministic
  management closes.

## Safety Boundary

This card authorizes only research, build, strict compile, and non-live paced
pipeline handoff. It does not authorize a manual backtest; live, demo, shadow,
optimization, or stress setfile; AutoTrading; `T_Live`; deploy or T_Live
manifest; portfolio admission; portfolio-gate edit; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-06 | initial source-bounded WTI season/anchor card and strict build | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20241_wti_seas_anchor_g0.md` |
| Q01 Build Validation | 2026-08-06 | PASS | strict compile/build: 0 errors, warnings, failures, or build warnings |
| Q02 Baseline Screening | - | NOT_STARTED | - |
