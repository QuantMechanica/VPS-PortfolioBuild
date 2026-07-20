---
ea_id: QM5_20016
slug: xti-xng-mon-rv
type: strategy
strategy_id: TGIF-WTI-WEEKEND-2017_S03
source_id: TGIF-WTI-WEEKEND-2017
status: APPROVED
created: 2026-07-20
created_by: Research
last_updated: 2026-07-20
g0_status: APPROVED
g0_approval_reasoning: "OWNER commodity-sleeve mission: R1 tier-B complete peer-reviewed source; R2 fixed paired Monday directions, next-D1 exit, 1:1 notional hedge and deterministic joint risk/repair; R3 synchronized XTI/XNG D1 logical route; R4 calendar/ATR only with no ML or banned indicator; exact paired-mechanic dedup CLEAN."
source_citation: "Hoelscher, S. A., Mbanga, C. and Nelson, W. A. (2017). TGIF? The Weekend Effect in Energy Commodities. Journal of Finance Issues 16(1), 47-68. DOI 10.58886/jfi.v16i1.2264."
source_citations:
  - type: academic_paper
    citation: "Hoelscher, Seth A., Cedric Mbanga and Walt A. Nelson (2017). TGIF? The Weekend Effect in Energy Commodities. Journal of Finance Issues 16(1), 47-68."
    location: "Tables 1, 2, 4, 5 and 7; official article https://jfi-aof.org/index.php/jfi/article/view/2264; complete PDF https://jfi-aof.org/index.php/jfi/article/download/2264/1847; DOI https://doi.org/10.58886/jfi.v16i1.2264"
    quality_tier: B
    role: primary
sources:
  - "[[sources/TGIF-WTI-WEEKEND-2017]]"
concepts:
  - "[[concepts/cross-energy-weekday-relative-value]]"
  - "[[concepts/energy-weekend-effect]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, relative-value, market-neutral, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
period: D1
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20016_XTI_XNG_MON_RV_D1
expected_trade_frequency: "One paired XTI/XNG Monday-session package per eligible broker week; approximately 45-52 completed packages/year before synchronized-history, holiday, spread and entry-safety gates."
expected_trades_per_year_per_symbol: 48
expected_pf: 1.01
expected_dd_pct: 20.0
risk_class: high
ml_required: false
r1_track_record: TIER_B
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_QUEUED
review_focus: "Falsify the one-session long-XNG/short-XTI differential after CFD timing, 1:1 notional rounding, combined stop risk, costs and legging; standalone weekday overlap and unproven realized book correlation are explicit."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode_dual, magic_schema, one_position_per_magic_symbol, basket_atomicity, cfd_source_basis, portfolio_correlation]
---

# XTI/XNG Monday Relative-Value Basket

## Hypothesis

Hoelscher, Mbanga and Nelson find opposite Monday return signs in WTI and
Natural Gas in the same EIA spot-data study: WTI is negative while Natural Gas
is positive. Their full-sample robust and median regressions retain those
directions, and their Table 1 reports low Monday return correlation between
the two markets. A simultaneous long-XNG/short-XTI package can test the
cross-sectional Monday differential while targeting zero net dollar notional
instead of adding another outright commodity beta sleeve.

This is a research candidate, not a neutrality or certification claim. Equal
USD notionals do not neutralize volatility, curve basis, gaps, financing or
nonlinear CFD behavior. Q02 and later portfolio analysis must measure the
realized package and its relationship to XAU, SP500, NDX, XNG and the rest of
the book. This card does not alter the portfolio gate.

## Source and interpretation boundary

The sole source is the complete peer-reviewed 2017 article cited above. It
uses EIA daily closing spot prices through May 2017, excludes holidays and
returns without two consecutive observations, and estimates weekday effects
with White-Huber OLS, three robust estimators and robust median regression.

Table 2 Panel C reports negative WTI Monday coefficients across all five
estimators, `-0.1474` to `-0.1989` percentage points. Table 4 Panel C reports
positive Natural Gas Monday coefficients across all five estimators,
`+0.3717` to `+0.8263`. Table 1 reports WTI/Gas Monday Pearson correlation
`0.1100`. Table 5 shows weaker WTI subperiod persistence; Table 7 shows much
stronger Natural Gas persistence. These are source statistics, not expected
Darwinex returns.

The paper does not prescribe a basket. The signed pair, equal-notional hedge,
ATR stops and execution controls are QM translations. Because the source
labels close-to-close returns by the ending weekday, its Monday observation
includes a weekend gap that cannot be entered after it occurs. The executable
carrier opens at the Monday D1 bar's first tick and therefore tests only the
broker Monday session. This mismatch is load-bearing and must be falsified at
Q02; the rule may not be rescued by moving entry to Friday.

## Exact non-duplicate decision

Pre-allocation dedup returned `CLEAN` for slug `xti-xng-mon-rv`, strategy ID
`TGIF-WTI-WEEKEND-2017_S03`, and the full paired mechanic. The verdict is
`NO_EXACT_PAIRED_MECHANIC_DUPLICATE` with `KNOWN_SINGLE_LEG_OVERLAP`:

- `QM5_12596_wti-mon-fade` independently shorts WTI on Monday and may hold a
  full unhedged WTI position; it has no Natural Gas leg or package invariant.
- `QM5_12806_xng-rev-weekend` independently buys Natural Gas on Monday and
  separately shorts it on Friday; it has no WTI hedge or joint risk budget.
- `QM5_12750` and `QM5_12779` condition WTI trades on the observed Monday gap;
  this package neither reads nor conditions on gap direction.
- `QM5_12578`, `QM5_12608`, `QM5_12733`, `QM5_12840`, `QM5_12850`,
  `QM5_13089`, `QM5_13130` and the energy factor baskets use ratio,
  breakout, cross-momentum, return-spread, volatility, carry, low-price or
  month-rank signals rather than a fixed Monday differential.

Neither component is authorized alone. The new information object is the
one-session cross-energy differential with joint sizing, atomic repair and one
logical Q02 result. Component overlap is not hidden; the package must earn its
own net expectancy and realized diversification.

## Markets, timeframe and cadence

- Host: `XTIUSD.DWX`, D1, magic slot 0.
- Foreign leg: `XNGUSD.DWX`, magic slot 1.
- Logical tester symbol: `QM5_20016_XTI_XNG_MON_RV_D1`.
- Decision cadence: at most one consumed attempt per broker week.
- Normal entry: first tradable tick of a broker-calendar Monday D1 bar.
- Normal exit: first tradable tick of the next D1 bar, normally Tuesday.
- Expected frequency: approximately 45-52 paired packages/year.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1` for the entire two-leg package.

Standalone XTI or XNG tests are invalid. Both histories must be synchronized
and fresh enough for a common Monday decision.

## Entry rules

- Evaluate entry only once on a new host D1 bar whose broker weekday is
  Monday (`strategy_entry_dow=1`, Sunday=0).
- Require the first observed host tick to be within the locked five-minute
  D1 opening grace. A late attach consumes no new risk and cannot enter later
  in that session.
- Require both symbols' current D1 bar timestamps to equal the host bar time.
- Require valid prior completed D1 ATR(20), bid/ask and contract metadata for
  both legs.
- Require nonnegative spreads no greater than the per-leg locked caps.
- Persist the weekly attempt before news gating or order submission. News
  block, restart, rejection or rollback cannot create a later package that
  week.
- Submit SELL `XTIUSD.DWX` and BUY `XNGUSD.DWX`; no opposite signal exists.
- Solve both volumes jointly so total frozen ATR-stop loss is at most the one
  framework fixed-risk budget and rounded absolute USD notionals target 1:1
  within `strategy_max_notional_error_pct=20`.
- Place each hard stop at `3.0 * ATR(20)` from its own executable price. No
  take-profit is authorized.
- Submit the second leg only after the first is confirmed. If it fails, close
  the first immediately and consume the week.

## Exit rules and precedence

1. Broker-side hard stop on either leg.
2. Every-tick malformed-package repair: foreign magic, duplicate leg,
   same-direction pair, orphan, or actual-notional error above the cap closes
   all owned exposure.
3. On the first new host D1 bar after entry, close both legs before considering
   any entry. This is normally Tuesday's first tick.
4. Close both after `strategy_max_hold_days=3` calendar days as a stale guard
   if the normal next-D1 boundary was absent.
5. Framework kill-switch close remains authoritative for both registered
   magics.

News filtering blocks only new risk. It cannot delay repair, next-bar exit or
stale exit. Friday close remains enabled but should never be load-bearing for
a normal one-session Monday package.

## No-trade and management rules

- Fail closed unless attached to the exact XTI D1 host with slot 0.
- Code-lock weekday, directions, hedge ratio, ATR period/multiple, grace,
  maximum hold and deviation inputs; invalid mutation fails `OnInit`.
- One position per magic, two positions per healthy package, no pending
  orders, no independent leg, and no same-week retry.
- Position and deal history plus a terminal-global marker make the lifecycle
  restart-safe.
- Manage both magics on every host tick, including the foreign-leg kill
  switch and close paths.
- No grid, martingale, pyramid, scale-in, partial close, trailing stop,
  break-even move, price target, external runtime feed, adaptive fit, banned
  indicator or ML component.

## Parameters to test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_xng_symbol` | `XNGUSD.DWX` | locked | registered foreign leg |
| `strategy_entry_dow` | 1 | [1] | locked Monday D1 entry |
| `strategy_entry_grace_minutes` | 5 | [5] | first-bar-tick tolerance |
| `strategy_atr_period_d1` | 20 | [20] | frozen stop estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | per-leg hard-stop distance |
| `strategy_notional_ratio` | 1.0 | [1.0] | equal absolute USD notionals |
| `strategy_max_notional_error_pct` | 20.0 | [20.0] | post-rounding/fill package cap |
| `strategy_max_hold_days` | 3 | [3] | stale guard only |
| `strategy_xti_max_spread_pts` | 1000 | [1000] | WTI entry spread cap |
| `strategy_xng_max_spread_pts` | 2500 | [2500] | Natural Gas entry spread cap |
| `strategy_deviation_points` | 20 | [20] | paired-order deviation |

There is no baseline sweep. Changing weekday, either direction, allowing a
standalone leg, using a gap condition, moving entry to Friday, changing the
notional target or extending the source session creates a new strategy.

## Author claims

The authors report that WTI Monday returns are negative while Natural Gas
Monday returns are positive and significant. They also report that the
Natural Gas reverse-weekend result persists across their subperiods and robust
estimators. The paper does not claim that a paired CFD trade is profitable.

## Initial risk profile and kill criteria

- `expected_pf: 1.01` is a conservative queue prior, not evidence.
- `expected_dd_pct: 20.0` reflects gap, legging, CFD basis and stop risk, not
  a source statistic.
- Risk class: high until package integrity and cross-symbol fills are proven.
- Retire at Q02 if fewer than five completed paired packages per year are
  observed over the eligible synchronized window.
- Fail on zero trades, repeated `OnInit` failure, wrong weekday, standalone
  exposure, duplicate weekly entry, excess notional mismatch, non-determinism,
  risk-mode mismatch or any unclosed orphan.
- The generic tester counts leg trades. Density must be checked as paired
  packages, not inferred from the automatic report-trade floor.
- Do not add a trend, RSI, gap, weather, storage, return-threshold, volatility
  regime or post-hoc calendar filter after a weak baseline.

## Strategy allowability check

- [x] R1: complete official peer-reviewed source and exact tables reviewed.
- [x] R2: fixed calendar, directions, lifecycle, hedge and risk are mechanical.
- [x] R3: XTI/XNG D1 and a logical basket route are locally testable.
- [x] R4: no ML, banned indicator, adaptive fit, grid or martingale.
- [x] Expected package cadence exceeds the five-per-year Q02 floor.
- [x] Exact paired-mechanic dedup is clean; standalone overlap is disclosed.
- [x] One combined `RISK_FIXED` budget; no standalone test or live preset.

## Four-module mapping

- no_trade: exact host/timeframe/slot and locked-input guards, synchronized
  bars, weekly attempt/deal history, ATR, spread, metadata and news checks.
- trade_entry: fixed Monday directions, joint fixed-risk/equal-notional lot
  solve, frozen stops and immediate partial-package rollback.
- trade_management: every-tick composition/notional/orphan repair, next-D1
  lifecycle close, stale close and foreign-magic kill-switch ownership.
- trade_close: framework close helper on both legs plus broker hard stops.

## Implementation and safety boundary

The build must provide a basket manifest and exactly one logical
`RISK_FIXED` backtest setfile. It may not create a standalone-leg result, live
setfile, T_Live action, AutoTrading action, deploy/T_Live manifest, portfolio
gate change, portfolio admission or portfolio KPI change. The current tester
fleet is above its CPU ceiling, so smoke/backtest execution is deferred and
Q02 is enqueued without dispatch.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-20 | initial source-explicit cross-energy Monday package | G0 | APPROVED |

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-20 | APPROVED; R1-R4 PASS | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_20016_xti-xng-mon-rv.md` |
| Q01 Build Validation | - | PENDING | `framework/EAs/QM5_20016_xti-xng-mon-rv/` |
| Q02 Baseline Screening | - | NOT QUEUED | logical basket only |

## Lessons captured

- 2026-07-20: A pair made from known directional legs is acceptable only when
  the exact joint object is dedup-clean and the component overlap is explicit;
  pairing does not itself prove neutral risk or portfolio decorrelation.
