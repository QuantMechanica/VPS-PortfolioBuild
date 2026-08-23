---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-MEHLITZ-CME-XAUXAG-MDAILY-PERSIST-RV-2026_S01
variant_id: SCHWEIKERT-MEHLITZ-CME-XAUXAG-MDAILY-PERSIST-RV-2026_S01
source_id: SCHWEIKERT-MEHLITZ-CME-XAUXAG-MDAILY-PERSIST-RV-2026
ea_id: QM5_41128
slug: xauxag-mdaily-persist-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41128_xauxag-mdaily-persist-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-23
created_by: Research+Development
last_updated: 2026-08-23
g0_status: APPROVED
g0_decision: decisions/2026-08-23_qm5_41128_xauxag_monthly_daily_persistence_reversion_g0.md
source_approval: decisions/2026-08-23_xauxag_monthly_daily_persistence_reversion_source_approval.md
source_author: "Karsten Schweikert; Julia S. Mehlitz; Benjamin R. Auer; CME Group"
source_authors: "Karsten Schweikert; Julia S. Mehlitz; Benjamin R. Auer; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread; Mehlitz and Auer (2024), European Journal of Finance 30(8), 773-802, DOI 10.1080/1351847X.2023.2220118."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relation
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade.html; governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: B
    role: intermarket_spread_carrier_and_driver_difference
  - type: peer_reviewed_paper_bounded_packet
    citation: "Mehlitz, J. S., and Auer, B. R. (2024). Memory-enhanced momentum in commodity futures markets. The European Journal of Finance 30(8), 773-802."
    location: "DOI 10.1080/1351847X.2023.2220118; complete-read evidence strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md; bounded statistic strategy-seeds/sources/MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026/source.md"
    quality_tier: A
    role: commodity_return_memory_and_daily_persistence_statistic
strategy_mechanic: exact-synchronized-xau-xag-immediately-completed-broker-month-seventeen-to-twenty-three-daily-gold-minus-silver-log-ratio-returns-demeaned-adjacent-product-lag-one-score-plus-fixed-one-over-n-minus-one-strict-positive-gate-contrarian-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-MEHLITZ-CME-XAUXAG-MDAILY-PERSIST-RV-2026]]"
concepts:
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/completed-month-daily-persistence]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/bias-neutralized-lag-one-return-persistence]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, structural-reversion, completed-month-daily-persistence, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41128_XAU_XAG_MDAILY_PERSIST_RV_D1
symbol: QM5_41128_XAU_XAG_MDAILY_PERSIST_RV_D1
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411280000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-7 completed XAU/XAG packages per full post-warm-up year after the fixed persistence and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_PATH_HORIZON_AND_DIRECTION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a completed-month gold/silver daily-persistence reversion basket outside the certified directional XAU/SP500/NDX/XNG book. Verify exact synchronization, older boundary pair, every relative return ending in the month, centering, variance and adjacent-products, fixed 1/(n-1) neutralization, strict positive score, contrarian equal-notional sides, one attempt, aggregate fixed risk, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, immediate_completed_calendar_month, synchronized_session_count, older_boundary_pair, chronological_relative_log_return_orientation, every_month_return_once, return_mean, centered_variance, adjacent_product_sum, fixed_sample_neutralization, endpoint_identity, strict_positive_persistence_gate, contrarian_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-23; R1 PASS peer-reviewed gold/silver relation and commodity-memory lineage plus official exchange carrier, with the within-month daily relative-path gate and contrarian direction disclosed as untested translations; R2 PASS exact synchronized month package, return inclusion, centering, variance, adjacent products, fixed correction, endpoint identity, strict gate, sides, attempt, aggregate risk, atomicity and lifecycle; R3 PASS registered native XAU/XAG D1 routes with synchronization and continuous-CFD basis risk; R4 PASS deterministic arithmetic without banned signal; pre-allocation dedup CLEAN and post-allocation only expected self-hits."
---

# QM5_41128 XAU/XAG Completed-Month Daily-Persistence Reversion

## Hypothesis

Gold and silver share precious-metals and USD drivers but respond differently
to safe-haven, monetary, industrial, and business-cycle shocks. A completed
month whose daily gold-minus-silver relative returns remain positively related
from one session to the next represents a persistent intermetal displacement,
not merely a month-end move assembled from offsetting noise. Fading that
persistent displacement for the following broker month tests whether the
state-dependent long-run relation pulls the ratio back after an orderly
relative trend.

The opposite equal-notional legs are designed to reduce common outright-metal
direction and create a market-neutral-style return stream different from the
certified directional XAU/SP500/NDX/XNG book. They do not prove dollar, beta,
volatility, factor, or portfolio neutrality. Q02 owns density and baseline
economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-MEHLITZ-CME-XAUXAG-MDAILY-PERSIST-RV-2026/source.md`,
authorized before extraction by
`decisions/2026-08-23_xauxag_monthly_daily_persistence_reversion_source_approval.md`
at commit `8889d7f32`.

Schweikert supports testing a potentially state-dependent long-run gold/silver
relation. CME defines the ratio and intermarket-spread carrier. Mehlitz and
Auer provide commodity return-memory lineage, while the governed WTI child
preserves the exact daily persistence arithmetic. The sources do not test
daily gold/silver relative-return persistence inside one month, the fixed
short-sample correction, contrarian sides, a Darwinex CFD basket, equal-
notional fixed-dollar ATR risk, or the QM book. Every horizon, direction,
execution, and risk choice below is a declared QM interpretation.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, or correlation
statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,627 registry
identities, 1,296 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`.
After deterministic allocation it found only the expected slug and strategy-
ID self-hits for `QM5_41128`. Evidence is in the pre- and post-allocation
receipts under `artifacts/`.

Manual family review fixes the mechanical boundaries:

- rolling ratio, OLS, quantile, and MAD cards estimate a center, coefficient,
  scale, or crossing. This card estimates none.
- `QM5_20249_xauxag-vr-spread` estimates lag dependence across 32 monthly
  relative returns and switches direction by persistence state. This card
  uses one month of daily relative returns, a fixed positive-memory gate, and
  only reversion.
- `QM5_41112_xauxag-mdaybreadth-rv` counts daily signs and discards
  magnitudes. Fixed-block cards aggregate halves or thirds, and `QM5_41121`
  orders state transitions. This card uses centered adjacent return products
  and no count, block, vote, range, or extreme state.
- `QM5_41123_xauxag-mpath-eff-rv` divides net displacement by an L1 path and
  `QM5_41125_xauxag-mrms-coherence-rv` divides net displacement by an L2
  path. Neither measures adjacent dependence or applies the fixed short-
  sample neutralization.
- `QM5_41127_wti-mdaily-persist-mom` follows the same governed statistic on
  one outright WTI leg. This card applies it to a synchronized gold/silver
  relative series, fades the endpoint, and owns an atomic equal-notional
  two-leg package.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback.

The paired carrier, exact completed month, older boundary pair, every relative
return ending in the month, centering, variance and adjacent-product sums,
fixed correction, strict positive score, contrarian sides, durable attempt,
equal-notional aggregate-risk package, and next-month exit are jointly load
bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_PERSISTENCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host: exact `XAUUSD.DWX`, D1, slot 0, magic `411280000`.
- Companion: exact `XAGUSD.DWX`, D1, slot 1, magic `411280001`.
- Logical symbol: `QM5_41128_XAU_XAG_MDAILY_PERSIST_RV_D1`.
- Decision: first synchronized executable tick of a new broker-calendar
  month, within 180 elapsed minutes of the raw current host D1 bar open.
- Signal data: exact immediately completed synchronized calendar month plus
  one adjacent older boundary pair; current-month prices are excluded.
- Position count: zero or one valid two-leg package and at most one consumed
  attempt per broker `yyyymm`.
- Expected frequency: six packages/year as an ordering prior within a 5-7
  design range; Q02 must prove at least five in every scored full year.

## Completed-Month Contract

The immediately preceding synchronized pair must belong to the prior calendar
month. Within a fixed 45-bar buffer, collect every completed D1 pair labeled
with that prior year and month. Require 17 through 23 unique timestamps in
strict order and one adjacent older synchronized pair proving that the package
was not truncated. A current-month pair, duplicate or mismatched timestamp,
wrong month, missing boundary proof, invalid close, or session count outside
17-23 consumes the current month flat.

For older boundary ratio `s[-1]`, chronological completed-month ratios
`s[0]..s[n-1]`, and `n` relative returns:

```text
s[j] = ln(XAU_close[j]) - ln(XAG_close[j])
r[j] = s[j] - s[j-1], j=0..n-1
N    = sum(r[j])
mu   = N / n
S    = sum((r[j] - mu)^2)
A    = sum((r[j] - mu) * (r[j-1] - mu)), j=1..n-1
rho  = A / S
J    = rho + 1/(n-1)

J > 0 and N > 0 => SELL XAU, BUY XAG
J > 0 and N < 0 => BUY XAU, SELL XAG
otherwise       => FLAT
```

Require positive finite closes, finite ratios, returns and sums, `S>0`, and
`rho` in `[-1,1]` within `1e-10`. Verify `N` equals the direct log-ratio move
from the older boundary pair to the completed month's final pair within
`1e-10`. Exact-zero constituent returns are valid. Zero variance, zero net,
`J<=0`, endpoint mismatch, and invalid numerical state are flat. Every
relative return ending in the month contributes exactly once. No current-
month price enters the formula.

## Rules

The entry, exit, filter, and management contracts below are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

1. Repair malformed or partial owned exposure before entry-only filters.
2. Require exact symbols, D1, EA ID, slots, risk mode, news modes, Friday-close
   inputs, and synchronized current host/companion bars.
3. Observe a new host D1 bar and derive current broker `yyyymm` from its raw
   bar time.
4. Admit only within `strategy_entry_grace_minutes=180` elapsed minutes of raw
   host-bar open. Late attachment consumes the month flat.
5. Persist current `yyyymm` before history, aggregation, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry that month.
6. Aggregate the exact immediately completed synchronized broker month.
   Require 17 through 23 valid pairs and one older boundary pair.
7. Build chronological gold-minus-silver log-ratio returns ending on every
   completed-month session. Require finite `N`, `S>0`, bounded `rho`, finite
   `J`, and endpoint identity.
8. Require strict `J>strategy_persistence_threshold=0.0` and nonzero `N`.
9. Fade positive `N` with SELL XAU / BUY XAG and negative `N` with BUY XAU /
   SELL XAG. Equality, invalid state, and nonpositive-score state remain flat.
10. Require XAU spread no greater than 1,500 points, XAG spread no greater than
    500 points, valid quotes, and valid completed-bar `ATR(20,D1)` on both legs.
11. Freeze one hard stop `3.5*ATR` from each leg's entry and use no target.
12. Size to equal target absolute USD notionals with combined normalized stop
    risk at or below the single aggregate `RISK_FIXED` budget. Reject a package
    whose realized notional mismatch exceeds 20%.
13. Submit the first leg then the second; if the second leg fails or the pair
    is malformed, close all owned exposure immediately. No same-month retry.

Persistence score and displacement magnitude never change the fixed risk
budget or target notionals.

### Attempt And Restart Contract

The attempt key is terminal-global, scoped by EA and logical basket, and stores
the current broker `yyyymm`. It is written before every fallible gate.
Initialization after the 180-minute grace consumes the missed month without a
late trade. Owned deal history and open-position checks are additional fail-
closed guards. An order rejection, atomic repair, stop-out, news block, spread
failure, restart, invalid ATR, or invalid history cannot create a same-month
retry.

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
  `41128`, and slots 0/1.
- Require `RISK_FIXED>0`, `RISK_PERCENT=0`, valid stop inputs, news temporal
  OFF, news compliance NONE, and Friday close disabled.
- Framework kill switch, broker, and ownership controls remain authoritative.
- Apply entry grace, durable attempt, exact synchronized calendar month,
  history and close validity, persistence arithmetic, spread ceilings,
  quotes, completed ATRs, sizing, notional mismatch, and atomicity fail closed.
- No fitted center, scale, z-score, regression, quantile, rank, moving average,
  oscillator, sign count, block vote, sequence count, range location, volume,
  open interest, event calendar, futures curve, external file, API, or manual
  runtime input is used.

## 7. Trade Management Rules

- Own either zero exposure or exactly one valid opposite-side two-leg package
  on registered magics and symbols.
- Flatten orphaned, duplicated, same-side, stopless, wrong-side, or notional-
  invalid exposure before considering a new entry.
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
| `strategy_min_month_sessions` | 17 | minimum completed-month pairs/returns |
| `strategy_max_month_sessions` | 23 | maximum completed-month pairs/returns |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_sample_bias_adjustment` | true | require fixed `1/(n-1)` shift |
| `strategy_persistence_threshold` | 0.0 | strict corrected-score gate |
| `strategy_numerical_tolerance` | 1e-10 | endpoint and correlation tolerance |
| `strategy_atr_period_d1` | 20 | completed D1 stop estimator |
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
interpretation, commodity return-memory concept, monthly clock, and auditable
lag-one persistence statistic. It does not supply the daily-ratio horizon,
fixed correction on relative returns, or contrarian direction.

## QM Interpretations

`SCHWEIKERT-MEHLITZ-CME-XAUXAG-MDAILY-PERSIST-RV-2026_S01` fixes synchronized
broker-month labels, 17-to-23 pairs plus the older boundary, every relative
return ending in the month, centering, adjacent-product inclusion, fixed
`1/(n-1)` correction, strict positive gate, fade direction, continuous-CFD
mapping, equal-notional aggregate fixed risk, entry grace, persistent attempt,
spread caps, atomicity, and lifecycle.

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
framework position/deal state, and persistent terminal-global attempt state.
No finite external dataset or event calendar exists.

## Risk

- Backtest only: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Equal target absolute USD notionals with at most 20% realized mismatch.
- Frozen hard stop: `3.5*ATR(20,D1)` on each leg; normalized per-leg risk sums
  to no more than the one aggregate fixed-risk budget.
- No target, convergence exit, or signal-strength sizing.
- Major risks are structural ratio breaks, persistent-move continuation,
  calendar mismatch, continuous-CFD roll/basis, financing, asymmetric spread
  and fill, orphan exposure, density below the floor, and realized book
  correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Kill Criteria

- Retire at zero packages or below five completed packages in any full post-
  warm-up scored year.
- Fail on wrong month labels, missing boundary pair, wrong session count,
  current-month leakage, reversed/omitted/duplicated relative return, wrong
  centering, variance, adjacent-product sum, correction, strict gate, endpoint
  identity, sides, repeated attempt, aggregate risk, atomicity, notional
  mismatch, hold beyond forty days, missing stop, invalid fixed-risk mode, or
  nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the carrier, correction, threshold,
  direction, return inclusion, risk, stops, hold, spread, retry policy, or by
  adding another signal or sweep.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS_WITH_PATH_HORIZON_AND_DIRECTION_TRANSLATION_RISK | Peer-reviewed gold/silver and commodity-memory DOI lineage, official CME carrier, complete-read evidence, durable hashes, and all translations disclosed. |
| R2 | PASS | Exact synchronization, boundary pair, month clock, return arithmetic, centering, variance, adjacent-product sum, correction, endpoint identity, sides, attempt, shared risk, stops, atomicity, spread gates, and lifecycle. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 history and MT5 state supply every runtime field. |
| R4 | PASS | Deterministic timestamp, price, logarithm, addition, multiplication, division, comparison, and execution-state arithmetic only; no trained or adaptive signal. |

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five completed
packages in any full post-warm-up year, nonpositive governed economics,
unsynchronized or wrong month membership, wrong relative-return orientation
or count, wrong `N`, `mu`, `S`, `A`, `rho`, or `J`, accepting `S=0`, endpoint
mismatch, accepting equality at zero, wrong side, late or repeated attempt,
missing hard stop, aggregate-risk breach, notional mismatch above 20%, orphan
survival, wrong next-month close, nondeterminism, or invalid fixed-risk mode.

Changing the carrier, month package, statistic, correction, threshold,
direction, attempt clock, equal-notional contract, risk, stops, or lifecycle
requires a new identity and full G0/Q01 cycle. A failed result may not be
rescued by adding a center, scale, z-score, sign count, block vote, sequence
state, range location, volatility, calendar, volume, event, external, or
prior-result filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/companion/period, synchronized month, persistence arithmetic, attempt, spread, ATR, paired sizing | Trade Entry | `Strategy_EntrySignal` plus deterministic basket helpers |
| malformed/orphan repair, later-month and stale closure | Trade Management | `Strategy_ManageOpenPosition` plus package lifecycle helper |
| next-month and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, aggregate fixed-risk mode | Framework No-Trade | standard framework orchestration plus paired ownership checks |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove first-month-bar and 180-minute timing; synchronized months and
year boundaries; exact immediately completed package; 17/20/23-pair
acceptance and 16/24 rejection; older boundary proof; oldest-to-newest ratios;
every month-ending return once; positive and negative `N`; zero constituent
returns accepted; `S=0` and `N=0` flat; endpoint identity; `rho` and `J` below,
equal to, and above zero; fixed bias correction; numerical tolerance;
contrarian sides; no current-month leakage; persistent monthly attempts;
equal-notional aggregate fixed-risk sizing; second-leg failure cleanup;
orphan and malformed repair; next-month and stale closure; card lint; strict
compile; logical setfile and basket-manifest schema; resolver identity; and
static artifact validation.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-23 | initial XAU/XAG completed-month daily-persistence reversion card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-23 | APPROVED | `decisions/2026-08-23_qm5_41128_xauxag_monthly_daily_persistence_reversion_g0.md` |
| Q01 Build Validation | 2026-08-23 | PENDING_BUILD | source implementation and strict compile required |
| Q02 Baseline Screening | 2026-08-23 | NOT_ENQUEUED_Q01_PENDING | strict compile, EX5, final set binding, basket manifest, and Q01 PASS required |

## Safety Boundary

This card requests a branch-only non-live build, Q01 validation, one logical
D1 `RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only
below tester and CPU ceilings. It does not authorize a manual backtest,
terminal control, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio-gate change, portfolio
admission, decorrelation claim, or correlation waiver.
