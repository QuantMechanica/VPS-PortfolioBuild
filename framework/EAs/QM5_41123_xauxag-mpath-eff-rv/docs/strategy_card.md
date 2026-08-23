---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026_S01
variant_id: SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026_S01
source_id: SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026
ea_id: QM5_41123
slug: xauxag-mpath-eff-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41123_xauxag-mpath-eff-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-23
created_by: Research+Development
last_updated: 2026-08-23
g0_status: APPROVED
g0_decision: decisions/2026-08-23_qm5_41123_xauxag_monthly_path_efficiency_reversion_g0.md
source_approval: decisions/2026-08-23_xauxag_monthly_path_efficiency_reversion_source_approval.md
source_author: "Karsten Schweikert; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; CME Group"
source_authors: "Karsten Schweikert; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; CME Group"
source_citation: "Schweikert, K. (2018), Are gold and silver cointegrated?, Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; CME Group Gold-Silver Ratio Spread; Moskowitz, Ooi and Pedersen (2012), Time Series Momentum, JFE 104(2), 228-250."
source_citations:
  - type: academic_paper_exchange_bounded_packet
    citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51; CME Group Gold-Silver Ratio Spread; Moskowitz, Ooi and Pedersen (2012), Journal of Financial Economics 104(2), 228-250."
    location: "DOIs 10.1016/j.jbankfin.2017.11.010 and 10.1016/j.jfineco.2011.11.003; governed packets under strategy-seeds/sources/; bounded child SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026/source.md"
    quality_tier: A
    role: gold_silver_relative_carrier_monthly_path_statistic_lineage
strategy_mechanic: synchronized-broker-month-boundary-xau-xag-one-immediately-completed-seventeen-to-twenty-three-session-log-ratio-daily-net-to-absolute-path-efficiency-at-least-zero-point-two-contrarian-equal-notional-basket-one-month-hold
sources:
  - "[[sources/SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/completed-month-path-efficiency]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/net-to-absolute-path-efficiency]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver, structural-relative-value, market-neutral-design, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41123_XAU_XAG_MPATH_EFF_RV_D1
symbol: QM5_41123_XAU_XAG_MPATH_EFF_RV_D1
host_symbol: XAUUSD.DWX
companion_symbol: XAGUSD.DWX
symbol_slots: [0, 1]
magic: 411230000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-7 completed two-leg packages per full post-warm-up year after the fixed path-efficiency and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_PATH_HORIZON_AND_DIRECTION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a completed-month gold/silver relative-path exhaustion basket outside the certified XAU/SP500/NDX/XNG directional book. Verify synchronized month membership, all adjacent ratio returns, exact net and absolute-path sums, inclusive 0.20 threshold, contrarian equal-notional sides, aggregate fixed risk, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, immediate_completed_calendar_month, synchronized_session_count, chronological_log_ratio_orientation, every_adjacent_return_once, signed_net_sum, absolute_path_sum, fixed_efficiency_threshold, zero_and_numerical_handling, contrarian_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-23; R1 PASS peer-reviewed gold/silver and path-statistic lineage plus official CME carrier with daily-ratio horizon and contrarian translation disclosed; R2 PASS exact synchronized month, net-to-absolute-path statistic, 0.20 threshold, sides, attempt, aggregate risk, atomicity and lifecycle; R3 PASS native XAU/XAG D1; R4 PASS deterministic arithmetic without banned signal; pre-allocation dedup CLEAN and post-allocation only self-hits."
---

# QM5_41123 XAU/XAG Completed-Month Path-Efficiency Reversion

## Hypothesis

When the net gold/silver log-ratio displacement accounts for a material share
of every daily relative move in a completed broker month, the intermetal move
has been unusually one-directional. On a related but state-dependent
gold/silver carrier, that efficient relative displacement may partially mean
revert during the next broker month.

The opposite equal-notional legs are designed to reduce common outright-metal
direction and supply exposure different from the certified directional
XAU/SP500/NDX/XNG book. They do not prove neutrality, profitability, or low
correlation. Q02 owns baseline economics and density; unchanged Q09 alone may
establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026/source.md`,
authorized before extraction by
`decisions/2026-08-23_xauxag_monthly_path_efficiency_reversion_source_approval.md`
at commit `13cb898ac`.

Schweikert supports testing a potentially state-dependent long-run gold/silver
relation. CME defines the ratio and intermarket carrier. Moskowitz, Ooi, and
Pedersen provide completed-price and monthly-clock lineage, while the governed
path-efficiency packet preserves the exact closed-form statistic. The sources
do not test daily ratio efficiency inside one month, the 0.20 threshold,
contrarian sides, a Darwinex CFD basket, fixed-dollar ATR risk, or the QM book.
Every horizon, direction, execution, and risk choice below is a declared QM
interpretation.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, or correlation
statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,622 registry
identities, 1,291 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`.
After deterministic allocation it found only the expected slug and strategy-ID
self-hits for `QM5_41123`. Evidence is in the pre- and post-allocation receipts
under `artifacts/`.

Manual family review fixes the mechanical boundaries:

- rolling XAU/XAG ratio, OLS, quantile, median/MAD, and tail cards estimate a
  center, scale, rank, or fresh crossing; this card estimates none.
- `QM5_20274_wti-path-eff` follows an outright WTI twelve-month path at a 0.25
  threshold. This card fades one completed month of synchronized gold/silver
  relative daily returns with two opposite legs and a 0.20 threshold.
- `QM5_41112_xauxag-mdaybreadth-rv` counts daily relative-return signs while
  discarding magnitudes. This card uses every return magnitude in `P`.
- `QM5_41113`, `QM5_41116`, and `QM5_41118` aggregate fixed blocks; this card
  has no block boundary or vote.
- `QM5_41119`, `QM5_41120`, and `QM5_41121` use range location, anchor
  residence, or sequence transitions; this card uses only signed net ratio
  displacement and the full absolute adjacent path.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback.

The paired carrier, exact completed month, synchronized sessions, every
adjacent relative return, net-to-absolute-path quotient, fixed inclusive 0.20
threshold, contrarian sides, durable attempt, equal-notional aggregate-risk
package, and next-month exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_PATH_EFFICIENCY_REVERSION_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host: exact `XAUUSD.DWX`, D1, slot 0, planned magic `411230000`.
- Companion: exact `XAGUSD.DWX`, D1, slot 1, planned magic `411230001`.
- Logical symbol: `QM5_41123_XAU_XAG_MPATH_EFF_RV_D1`.
- Decision: first synchronized executable tick of a new broker-calendar
  month, within 180 elapsed minutes of the raw current host D1 bar open.
- Signal data: exact immediately completed synchronized calendar month only;
  current-month prices are excluded.
- Position count: zero or one valid two-leg package and at most one consumed
  attempt per broker `yyyymm`.
- Expected frequency: six packages/year as an ordering prior within a 5-7
  design range; Q02 must prove at least five in every scored full year.

## Completed-Month Contract

The immediately preceding synchronized pair must belong to the prior calendar
month. Within a fixed 45-bar buffer, the package must contain exactly every
completed D1 pair labeled with that prior year and month. Require 17 through 23
unique timestamps in strict order and one adjacent older synchronized pair
proving that the package was not truncated. A current-month pair, duplicate or
mismatched timestamp, wrong month, missing boundary proof, invalid close, or
session count outside 17-23 consumes the current month flat.

For chronological synchronized sessions `i=0..n-1`:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[j] = s[j] - s[j-1], j=1..n-1
N    = sum(r[j])
P    = sum(abs(r[j]))
E    = abs(N) / P

E >= 0.20 and N > 0 => SELL XAU, BUY XAG
E >= 0.20 and N < 0 => BUY XAU, SELL XAG
otherwise            => FLAT
```

Require finite arithmetic, `P>0`, and `E` in `[0,1]` within `1e-10`.
Exact-zero constituent returns are valid and add zero to both sums. Zero total
path, zero net, below-threshold efficiency, and invalid numerical state are
flat. Every adjacent return contributes exactly once. No current-month price
enters the formula.

## Rules

The entry, exit, filter, and management contracts below are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

1. Repair malformed or partial owned exposure before entry-only filters.
2. Require exact symbols, D1, EA ID, slots, risk mode, news modes, Friday-close
   inputs, and one current synchronized bar time.
3. Observe a new host D1 bar and derive current broker `yyyymm` from its raw
   bar time.
4. Admit only within `strategy_entry_grace_minutes=180` elapsed minutes of
   raw host bar open. Late attachment consumes the month flat.
5. Persist current `yyyymm` attempt before history, aggregation, signal, news,
   spread, quote, ATR, sizing, or order gates. Never retry that month.
6. Aggregate the exact immediately completed synchronized broker month.
   Require 17 through 23 valid pairs and an older boundary pair.
7. Build chronological log ratios and every adjacent return. Require finite
   values, `P>0`, and efficiency bounds.
8. Require `E>=strategy_efficiency_threshold=0.20` and nonzero `N`.
9. Fade positive `N` with SELL XAU / BUY XAG and negative `N` with BUY XAU /
   SELL XAG. Equality, invalid state, and below-threshold state remain flat.
10. Require XAU spread no greater than 1,500 points, XAG spread no greater
    than 500 points, valid quotes, and valid completed-bar `ATR(20,D1)` on
    both legs.
11. Freeze one hard stop `3.5*ATR` from each leg's entry and use no target.
12. Size to equal target absolute USD notionals with combined normalized stop
    risk at or below the single aggregate `RISK_FIXED` budget. Reject a package
    whose realized notional mismatch exceeds 20%.
13. Submit the first leg then the second; if the second leg fails or the pair
    is malformed, close all owned exposure immediately. No same-month retry.

Efficiency beyond 0.20 and displacement magnitude never change the fixed risk
budget or target notionals.

### Attempt And Restart Contract

The attempt key is terminal-global, scoped by EA and logical basket, and stores
current broker `yyyymm`. It is written before every fallible gate.
Initialization after the 180-minute grace consumes the missed month without a
late trade. Owned deal history and open-position checks are additional
fail-closed guards. An order rejection, atomic repair, stop-out, news block,
spread failure, restart, invalid ATR, or invalid history cannot create a
same-month retry.

## 5. Exit Rules

1. Broker hard stops and framework kill switch remain authoritative.
2. Orphaned, duplicated, same-side, wrong-magic, stopless, or notional-invalid
   owned exposure is flattened as one broken package.
3. Close both legs on the first tick whose broker `yyyymm` is later than the
   month stored for the package's entry attempt.
4. Forty elapsed calendar days is a stale repair only.

There is no convergence target, take-profit, opposite-signal exit, trailing
stop, break-even move, partial close, Friday flattening, scale-in, pyramid,
grid, martingale, hedge adjustment, or discretionary close.

## 6. Filters (No-Trade Module)

- Require exact host `XAUUSD.DWX`, exact companion `XAGUSD.DWX`, D1, EA ID
  `41123`, and slots 0/1.
- Require `RISK_FIXED>0`, `RISK_PERCENT=0`, valid stop inputs, news temporal
  OFF, news compliance NONE, and Friday close disabled.
- Framework kill-switch, broker, and ownership controls remain authoritative.
- Apply entry grace, durable attempt, exact synchronized calendar month,
  history and close validity, path-efficiency gate, spread ceilings, valid
  quotes, completed ATRs, sizing, notional mismatch, and atomicity fail-closed.
- No fitted center, scale, z-score, regression, quantile, rank, moving average,
  oscillator, sign count, block vote, sequence count, range location, volume,
  open interest, event calendar, futures curve, external file, API, or manual
  runtime input is used.

## 7. Trade Management Rules

- Own either zero exposure or exactly one valid opposite-side two-leg package
  on registered magics and symbols.
- Flatten orphaned, duplicated, same-side, stopless, wrong-side, or
  notional-invalid exposure before considering a new entry.
- Leave both frozen server-side stops unchanged; do not trail, widen, partial-
  close, rebalance, reverse, scale, or pyramid.
- Close both survivors at the first later broker-month boundary; use the
  forty-day guard only when that boundary repair was missed.
- Management remains reachable on every tick before any entry-only gate.

## Parameters To Test

No optimization surface is approved. The sole baseline uses:

| Parameter | Locked value | Role |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_history_bars_d1` | 45 | bounded synchronized month buffer |
| `strategy_min_month_sessions` | 17 | minimum completed-month pairs |
| `strategy_max_month_sessions` | 23 | maximum completed-month pairs |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_efficiency_threshold` | 0.20 | inclusive path-efficiency gate |
| `strategy_efficiency_tolerance` | 1e-10 | numerical upper-bound tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal target absolute notionals |
| `strategy_max_notional_mismatch_pct` | 20.0 | atomic package validity ceiling |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_xau_max_spread_points` | 1500 | gold entry-cost guard |
| `strategy_xag_max_spread_points` | 500 | silver entry-cost guard |
| `strategy_deviation_points` | 20 | deterministic order deviation |
| `qm_friday_close_enabled` | false | full-month identity |

Every value is locked in the one logical baseline setfile and is not an
optimization surface.

## Source-Defined Rules

The source lineage supplies a related gold/silver carrier, intermarket-spread
interpretation, completed-price path, monthly clock, and auditable
net-to-absolute-path statistic. It does not supply the daily-ratio horizon,
threshold, or contrarian direction.

## QM Interpretations

`SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026_S01` fixes synchronized broker
month labels, 17-to-23 pairs, every adjacent daily ratio return, 0.20 threshold,
fade direction, continuous-CFD mapping, equal-notional aggregate fixed risk,
entry grace, persistent attempt, spread caps, atomicity, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
repair precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stops and framework kill switch.
2. Malformed, orphaned, or unsafe owned-package repair.
3. Later broker-month closure.
4. Forty-calendar-day stale repair.

## Runtime Data Dependencies

Exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX` native D1 closes and
timestamps, broker time, symbol metadata, quotes, completed-bar ATRs,
framework position/deal state, and persistent terminal global-variable attempt
state. No finite external dataset or event calendar exists.

## Risk

- Backtest only: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Equal target absolute USD notionals with at most 20% realized mismatch.
- Frozen hard stop: `3.5*ATR(20,D1)` on each leg; normalized per-leg risk sums
  to no more than the one aggregate fixed-risk budget.
- No target, convergence exit, or signal-strength sizing.
- Major risks are structural ratio breaks, efficient-move continuation,
  calendar mismatch, continuous-CFD roll/basis, financing, asymmetric spread
  and fill, orphan exposure, density below the floor, and realized book
  correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS | Peer-reviewed gold/silver and path-statistic DOI lineage, official CME carrier, complete-read evidence, durable hashes, and all translations disclosed. |
| R2 | PASS | Exact synchronization, month clock, return arithmetic, threshold, sides, attempt, shared risk, stops, atomicity, spread gates, and lifecycle. |
| R3 | PASS | Registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 history and MT5 state supply every runtime field. |
| R4 | PASS | Deterministic timestamp, price, logarithm, absolute-value, sum, division, and execution-state arithmetic only; no trained or adaptive signal. |

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five completed
packages in any full post-warm-up year, nonpositive governed economics,
unsynchronized or wrong month membership, wrong return orientation or count,
wrong `N`, `P`, or `E`, accepting `P=0`, rejecting equality at 0.20, wrong
side, late or repeated attempt, missing hard stop, aggregate-risk breach,
notional mismatch above 20%, orphan survival, wrong next-month close,
nondeterminism, or invalid fixed-risk mode.

Changing the carrier, month package, statistic, threshold, direction, attempt
clock, equal-notional contract, risk, stops, or lifecycle requires a new
identity and full G0/Q01 cycle. A failed result may not be rescued by adding a
center, scale, z-score, sign count, block vote, sequence state, range location,
volatility, calendar, volume, event, external, or prior-result filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/companion/period, synchronized month, path arithmetic, threshold, attempt, spread, ATR, paired sizing | Trade Entry | `Strategy_EntrySignal` plus deterministic basket helpers |
| malformed/orphan repair, later-month and stale closure | Trade Management | `Strategy_ManageOpenPosition` plus package lifecycle helper |
| next-month and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, aggregate fixed-risk mode | Framework No-Trade | standard framework orchestration plus paired ownership checks |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove first-month-bar and 180-minute timing; synchronized months and
year boundaries; exact immediately completed package; 17/20/23-pair acceptance
and 16/24 rejection; oldest-to-newest ratios; every adjacent return once;
positive and negative `N`; zero constituent returns accepted; `P=0` and `N=0`
flat; `E` below, equal to, and above 0.20; numerical tolerance; contrarian
sides; no current-month leakage; persistent monthly attempts; equal-notional
aggregate fixed-risk sizing; second-leg failure cleanup; orphan and malformed
repair; next-month and stale closure; card lint; strict compile; logical
setfile and basket-manifest schema; resolver identity; and static artifact
validation.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-23 | initial XAU/XAG completed-month path-efficiency reversion card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-23 | APPROVED | `decisions/2026-08-23_qm5_41123_xauxag_monthly_path_efficiency_reversion_g0.md` |
| Q01 Build Validation | 2026-08-23 | PENDING_BUILD | source implementation and strict compile required |
| Q02 Baseline Screening | 2026-08-23 | NOT_ENQUEUED_Q01_PENDING | strict compile, EX5, final set binding, basket manifest, and Q01 PASS required |

## Safety Boundary

This card requests a branch-only non-live build, Q01 validation, one logical
D1 `RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only
below tester and CPU ceilings. It does not authorize a manual backtest,
terminal control, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio-gate change, portfolio
admission, decorrelation claim, or correlation waiver.
