---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026
ea_id: QM5_41119
slug: xauxag-mclose-quartile-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41119_xauxag-mclose-quartile-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-22
created_by: Research+Development
last_updated: 2026-08-22
g0_status: APPROVED
g0_decision: decisions/2026-08-22_qm5_41119_xauxag_monthly_close_quartile_reversion_g0.md
source_approval: decisions/2026-08-22_xauxag_monthly_close_quartile_reversion_source_approval.md
source_author: "Karsten Schweikert; CME Group"
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Yaya, Vo, and Olayinka (2021), Resources Policy 72, 102045, DOI 10.1016/j.resourpol.2021.102045; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: academic_paper
    citation: "Schweikert, Karsten (2018), Are gold and silver cointegrated? New evidence from quantile cointegrating regressions, Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete-read packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_long_run_relation
  - type: academic_paper
    citation: "Yaya, OlaOluwa S.; Vo, Xuan Vinh; and Olayinka, Hammed A. (2021), Gold and silver prices, their stocks and market fear gauges: Testing fractional cointegration using a robust approach, Resources Policy 72, 102045."
    location: "DOI 10.1016/j.resourpol.2021.102045; governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: supporting_fractional_cointegration_lineage
  - type: exchange_research
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md; bounded extraction strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026/source.md"
    quality_tier: A
    role: ratio_definition_and_intermarket_spread_carrier
strategy_mechanic: synchronized-immediately-completed-calendar-month-seventeen-to-twenty-three-chronological-gold-minus-silver-log-ratio-closes-strict-newest-close-rank-fixed-ceiling-quarter-lower-upper-tail-contrarian-next-month-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-ratio-reversion]]"
  - "[[concepts/completed-month-close-rank]]"
  - "[[concepts/market-neutral-commodity-basket]]"
indicators:
  - "[[indicators/completed-month-inclusive-count-close-quartile]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver-ratio, relative-value-basket, completed-month-close-quartile, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41119_XAU_XAG_MCLOSE_QUARTILE_RV_D1
symbol: QM5_41119_XAU_XAG_MCLOSE_QUARTILE_RV_D1
host_symbol: XAUUSD.DWX
companion_symbols: [XAGUSD.DWX]
symbol_slot_map: {XAUUSD.DWX: 0, XAGUSD.DWX: 1}
magic_map: {XAUUSD.DWX: 411190000, XAGUSD.DWX: 411190001}
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-7 completed XAU/XAG basket packages per full post-warm-up year from the fixed lower/upper close-rank sets; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CLOSE_QUARTILE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a completed-month gold/silver close-quartile fade outside the certified XAU/SP500/NDX/XNG book. Verify exact synchronized 17-23-session month membership, chronological log-ratio closes, strict newest uniqueness, lower-count rank, ceil(n/4) outer sets, contrarian pair sides, durable monthly attempt, aggregate fixed risk, atomic basket repair, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, synchronized_first_tradable_month_bar, immediately_completed_calendar_month, bounded_month_session_count, chronological_ratio_close_order, strict_newest_close_uniqueness, zero_based_lower_count_rank, ceiling_quarter_tail_count, fixed_outer_rank_sets, contrarian_package_direction, persistent_month_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_month_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 Tier A peer-reviewed DOI plus official CME carrier with close-quartile translation disclosed; R2 locks synchronized month history, strict rank/tie arithmetic, inverse outer-rank sides, attempt, aggregate risk, atomicity and lifecycle; R3 native XAU/XAG D1; R4 deterministic arithmetic with no banned signal; pre-allocation dedup CLEAN and post-allocation only self-hits."
---

# QM5_41119 XAU/XAG Completed-Month Close-Quartile Reversion

## Hypothesis

Gold and silver share a long-run precious-metals factor but have different
monetary, safe-haven, and industrial sensitivities. When the final
synchronized gold/silver log-ratio close of a completed calendar month lies in
that month's fixed lower or upper close-rank quartile, the relative move may
be temporarily extended. Fading that rank for the next broker month may
capture a structural, low-frequency intermetal reversion effect.

This is one opposite-leg relative-value package rather than another outright
XAU, index, or XNG direction. Equal-notional construction is a target, not
proof of profitability, neutrality, or decorrelation. Q02 owns frequency and
baseline economics; Q09 alone may establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026/source.md`,
authorized before extraction by
`decisions/2026-08-22_xauxag_monthly_close_quartile_reversion_source_approval.md`
at commit `7649b3e95`. The bounded extraction was committed at `123c8cf71`.
The complete parent-source hashes are
`4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`
and `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.

Schweikert documents state-dependent gold/silver cointegration evidence, the
supporting paper documents fractional-cointegration lineage, and CME defines
the gold/silver ratio and intermarket spread carrier. They do not test a
completed-month close-quartile rule, continuous CFDs, equal-notional fixed-
dollar risk, or the QM book. All month, ranking, tie, execution, and risk
choices below are declared QM interpretations.

No source return, density, hedge ratio, profit factor, drawdown, transaction
cost, CFD equivalence, neutrality, or correlation statistic is imported.

## Non-Duplicate Decision

The fail-closed pre-allocation checker scanned 4,618 registry identities,
1,287 repository cards, and 45 Strategy-Wiki nodes. It found no exact or
fuzzy candidate match and returned `CLEAN`. The post-allocation scan covered
4,619 registry identities and found only the expected reserved `QM5_41119`
slug and strategy-ID self-hits, with no foreign fuzzy match.

Manual semantic review fixes the load-bearing boundaries:

- `QM5_41079_xauxag-wclose-extreme-rv` requires the unique newest minimum or
  maximum inside a three-to-five-session completed week and holds one week.
  This card uses fixed outer quartile rank sets inside a 17-to-23-session
  completed month and holds one month.
- `QM5_20268_xauxag-qtail-rv` ranks against a frozen 126-ratio empirical
  distribution, requires a central-plus-two-tail event, and exits at a
  rolling median. This card ranks only the final close inside one completed
  month and exits at the next month.
- `QM5_41118_xauxag-mlatehalf-dom-rv` partitions adjacent returns into two
  exhaustive cumulative blocks and compares their magnitudes. This card uses
  close levels, no return blocks, and no magnitude comparison.
- `QM5_41110_xauxag-moutside-res-rv` measures residence outside a parent-
  month range, while `QM5_41103_xauxag-mrange-migrate-rv` compares two month
  ranges. This card reconstructs one month and has neither state.
- `QM5_12577`, `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268`
  estimate a rolling center, regression, scale, score, or empirical tail.
  This card estimates none.
- `QM5_12533` supplies the validated logical-basket manifest/order recipe but
  trades an EURJPY/GBPJPY cointegration package.
- certified `QM5_12567_cum-rsi2-commodity` is a single-symbol, long-only,
  two-day XNG oscillator pullback, not a paired monthly intermetal rank fade.

The exact paired carrier, immediately completed calendar month,
17-to-23-session synchronization, chronological ratio closes, strict newest-
close uniqueness, fixed `ceil(n/4)` outer rank sets, contrarian rank package,
consumed monthly attempt, equal-notional aggregate-risk package, and next-
month exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_STRICT_CLOSE_QUARTILE_REVERSION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host: `XAUUSD.DWX`, D1, slot 0, planned magic `411190000`.
- Exact companion: `XAGUSD.DWX`, D1, slot 1, planned magic `411190001`.
- Logical symbol: `QM5_41119_XAU_XAG_MCLOSE_QUARTILE_RV_D1`.
- Formation: all synchronized close pairs in the immediately completed
  broker-calendar month, with 17 through 23 sessions.
- Decision: first tradable synchronized D1 bar of a new broker month, within
  180 elapsed raw-session minutes.
- Signal: newest completed-month ratio close is in the strict unique lower or
  upper inclusive-count quartile; fade its rank.
- Ordinary exit: first tick whose broker month is later than the package-open
  month.
- Expected cadence: approximately five to seven completed packages/year;
  retire below five.
- Q02 risk: aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let the immediately completed broker month contain `n` synchronized positive
finite D1 close pairs ordered oldest to newest, with `17 <= n <= 23`:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..n-1
z    = s[n-1]
rank = count(s[i] < z for i=0..n-1)
tail = ceil(n/4) = (n+3)//4

any s[i] == z for i=0..n-2 => FLAT
rank < tail                 => BUY XAU, SELL XAG
rank >= n-tail              => SELL XAU, BUY XAG
otherwise                   => FLAT
```

Every input completes before the decision month begins. The newest close
participates once. The strict lower-count rank spans `0..n-1` when unique.
Across the locked session range, each outer set contains five or six ranks.
The current month's open, high, low, or close never enters the signal. Rank
distance never changes signal or risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XAUUSD.DWX` D1 bar under EA 41119 and
   host magic slot zero.
2. Repair malformed, orphaned, duplicated, same-side, stopless, notional-
   invalid, later-month, or stale owned exposure before entry-only gates.
3. Require exact host and companion D1 timestamps. Normalize the broker-date
   label uniformly across both series, require the current synchronized bar
   to be the first tradable bar of a new month, and reject attachment later
   than 180 elapsed minutes after the raw host bar open.
4. Persist the current decision `yyyymm` before history, signal, spread,
   quote, ATR, sizing, news, or order gates. Never retry that month.
5. Within a fixed 45-bar buffer, collect every positive finite synchronized
   close pair whose normalized label belongs to the immediately completed
   month. Require exactly 17 through 23 pairs, identical timestamps across
   legs, unique strict chronology, exact month membership, and no current-
   month pair.
6. Order ratios oldest to newest. Require the newest ratio to differ from
   every earlier ratio. Count all ratios strictly below it, compute
   `tail=(n+3)//4`, and accept only `rank < tail` or `rank >= n-tail`.
   Equality and every interior rank consume the attempt flat.
7. BUY XAU/SELL XAG for a lower-quartile close. SELL XAU/BUY XAG for an
   upper-quartile close. Rank distance never changes risk.
8. Require no owned exposure, no same-magic entry deal already recorded in
   the current month, executable side-specific quotes, and no genuinely
   positive spread wider than 1,500 XAU points or 500 XAG points. Modeled
   zero `.DWX` spread is valid.
9. Require valid completed-bar `ATR(20,D1)` for both legs and attach one frozen
   hard stop at `3.5*ATR` on each. Size the package so combined normalized
   stop risk cannot exceed the single `RISK_FIXED=1000` budget.
10. Target one-to-one absolute entry notional. Round down only and reject a
    resulting mismatch above 20 percent. Use no take-profit.
11. Submit the two market legs once. If either leg fails or the resulting
    composition/notional contract is invalid, immediately flatten all owned
    exposure. No pending order, retry, one-leg fallback, scale-in, grid,
    martingale, pyramid, hedge overlay, or second entry exists.

## 5. Exit Rules

1. Broker hard stops and framework kill-switch closure remain authoritative.
2. Immediately flatten an orphan, duplicate, same-side, wrong-symbol, wrong-
   magic, missing-stop, invalid-volume, or notional-invalid package.
3. Close both legs on the first tick whose normalized broker `yyyymm` is later
   than the package-open `yyyymm`.
4. Close after forty elapsed calendar days as a final stale guard.
5. No Friday close, target, fitted-mean exit, signal reversal, trailing stop,
   break-even move, partial exit, discretionary close, or intentional hold
   beyond the next broker month is authorized.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41119, slot zero, and both governed magics.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes, legacy news mode, and Friday close are OFF for Q02;
  lifecycle repair is never delayed by an entry-only gate.
- Uniform date-label normalization, first-month-bar clock, exact prior month,
  synchronized timestamps, 17-to-23 session count, unique chronological
  endpoints, positive finite prices, strict newest uniqueness, lower-count
  rank, fixed quartile arithmetic, durable attempt, side-specific trade mode,
  spread, quote, ATR, sizing, stop geometry, and notional match all fail
  closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, rolling center, fitted hedge ratio, or
  manual signal is read at runtime.

## 7. Trade Management Rules

- Own exactly one `XAUUSD.DWX` position under active magic `411190000` and one
  opposite-side `XAGUSD.DWX` position under active magic `411190001`.
- Persist the last attempted decision `yyyymm` across restart; clear only a
  future-dated tester residue at initialization.
- Manage malformed, later-month, stale, and kill-switch exits on every tick
  before entry evaluation.
- Freeze both original hard stops; never widen, trail, or remove them.
- Do not retry, add, pyramid, grid, martingale, partially close, add a third
  hedge, or reverse inside the month.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_history_bars_d1` | 45 | bounded completed-month buffer |
| `strategy_min_month_sessions` | 17 | complete-month lower bound |
| `strategy_max_month_sessions` | 23 | complete-month upper bound |
| `strategy_entry_grace_minutes` | 180 | first-month-bar window |
| `strategy_atr_period_d1` | 20 | completed-bar per-leg range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal absolute notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | lot-step mismatch ceiling |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_xau_max_spread_points` | 1500 | XAU cost guard |
| `strategy_xag_max_spread_points` | 500 | XAG cost guard |
| `strategy_deviation_points` | 20 | bounded market-order deviation |
| `qm_friday_close_enabled` | false | full-month identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive value |

The inclusive-count quartile, tie rejection, contrarian direction, one-
attempt rule, and next-month exit are not parameters.

## Source-Defined Rules

Schweikert supplies state-dependent gold/silver relationship lineage. CME
supplies the gold/silver ratio definition and intermarket carrier. Neither
source supplies the within-month close-rank state or one-month fade.

## QM Interpretations

`SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026_S01` fixes the exact completed
month, session bounds, strict final-close rank, `ceil(n/4)` outer sets, tie
rule, inverse sides, continuous-CFD clock, durable attempt, equal-notional
aggregate risk, spread caps, stops, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. The companion magic must be registered as a foreign
owned magic before build. No live execution override exists.

## Exit Precedence

1. Broker hard stops and framework kill switch.
2. Malformed or unsafe owned-package repair.
3. Later broker-month closure.
4. Forty-calendar-day stale repair.

## Runtime Data Dependencies

Exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX` native D1 timestamps and
closes, broker time, symbol metadata, quotes, completed-bar ATR, framework
position/deal state, and persistent terminal global-variable attempt state.
No finite external dataset or calendar exists.

## Risk

- Backtest only: aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data on each leg.
- Combined normalized stop risk may not exceed one fixed-risk budget.
- No target and no signal-strength sizing.
- Major risks are non-convergence, repeated monthly extremes during a relative
  trend, one-leg fills, stop-risk asymmetry, lot-step notional mismatch,
  gold/silver beta drift, month-end gaps, continuous-CFD basis, financing,
  spread, density below the floor, source translation, and realized overlap
  with the XAU book.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_CLOSE_QUARTILE_TRANSLATION_RISK | Named peer-reviewed DOI, supporting DOI, official CME carrier, complete-read evidence, and durable hashes; the within-month rank rule is an untested QM translation. |
| R2 | PASS | Clock, month membership, synchronization, ordering, exact rank/quartile/tie arithmetic, attempt, sides, aggregate risk, atomicity, and lifecycle are deterministic. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered native XAU/XAG D1 supplies all runtime inputs; Q02 owns synchronization, density, costs, financing, and CFD-basis sufficiency. |
| R4 | PASS | Native deterministic arithmetic and state only; no trained signal, banned indicator, external runtime feed, grid, or martingale. |

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong or
asynchronous month timestamps, invalid session count, current-month leakage,
missing or duplicated closes, wrong chronology, accepted tie, wrong rank or
quartile boundary, wrong contrarian side, duplicate monthly attempt, one-leg
survivor, aggregate-risk breach, notional mismatch above 20 percent, missing
hard stop, wrong next-month exit, or nondeterminism.

Requalification requires a new OWNER-approved card version before changing
the quartile definition, tie handling, direction, hold, history/session bounds,
or adding return, volatility, volume, season, weekday, moving-average,
breakout, event, inventory, external-data, or prior-result gates. No post-
result parameter salvage is authorized.

## Framework Alignment

| Card rule | V5 owner | Implementation target |
|---|---|---|
| Exact host/period, risk, news, Friday, frozen inputs | No-Trade | `Strategy_NoTradeFilter` plus framework initialization |
| Month label, synchronization, close package, rank/quartile/tie, attempt, ATR sizing | Trade Entry | `Strategy_EntrySignal` plus basket order helper |
| Frozen stops and malformed-package repair | Trade Management | `Strategy_ManageOpenPosition` plus pre-entry lifecycle repair |
| Next-month and forty-day stale exits | Trade Close | package lifecycle helper and `Strategy_ExitSignal` |
| Native-price declaration; news OFF/OFF | News hook | `Strategy_NewsFilterHook` |

## Validation Plan

Q01 must prove native and uniformly shifted date-label equivalence; first-
month-bar and 180-minute clock; immediately completed month across year
boundaries; 17- and 23-session synchronized packages; chronological ratio
ordering; each possible lower, interior, and upper rank; `ceil(n/4)` at every
allowed `n`; tie and invalid-price flat states; no current-bar leakage;
persistent monthly attempts; fixed-risk frozen-stop sizing; atomic broken-
package repair; next-month and stale exits; card lint; strict compile; setfile
schema; basket manifest; resolver identity; and deterministic reference tests.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1-card | 2026-08-22 | new OWNER-authorized XAU/XAG structural sleeve | Q00 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| Q00 Research Intake | 2026-08-22 | APPROVED | `decisions/2026-08-22_qm5_41119_xauxag_monthly_close_quartile_reversion_g0.md` |
| Q01 Build and Spec | - | PENDING | - |
| Q02 Baseline | - | NOT_QUEUED | - |

## Safety Boundary

Research/backtest only. This card authorizes one branch-only non-live build,
strict Q01, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue only
after all gates pass. It authorizes no manual tester; live/demo/shadow/stress/
optimization setfile; AutoTrading; `T_Live`; deploy or T_Live manifest;
portfolio admission; portfolio-gate change; correlation waiver; or live use.
