---
card_schema_version: 2
type: strategy
strategy_id: HOLLSTEIN-AGGVOL-2021_XTI_TS_S02
variant_id: HOLLSTEIN-AGGVOL-2021_XTI_TS_S02
source_id: HOLLSTEIN-WTI-VOLBETA-REG-2026
ea_id: QM5_20303
slug: wti-volbeta-reg
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20303_wti-volbeta-reg_card.md
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
    location: "DOI https://doi.org/10.1142/S2010139221500178; complete-paper evidence strategy-seeds/sources/HOLLSTEIN-AGGVOL-2021/source.md; bounded extraction strategy-seeds/sources/HOLLSTEIN-WTI-VOLBETA-REG-2026/source.md"
    quality_tier: A
    role: primary_smooth_aggregate_volatility_beta_formula_high_minus_low_direction_and_monthly_cadence
strategy_mechanic: monthly-wti-self-relative-two-disjoint-272-return-smooth-common-energy-volatility-beta-high-minus-low-regime
sources:
  - "[[sources/HOLLSTEIN-WTI-VOLBETA-REG-2026]]"
concepts:
  - "[[concepts/aggregate-volatility-risk-premium]]"
  - "[[concepts/smooth-volatility-beta]]"
  - "[[concepts/crude-oil-structural-premium]]"
indicators:
  - "[[indicators/realized-volatility]]"
  - "[[indicators/ordinary-least-squares]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, smooth-volatility-beta, factor-sensitivity, self-relative-regime, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
read_only_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 203030000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly WTI positions/year after the 545-close synchronized warm-up because only a numerical tie or invalid state stays flat; Q02 must prove at least five completed positions/year or retire."
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
q02_status: NOT_ENQUEUED
review_focus: "Falsify an outright WTI monthly smooth common-energy volatility-beta regime whose two own-history coefficient blocks differ from the existing paired energy rank, WTI realized-VoV, tail, moment, trend, calendar, event, and XNG oscillator neighbors; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exactly_545_synchronized_completed_closes, two_disjoint_272_return_blocks, block_local_inverse_volatility_weights, sample_standard_deviations, exact_20_return_rv, two_sigma_jump_zeroing, exact_252_row_three_column_ols, at_least_200_smooth_days, self_relative_high_beta_direction, xng_read_only, monthly_attempt_state, risk_mode_dual, friday_close_disabled, option_realized_proxy, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-13_qm5_20303_wti_volbeta_reg_g0.md: R1 tier-A peer-reviewed complete-read source with explicit WTI membership, smooth-volatility-beta construction, positive high-minus-low orientation, weak multiple-testing result, and sibling Q08 failure preserved; R2 locked synchronized two-block factor/OLS estimator and monthly lifecycle; R3 registered XTI/XNG D1 route with XNG read-only; R4 deterministic native arithmetic. No exact identity across 4,368 registry rows and 479 cards; one expected source-family fuzzy neighbor was manually resolved."
---

# QM5_20303 WTI Self-Relative Smooth-Volatility-Beta Regime

## Hypothesis

WTI's sensitivity to changes in common energy volatility can move through
slow physical-market regimes as production, inventories, transport, refining,
hedging, policy, and demand conditions change. If the source's positive high-
smooth-volatility-beta relation has a price-native time-series analogue, WTI
may earn a positive premium when its recent smooth common-energy volatility
beta exceeds its preceding state and a negative premium when it falls below.

The direct crude-oil carrier and factor-sensitivity state differ from the
certified XAU, SP500, NDX, and XNG book. That does not prove decorrelation,
profitability, or portfolio suitability. Q02 owns density and economics;
unchanged later gates, especially Q09, own robustness and realized overlap.

## Source Traceability And Claim Boundary

The source of record is the bounded packet
`strategy-seeds/sources/HOLLSTEIN-WTI-VOLBETA-REG-2026/source.md`. Its
content-bound parent records the complete accepted article and online appendix
for Hollstein, Prokopczuk, and Tharann (2021), a peer-reviewed *Quarterly
Journal of Finance* article. The source defines an option-derived aggregate
smooth-volatility beta, controls for equity-market return, renews monthly, and
reports a positive high-minus-low commodity spread that does not clear its
paper-wide multiple-testing threshold.

The source does not test a realized two-CFD factor, two own-history blocks, an
outright WTI rule, continuous CFDs, fixed-dollar risk, or the QM book. Every
such element is a disclosed translation. No source return, alpha,
significance, WTI-only effect, drawdown, cost, trade count, CFD equivalence, or
correlation statistic transfers.

The paired proxy parent `QM5_13151_energy-volbeta` recorded Q02 PF 1.46, net
profit 1,894.48, and 46 trades and passed through Q07. It failed Q08 hard on a
runs-test p-value of `0.02295` and lost money in the low-volatility regime.
Those facts are adverse family evidence, not a waiver or repair rationale.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,368 EA-registry rows and 479
cards. It found no exact identity and one expected source-family fuzzy match.
Manual review separates the mechanics:

- `QM5_13151_energy-volbeta` estimates XTI and XNG betas concurrently in one
  272-return block, ranks them, trades both legs, splits package risk, and
  repairs orphans. This card estimates WTI beta in two disjoint history blocks,
  compares recent with preceding, owns one WTI leg, and treats XNG as read-only.
- `QM5_20298_wti-vov-regime` measures dispersion-over-mean across nested WTI
  realized-volatility levels. It has no common-energy factor, jump exclusion,
  return regression, or beta coefficient.
- WTI MAX, expected-shortfall, ALIQ, skewness, kurtosis, trend, calendar,
  event, breakout, reversal, variance-ratio, and robust-location EAs use
  different information objects or clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG oscillator
  pullback rather than a monthly WTI factor-sensitivity state.

The synchronized XTI/XNG inputs, block-local inverse-volatility weights,
20-return sample-volatility changes, fixed two-sigma zeroing, intercept plus
two-regressor OLS, offsets `0/272`, high-beta direction, outright WTI topology,
and consumed monthly lifecycle are jointly load-bearing. Verdict:
`CLEAN_AUTHORIZED_WTI_TIME_SERIES_SMOOTH_VOL_BETA_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Formula

- Host/traded symbol: `XTIUSD.DWX`, D1, slot 0, intended magic `203030000`.
- Read-only factor input: `XNGUSD.DWX`, D1, with no magic or order authority.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: exactly 545 synchronized completed D1 closes, newest endpoint
  before the decision bar and at most ten calendar days stale.
- Holding clock: next broker-month boundary, with a forty-day stale guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions/year.

```text
544 chronological simple returns split into:
preceding block = indices 0..271
recent block    = indices 272..543

For each block independently:
rank span                 = indices 20..271
w_i                       = inverse(sample_sd_i) / sum inverse sd
m_t                       = w_XTI*r_XTI,t + w_XNG*r_XNG,t
RV20_t                    = sample_sd(m_[t-19..t])
smooth_t                  = 0 on abs(m_t-mean_m) >= 2*sample_sd_m
                            else RV20_t - RV20_[t-1]
r_XTI,t                   = alpha + beta_energy*m_t
                            + beta_smooth*smooth_t + error_t
```

Buy when `beta_recent > beta_preceding + 1e-12`; sell when
`beta_recent < beta_preceding - 1e-12`; remain flat on a tie or invalid state.
Beta magnitude never scales risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to log returns, equal/pooled weights, population
standard deviations, alternate RV windows, fitted jump thresholds, dropped
jump rows, regularized regression, trend/calendar filters, external series,
or prior pipeline results.

## 4. Entry Rules

1. Require exact EA ID 20303, `XTIUSD.DWX` D1, magic slot 0, read-only
   `XNGUSD.DWX`, and every locked input.
2. Process lifecycle exits before entry-only gates and evaluate only after a
   genuine broker-month transition.
3. Persist the month as consumed before history, signal, spread, quote, news,
   ATR, sizing, or order checks. No outcome may retry that month.
4. Reject owned exposure or any same-month entry deal for the WTI magic.
5. Load exactly 545 completed closes per symbol. Require exact timestamp
   synchronization, strict chronology, positive finite closes, and a fresh
   completed endpoint before the decision bar.
6. Form exactly 544 chronological simple returns and split at offset 272 so
   the two blocks share only their boundary close and no return.
7. For each block independently, calculate inverse-volatility weights from
   indices 20..271 using sample standard deviations, then form all 272 common-
   energy returns.
8. Calculate the block factor mean/sample deviation, 20-return rolling sample
   deviations, fixed two-sigma jump zeroing, and exactly 252 OLS rows. Require
   at least 200 non-jump rows and a full-rank finite solution.
9. Buy strictly above the preceding beta by more than `1e-12`; sell strictly
   below it; a tie consumes the month flat.
10. Require spread in `[0,1500]` points, executable quote, completed
    `ATR(20,D1)`, and valid contract metadata. Open at most one WTI market
    position with a frozen `3.5 * ATR(20,D1)` hard stop and no take-profit.

## 5. Exit Rules

1. Close the prior WTI position on the first processed D1 bar of every new
   broker month before considering replacement risk, even if direction is
   unchanged.
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
  incomplete/stale/misaligned history, wrong count, nonfinite return, invalid
  sample deviation or weights, too few smooth days, singular OLS, beta tie,
  excessive spread, invalid quote, unavailable ATR, invalid stop, or invalid
  contract metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not order XNG or read options, a futures chain, inventory,
  external files/APIs, analyst forecasts, trained output, optimizer results,
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
- XNG remains read-only. No randomness, adaptive fitting, external state,
  partial close, scale-in, grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_returns_per_block` | 272 | [272] | returns per independent beta block |
| `strategy_ols_observations` | 252 | [252] | exact rows per block regression |
| `strategy_recent_block_offset` | 272 | [272] | recent block's first chronological return |
| `strategy_history_bars_d1` | 545 | [545] | exact synchronized completed close count |
| `strategy_rv_window_d1` | 20 | [20] | rolling sample-volatility window |
| `strategy_jump_exclusion_z` | 2.0 | [2.0] | fixed jump-day zeroing threshold |
| `strategy_min_smooth_days` | 200 | [200] | minimum non-jump rows per block |
| `strategy_max_endpoint_gap_days` | 10 | [10] | completed-history freshness guard |
| `strategy_beta_tolerance` | 1e-12 | [1e-12] | symmetric block-comparison tolerance |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values, return type, block support, weighting, standard-deviation
denominators, jump handling, OLS design, direction, entry clock, risk, stop,
hold, and no-retry policy are locked. Any change requires a new card and
pipeline.

## Author Claims

Hollstein, Prokopczuk, and Tharann define aggregate smooth-volatility beta,
form monthly commodity portfolios, and report a positive high-minus-low
baseline spread. They do not claim that the realized XTI/XNG proxy reproduces
their option factor, that a two-block beta change predicts WTI, that a
continuous CFD reproduces collateralized futures, or that this candidate
diversifies the QM book. Their result does not clear the paper-wide multiple-
testing threshold.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: options-to-realized and cross-sectional-
to-time-series translation, endogenous two-CFD factor construction, block-
local weight drift, jump approximation, OLS conditioning, two-year warm-up,
persistent outright WTI states, continuous-CFD roll/financing effects,
sibling Q08 failure, stop slippage, and correlation with XNG or risk assets
can dominate the premise.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong close/return count, timestamp misalignment, overlapping
  returns, pooled/equal weights, population instead of sample deviations,
  wrong RV window, wrong jump threshold or row handling, fewer than 200 smooth
  days, singular OLS acceptance, low-beta-long direction, XNG order, repeated
  attempt, hold beyond forty days, missing hard stop, invalid risk mode, or
  nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing formation, blocks, weights, estimator,
  threshold, regression, direction, stop, hold, spread, retry, or carrier.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | Tier-A peer-reviewed source with DOI, complete-read evidence, weak inference, proxy caveat, and sibling Q08 failure disclosed. |
| R2 | PASS | Fixed synchronized blocks, inverse-volatility benchmark, 20-return smooth-volatility proxy, jump zeroing, OLS, direction, attempt, stop, rollover, and stale exit. |
| R3 | PASS | Registered XTI/XNG D1 closes; XNG is read-only and option-factor equivalence is not assumed. |
| R4 | PASS | Deterministic arithmetic only; no trained output, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: no exact identity; one fuzzy source-family neighbor was manually
  resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, XNG read-only contract,
  fixed-risk/news/Friday contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, exact synchronized histories, two
  block-local factors and OLS estimates, beta comparison, spread/quote/ATR/
  stop checks, and one fixed-risk WTI order.
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
| v1 | 2026-08-13 | initial WTI self-relative smooth-volatility-beta regime | G0 | APPROVED; build pending |
| v1-q01 | 2026-08-13 | deterministic V5 build, strict compile, synchronized-history guardrails, independent beta vectors, and P1 artifact validation | Q01 | PASS |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | APPROVED; R1-R4 PASS | `decisions/2026-08-13_qm5_20303_wti_volbeta_reg_g0.md`; bounded source packet |
| Q01 Build Validation | 2026-08-13 | PASS; strict compile 0 errors/0 warnings, build check 0 failures/0 warnings, 6 reference tests PASS, deploy verification PASS, P1 PASS | `D:/QM/reports/compile/20260813_094101/summary.csv`; `D:/QM/reports/framework/21/build_check_20260813_094101.json`; `D:/QM/reports/pipeline/QM5_20303/P1/P1_QM5_20303_result.json` |

