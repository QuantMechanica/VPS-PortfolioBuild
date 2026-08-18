---
card_schema_version: 2
type: strategy
strategy_id: CRABEL-CME-XAUXAG-WEEKNR7-2026_S01
variant_id: CRABEL-CME-XAUXAG-WEEKNR7-2026_S01
source_id: CRABEL-CME-XAUXAG-WEEKNR7-2026
ea_id: QM5_41060
slug: xauxag-week-nr7-brk
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41060_xauxag-week-nr7-brk_card.md
execution_contract_status: DRAFT
created: 2026-08-18
created_by: Research+Development
last_updated: 2026-08-18
g0_status: APPROVED
source_authors: "Toby Crabel; CME Group"
source_citation: "Crabel, Toby (1990), Day Trading with Short-Term Price Patterns and Opening Range Breakout, Traders Press; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: trading_book
    citation: "Crabel, Toby (1990). Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press."
    location: "Governed packets strategy-seeds/sources/CRABEL-WTI-NR7-BRK-2026/source.md and strategy-seeds/sources/CRABEL-WTI-WEEK-ORB-2026/source.md"
    quality_tier: B
    role: primary_nr7_range_compression_and_weekly_breakout_lineage
  - type: exchange_education
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade; governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A
    role: primary_gold_silver_relative_value_carrier
strategy_mechanic: synchronized-d1-gold-silver-close-ratio-complete-week-nr7-next-week-fresh-close-breakout-equal-notional-basket
sources:
  - "[[sources/CRABEL-CME-XAUXAG-WEEKNR7-2026]]"
  - "[[sources/CRABEL-WTI-NR7-BRK-2026]]"
  - "[[sources/CRABEL-WTI-WEEK-ORB-2026]]"
  - "[[sources/CME-GSR-SPREAD-2025]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/weekly-range-compression]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/nr7-range]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, weekly-compression, breakout-continuation, atr-hard-stop, friday-flat, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41060_XAU_XAG_WEEKNR7_D1
symbol: QM5_41060_XAU_XAG_WEEKNR7_D1
host_symbol: XAUUSD.DWX
symbol_slots:
  XAUUSD.DWX: 0
  XAGUSD.DWX: 1
magics:
  XAUUSD.DWX: 410600000
  XAGUSD.DWX: 410600001
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-10 completed paired packages per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_ENQUEUED
review_focus: "Falsify a weekly two-leg precious-metals volatility-expansion stream whose strict NR7 event, fresh next-week cross, equal-notional opposing legs, and Friday-flat clock differ from directional XAU and the certified QM5_12567 XNG oscillator; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [synchronized_completed_bars, complete_week_membership, strict_nr7, fresh_cross_only, durable_week_attempt, basket_atomicity, equal_notional_tolerance, aggregate_fixed_risk, orphan_repair, friday_flat, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-18_qm5_41060_xauxag_weekly_nr7_breakout_g0.md: R1 named-author/publisher NR7 book lineage plus CME exchange ratio carrier with the untested port disclosed; R2 locked synchronized close ratios, complete-week selection, strict seven-week compression, fresh next-week cross, one weekly attempt, opposing equal-notional legs, aggregate fixed risk, ATR stops, spread caps, and Friday exit; R3 registered XAU/XAG D1 symbols and magics; R4 deterministic native arithmetic only. Canonical dedup was CLEAN across 4,547 registry rows and 625 root cards; manual family review distinguished continuous channel, failed-break fade, monthly variance-ratio, and weekly flow systems. No source efficacy, neutrality, or decorrelation transfers."
---

# QM5_41060 XAU/XAG Weekly NR7 Ratio Breakout

## Hypothesis

Gold and silver share a precious-metals component but differ in monetary,
safe-haven, and industrial sensitivity. When their synchronized D1 close ratio
forms the narrowest complete weekly range in seven observations, a fresh
next-week ratio close outside that compressed range may mark a relative
volatility expansion. Following that expansion with opposing gold and silver
legs targets a relative-value return stream rather than another outright XAU
position.

Equal absolute entry notionals and opposite directions are structural controls,
not proof of dollar, beta, volatility, factor, or portfolio neutrality. Q02
owns density and economics. Unchanged downstream gates own robustness, and Q09
alone may measure realized overlap with the certified XAU/SP500/NDX/XNG book.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/CRABEL-CME-XAUXAG-WEEKNR7-2026/source.md`. Its governed
parents are the named Crabel/Traders Press NR7 and weekly range packets plus CME
Group's gold/silver ratio packet. All four bounded packets were read completely
before the durable source approval at
`decisions/2026-08-18_xauxag_weekly_nr7_breakout_source_approval.md`.

Crabel supplies only the volatility-contraction/range-expansion lineage. CME
supplies only the ratio definition, two-leg carrier, and differing metal
drivers. Neither source tests this exact complete-week ratio sample, next-week
fresh cross, continuous DWX CFDs, equal-notional fixed-risk package, or V5
lifecycle. No reported return, trade count, drawdown, hedge ratio, CFD basis,
neutrality, or portfolio statistic is imported.

## Non-Duplicate Decision

The canonical pre-allocation checker returned `CLEAN` across 4,547 registry
rows and 625 root cards for the slug, strategy ID, and complete mechanic.
Manual semantic review resolved the expected family neighbors:

- `QM5_12724_cme-xauxag-brk` follows every 120-D1 ratio-channel break and
  exits on a 40-D1 opposite channel. This candidate requires a strict complete-
  week NR7 event, accepts only a fresh cross in the immediately following
  week, and is Friday-flat.
- `QM5_20265_xauxag-fail-rv` fades a separate outside-then-inside 60-D1 event.
  This candidate follows an inside-to-outside close cross.
- `QM5_20249_xauxag-vr-spread` uses a monthly robust variance-ratio statistic
  and memory-direction matrix. This candidate has no autocorrelation or
  significance statistic.
- `QM5_41040` and `QM5_41057` decompose prior-week overnight and session
  relative returns and fade them. This candidate ignores flow decomposition
  and follows next-week expansion.
- `QM5_12533` is an EURJPY/GBPJPY cointegration EA. Only its validated basket
  manifest/order pattern is reused.

The synchronized close ratio, complete five-session weeks, strict NR7 state,
fresh next-week cross, continuation side, one weekly attempt, equal-notional
aggregate-risk package, and Friday-flat lifecycle are jointly load-bearing.
Verdict: `CLEAN_WEEKLY_RATIO_NR7_EXPANSION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_41060_XAU_XAG_WEEKNR7_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1, magic `410600000`.
- Companion/traded slot 1: `XAGUSD.DWX`, D1, magic `410600001`.
- Decision clock: first 180 minutes of each new synchronized host D1 bar from
  broker Tuesday through Friday.
- Formation: the immediately prior complete Monday-Friday week plus the six
  next-most-recent valid complete weeks.
- Expected cadence: five to ten completed packages per full post-warm-up year;
  retire below five.
- Runtime: native MT5 D1 time/close, ATR, spreads, quotes, positions, deals,
  broker calendar, contract metadata, and terminal-persistent attempt state.

## Formula

For a synchronized completed D1 timestamp `d`, define:

```text
r[d] = ln(XAUUSD.DWX_close[d]) - ln(XAGUSD.DWX_close[d])
```

A valid complete broker week contains exactly one synchronized observation for
each weekday Monday through Friday. For complete week `w`:

```text
week_low[w]   = min(r[d] for d in w)
week_high[w]  = max(r[d] for d in w)
week_range[w] = week_high[w] - week_low[w]
```

Let `w0` be the immediately prior calendar week and `w1..w6` the six next-
most-recent valid complete weeks. Older incomplete holiday weeks may be skipped;
`w0` may not. The compression state is:

```text
week_range[w0] > 0
and week_range[w0] < week_range[wi] for every i = 1..6
```

Let `r_prev` and `r_latest` be the two newest synchronized completed ratios,
where `r_latest` belongs to the current broker week. A fresh breakout is:

```text
inside_prev = week_low[w0] <= r_prev <= week_high[w0]
upper       = inside_prev and r_latest > week_high[w0]
lower       = inside_prev and r_latest < week_low[w0]
```

Equality at the outer boundary remains flat. `upper` buys XAU and sells XAG;
`lower` sells XAU and buys XAG. The two events are mutually exclusive.

## Rules

The rules below are the complete authorized Q02 baseline. There is no
parameter, side, calendar, carrier, or retry sweep.

## 4. Entry Rules

1. Require exact EA ID `41060`, `XAUUSD.DWX` D1 host, magic slot zero,
   registered `XAGUSD.DWX` slot one, and every baseline input locked to its
   declared value.
2. Process lifecycle repair and exits before entry-only gates. Evaluate only
   on a new synchronized D1 bar from Tuesday through Friday and within 180
   minutes of the host bar open.
3. Reject owned exposure or an entry deal/attempt for the current broker Monday
   week key.
4. Load enough synchronized completed D1 closes to collect seven valid complete
   weeks. Require exact timestamp equality, positive finite prices, exactly one
   observation for weekday one through five, and no duplicate weekday.
5. Require the newest collected complete week to be exactly the immediately
   prior broker calendar week. Older incomplete weeks may be skipped without
   substitution beyond the fixed history buffer.
6. Compute the seven five-close ratio ranges and require the prior week's
   positive finite range to be strictly smaller than all six older ranges.
7. Require the latest completed ratio to belong to the current week and the
   preceding completed ratio to lie inside the prior compressed range. Enter
   only on a strict fresh cross beyond that range.
8. Once a fresh cross exists, persist the current Monday week key before
   spread, quote, ATR, sizing, news, or order gates. A rejected or failed
   attempt cannot retry during the same week.
9. Require both spreads in `[0,1500]` points, executable quotes, completed
   `ATR(20,D1)`, valid stop geometry, contract/tick metadata, and valid lot
   steps.
10. Target one-to-one absolute entry notionals with at most 20 percent mismatch
    after lot rounding. Attach one frozen `3.0*ATR(20,D1)` hard stop per leg
    and constrain combined normalized stop risk to at most one
    `RISK_FIXED=1000` package. There is no take profit.
11. Open XAU then XAG. Keep the package only if exactly one correctly directed
    position exists in each registered slot and the notional tolerance holds.
    On order or validation failure, flatten every owned leg immediately.

## 5. Exit Rules

1. Close both legs at broker Friday 21 before any new entry.
2. Close both legs on the first observed bar/tick belonging to a broker week
   later than the entry week.
3. Close both legs after eight elapsed calendar days as a stale guard.
4. Immediately flatten an orphan, duplicate, same-direction, wrong-side,
   wrong-symbol, wrong-magic, missing-stop, or notional-invalid package.
5. Broker hard stops, framework kill switch, and framework Friday close remain
   authoritative.
6. No target, intrabar signal flip, trail, break-even, partial close, scale-in,
   grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact host, timeframe, EA ID, magic slot, fixed-risk,
  news/Friday contract, or locked strategy inputs.
- Reject owned exposure, consumed week, late bar, unsynchronized history,
  incomplete immediate prior week, fewer than seven valid weeks, nonpositive
  price, invalid logarithm, nonpositive range, non-strict NR7 state, stale
  cross, equality, excessive spread, invalid quote, unavailable ATR, invalid
  stop, invalid metadata, or invalid rounded package.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle repair
  and exits run before entry-only gates.
- Runtime may not read futures curves, inventory, volume, open interest, files,
  APIs, analyst forecasts, trained outputs, or portfolio results.

## 7. Trade Management Rules

- Maintain at most one logical package and exactly one position per registered
  leg magic.
- Preserve original hard stops; close on Friday, later-week detection, invalid
  package composition/notional, or the eight-day stale guard.
- Restart recovery combines a terminal-persistent attempted-week marker with
  owned positions and deal history. A marker from a future tester date is
  cleared so historical replay remains deterministic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | [`XAGUSD.DWX`] | registered companion |
| `strategy_reference_weeks` | 7 | [7] | strict weekly NR7 sample |
| `strategy_history_bars_d1` | 120 | [120] | bounded complete-week search |
| `strategy_entry_grace_minutes` | 180 | [180] | no late current-bar attach |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen per-leg hard stop |
| `strategy_notional_ratio` | 1.0 | [1.0] | XAU/XAG absolute notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | [20.0] | lot-step tolerance |
| `strategy_max_hold_days` | 8 | [8] | stale package guard |
| `strategy_xau_max_spread_points` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_points` | 1500 | [1500] | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | paired-order deviation |

Every value, week rule, shift, comparison, side, attempt, risk allocation, and
lifecycle rule is locked. Any change requires a new card and full pipeline run.

## Author Claims

The cited sources support investigating NR7-style range expansion and a
tradable gold/silver ratio carrier. They do not claim that this weekly ratio
rule works, that seven weeks is optimal for these CFDs, that opposing legs are
neutral, or that the package diversifies the certified book.

## Risk

Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The lot solver targets equal absolute entry notional but
must not exceed one combined broker-normalized fixed-cash stop budget. Each leg
has its own frozen hard stop; either stop may temporarily leave an orphan, which
must be closed immediately.

The package still carries basis, legging, spread, gap, unequal-volatility,
contract-step, synchronized-history, and regime risks. There is no live set.
Q09 alone may establish realized portfolio correlation.

## Acceptance And Retirement

Q02 must retire the unchanged identity on zero trades, fewer than five
completed packages per full post-warm-up year, nonpositive governed economics,
wrong week grouping, unsynchronized closes, non-strict NR7 classification,
stale or wrong-side entry, repeated attempt, invalid aggregate fixed risk,
malformed basket, wrong lifecycle, or nondeterminism. No after-result parameter
or carrier rescue is authorized.

This card authorizes build, instrumentation, strict compile/Q01, and paced
non-live Q02 handoff only. It does not authorize live/demo/shadow/stress/
optimization presets, AutoTrading, `T_Live`, deploy or T_Live manifests,
portfolio-gate edits, portfolio admission, decorrelation claims, or correlation
waivers.

## Framework Alignment

- No-trade: exact host/companion/timeframe/input contract, lifecycle repair,
  synchronized history, valid week sample, consumed attempt, spread/quote/ATR,
  and fixed-risk package gates.
- Trade entry: strict weekly NR7 state, fresh next-week ratio cross, persistent
  week attempt, opposing atomic basket, equal-notional/aggregate-risk sizing,
  and per-leg hard stops.
- Trade management: package composition/notional repair, Friday/later-week
  close, and eight-day stale guard.
- Trade close: paired framework exit reason with orphan repair; broker stops and
  kill switch remain authoritative.

## Pipeline History

| version | date | reason | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-18 | initial source-backed weekly gold/silver NR7 basket | G0 | APPROVED |
