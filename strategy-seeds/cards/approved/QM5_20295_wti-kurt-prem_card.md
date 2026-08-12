---
card_schema_version: 2
type: strategy
strategy_id: HOLLSTEIN-MAX-2021_XTI_TS_S05
variant_id: HOLLSTEIN-MAX-2021_XTI_TS_S05
source_id: HOLLSTEIN-WTI-KURT-2026
ea_id: QM5_20295
slug: wti-kurt-prem
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20295_wti-kurt-prem_card.md
execution_contract_status: DRAFT
created: 2026-08-13
created_by: Research+Development
last_updated: 2026-08-13
g0_status: APPROVED
source_author: "Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann"
source_authors: "Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann"
source_citation: "Hollstein, Prokopczuk, and Tharann (2021), Anomalies in Commodity Futures Markets, Quarterly Journal of Finance 11(4), article 2150017, DOI 10.1142/S2010139221500178."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Hollstein, F., Prokopczuk, M., and Tharann, B. (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), 2150017."
    location: "DOI https://doi.org/10.1142/S2010139221500178; complete accepted-manuscript evidence strategy-seeds/sources/HOLLSTEIN-MAX-2021/source.md; bounded extraction strategy-seeds/sources/HOLLSTEIN-WTI-KURT-2026/source.md"
    quality_tier: A
    role: primary_historical_kurtosis_formula_high_minus_low_direction_and_monthly_cadence
strategy_mechanic: monthly-wti-prior-252-simple-return-pearson-historical-kurtosis-normal-benchmark-three-premium
sources:
  - "[[sources/HOLLSTEIN-WTI-KURT-2026]]"
concepts:
  - "[[concepts/historical-kurtosis-premium]]"
  - "[[concepts/fourth-moment-risk-premium]]"
  - "[[concepts/crude-oil-structural-premium]]"
indicators:
  - "[[indicators/pearson-kurtosis]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, historical-kurtosis, fourth-moment-premium, time-series-premium, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202950000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly WTI positions/year after the 253-close warm-up because only benchmark-tie or invalid states stay flat; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01_PASS
q01_status: PASS
q02_status: NOT_STARTED
review_focus: "Falsify an outright monthly WTI fourth-moment premium around a fixed normal benchmark, unlike existing XTI/XNG and XAU/XAG kurtosis ranks, WTI skewness, semivariance, return trend/reversal, calendar, event, and XNG RSI neighbors; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exactly_252_simple_returns, source_variance_denominator, source_fourth_moment_denominator, pearson_not_excess_kurtosis, fixed_normal_benchmark, high_kurtosis_direction, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-13_qm5_20295_wti_kurt_prem_g0.md: R1 peer-reviewed QJF source with complete-read evidence, explicit WTI membership, and adverse robustness preserved; R2 exact 252-return Pearson historical-kurtosis estimator, fixed benchmark-three map, and monthly lifecycle; R3 registered WTI D1 route; R4 deterministic native arithmetic without trained output or prohibited signal indicator. No exact identity; seven fuzzy source-family neighbors were manually separated by carrier, statistic, or lifecycle."
---

# QM5_20295 WTI Historical-Kurtosis Premium

## Hypothesis

The source's cross-sectional high-kurtosis commodity premium may have a weak
time-series analogue in WTI: buy when prior-year Pearson historical kurtosis
is above the fixed normal benchmark of three and sell when it is below three.
The crude-oil carrier and fourth-moment state differ from the certified XAU,
SP500, NDX, and XNG book.

This is a low-prior falsification, not a profitability, significance,
decorrelation, certification, or portfolio-admission claim. WTI can remain
above the benchmark for long periods, so the rule may behave as persistent
outright crude exposure and later correlation gates remain decisive.

## Source Traceability And Claim Boundary

The trading source is Hollstein, Prokopczuk, and Tharann (2021), a peer-
reviewed QJF article with DOI and institutional accepted manuscript. The
complete-read parent and bounded WTI packet are identified in the metadata.

The paper specifies prior-year Pearson historical kurtosis, a monthly
cross-sectional sort, high-minus-low direction, and explicit WTI membership.
It does not test an absolute time-series benchmark. Its two-portfolio result
and regression slope are insignificant, and the later subperiod reverses sign
insignificantly. The benchmark-three map, continuous-CFD carrier, fixed risk,
ATR stop, spread cap, and lifecycle are QM translations. No source return,
alpha, drawdown, WTI-only result, cost, trade count, CFD equivalence, or
correlation statistic transfers.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,360 registry rows and 471 root
cards. It found no exact identity and seven expected fuzzy source-family
neighbors. Manual review separated them:

- `QM5_13131_energy-kurt-rank` and `QM5_20291_xauxag-kurt-rk` compute paired
  cross-sectional ranks with two histories, two magics, shared basket risk,
  and orphan repair. This card has one WTI state and one position.
- `QM5_20290_wti-skew-prem` uses a centered third standardized moment around
  zero and the low-skew direction. This rule uses a fourth central moment,
  source sample variance, benchmark three, and high-kurtosis direction.
- `QM5_13130_xti-xng-lowmax` and `QM5_20294_xauxag-max-rk` use only the five
  largest returns, not the full distribution's fourth moment.
- Legacy kurtosis EAs combine skew, daily scaling, or intraday composite
  states and do not trade a pure monthly outright-WTI kurtosis state.
- WTI cumulative-return, robust-location, path-efficiency, calendar, event,
  breakout, variance-ratio, and ordinary reversal EAs use different inputs.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback rather than a monthly fourth-moment premium.

The 252 simple returns, source denominators, Pearson fourth moment, fixed
benchmark three, high-kurtosis long/low-kurtosis short map, outright WTI
carrier, and monthly consumed attempt are jointly load-bearing. Verdict:
`CLEAN_AFTER_MANUAL_CROSS_SECTIONAL_TO_TIME_SERIES_REVIEW`.

## Markets, Timeframe, And Formula

- Exact symbol: `XTIUSD.DWX`, D1, slot 0, intended magic `202950000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: exactly 253 completed D1 closes and 252 chronological simple
  returns, with the newest endpoint before the decision bar and at most ten
  calendar days stale.
- Holding clock: next broker-month boundary, with a forty-day stale guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions/year.

```text
r[d] = close[d] / close[d-1] - 1
mu = sum(r[d]) / 252
s2 = sum((r[d] - mu)^2) / 251
m4 = sum((r[d] - mu)^4) / 252
kurtosis = m4 / (s2^2)
```

Buy above `3.0 + 1e-12`; sell below `3.0 - 1e-12`; remain flat inside the
tolerance or on invalid state. Magnitude never scales risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to excess kurtosis, skewness, semivariance, MAX, a rank,
raw return, trend, calendar direction, external series, or prior result.

## 4. Entry Rules

1. Require exact EA ID 20295, `XTIUSD.DWX` D1, magic slot 0, and every locked
   input.
2. Process lifecycle exits before entry-only gates and evaluate only after a
   genuine broker-month transition.
3. Persist the month as consumed before history, signal, spread, quote, news,
   ATR, sizing, or order checks. No outcome may retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Load bounded completed D1 history. Require exactly 253 closes, strictly
   increasing timestamps, positive finite prices, and a fresh completed
   endpoint before the decision bar.
6. Form exactly 252 simple returns in chronological older-to-newer orientation.
7. Compute the arithmetic mean, sample variance with denominator 251, fourth
   central moment with denominator 252, and Pearson kurtosis. Require finite
   arithmetic and variance above `1e-12`.
8. Buy strictly above `3.0 + 1e-12`; sell strictly below `3.0 - 1e-12`; the
   tolerance band consumes the month flat.
9. Require spread in `[0,1500]` points, executable quote, completed
   `ATR(20,D1)`, and valid contract metadata.
10. Open at most one market position with a frozen `3.5 * ATR(20,D1)` broker
    hard stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement risk, even if direction is unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Close duplicate, wrong-symbol, invalid-type, or missing-stop exposure owned
   by this EA's magic.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source-aligned hold spans weekends.
6. No intramonth flip, target, trail, break-even, partial close, scale-in,
   grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, slot, fixed-risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  incomplete or stale history, non-increasing timestamps, nonpositive close,
  wrong count, nonfinite return/moment, variance at or below `1e-12`, pivot
  tie, excessive spread, invalid quote, unavailable ATR, invalid stop, or
  invalid contract metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read a futures chain, options, inventory release, volume,
  open interest, file, API, analyst forecast, trained output, optimizer result,
  or portfolio state.

## 7. Trade Management Rules

- Maintain at most one WTI position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly replacement or after
  forty calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; tester initialization clears a future marker so
  historical runs remain deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, invalid-type, or missing-
  stop exposure before any new entry logic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_lookback_d1` | 252 | [252] | exact completed simple-return count |
| `strategy_history_bars` | 320 | [320] | bounded D1 history request |
| `strategy_max_endpoint_gap_days` | 10 | [10] | completed-history freshness guard |
| `strategy_variance_floor` | 1e-12 | [1e-12] | source sample-variance floor |
| `strategy_kurtosis_benchmark` | 3.0 | [3.0] | fixed Pearson normal pivot |
| `strategy_kurtosis_tolerance` | 1e-12 | [1e-12] | symmetric pivot tolerance |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values, denominators, pivot, direction, entry clock, risk, stop, hold, and
no-retry policy are locked. Any change requires a new card and pipeline.

## Author Claims

Hollstein, Prokopczuk, and Tharann define prior-year Pearson historical
kurtosis, report a positive full-sample cross-sectional relation, use monthly
sorts, and include WTI. They do not claim that benchmark three predicts WTI,
that a continuous CFD reproduces collateralized futures, or that this
candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: weak and unstable source evidence, the
cross-sectional-to-time-series translation, estimator bias around three,
persistent high-kurtosis/long-WTI states, crude gaps and rolls, CFD basis and
financing, fourth-moment noise, stop slippage, and correlation with XNG or
risk assets can dominate the premise.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong observation count/orientation, wrong estimator denominator,
  excess rather than Pearson kurtosis, fitted pivot, reversed direction,
  repeated attempt, hold beyond forty days, missing hard stop, invalid risk
  mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the formation, estimator, pivot,
  direction, stop, hold, spread, retry, or carrier.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | Tier-A peer-reviewed source with DOI, complete-read evidence, adverse robustness, and explicit WTI membership. |
| R2 | PASS | Fixed 252-return Pearson estimator, source denominators, benchmark, direction, attempt, stop, rollover, and stale exit. |
| R3 | PASS | Registered `XTIUSD.DWX` D1 plus native V5 execution state only. |
| R4 | PASS | Deterministic arithmetic only; no trained output, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: no exact identity; seven same-source/carrier fuzzy neighbors were
  manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, 253-close history, 252 simple
  returns, Pearson kurtosis state, spread/quote/ATR/stop checks, and one fixed-
  risk order.
- trade_management: malformed-state repair, broker-month exit, and stale exit
  before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff. It does not authorize a
manual backtest; live, demo, shadow, optimization, or stress setfile;
AutoTrading; `T_Live`; deploy or T_Live manifest; portfolio-gate change;
portfolio admission; or a correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-13 | initial WTI historical-kurtosis premium | G0 | APPROVED; build pending |
| v1-q01 | 2026-08-13 | deterministic V5 build, strict compile, target guardrails, independent kurtosis vectors, and P1 artifact validation | Q01 | PASS |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | APPROVED; R1-R4 PASS | durable decision and bounded source packet |
| Q01 Build Validation | 2026-08-13 | PASS; strict compile 0 errors/0 warnings, build check 0 failures/0 warnings, 5 reference tests PASS, P1 PASS | `D:/QM/reports/compile/20260812_231711/summary.csv`; `D:/QM/reports/framework/21/build_check_20260812_231710.json`; `D:/QM/reports/pipeline/QM5_20295/P1/P1_QM5_20295_result.json` |
| Q02 Baseline Screening | - | NOT STARTED | - |
