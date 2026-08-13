---
card_schema_version: 2
type: strategy
strategy_id: HOLLSTEIN-AGGJUMP-2021_XTI_TS_S02
variant_id: HOLLSTEIN-AGGJUMP-2021_XTI_TS_S02
source_id: HOLLSTEIN-WTI-JUMPBETA-REG-2026
ea_id: QM5_20304
slug: wti-jumpbeta-reg
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20304_wti-jumpbeta-reg_card.md
execution_contract_status: DRAFT
created: 2026-08-13
created_by: Research+Development
last_updated: 2026-08-13
g0_status: APPROVED
source_author: "Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann"
source_authors: "Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann; Duy B. B. Nguyen"
source_citation: "Hollstein, Prokopczuk, and Tharann (2021), Anomalies in Commodity Futures Markets, Quarterly Journal of Finance 11(4), article 2150017, DOI 10.1142/S2010139221500178."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Hollstein, F., Prokopczuk, M., and Tharann, B. (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), 2150017."
    location: "DOI https://doi.org/10.1142/S2010139221500178; complete-paper evidence strategy-seeds/sources/HOLLSTEIN-AGGJUMP-2021/source.md; bounded extraction strategy-seeds/sources/HOLLSTEIN-WTI-JUMPBETA-REG-2026/source.md"
    quality_tier: A
    role: primary_aggregate_jump_beta_formula_negative_high_minus_low_direction_and_monthly_cadence
  - type: peer_reviewed_paper
    citation: "Nguyen, D. B. B., and Prokopczuk, M. (2019). Jumps in Commodity Markets. Journal of Commodity Markets 13, 55-70."
    location: "DOI https://doi.org/10.1016/j.jcomm.2018.10.002"
    quality_tier: A
    role: supplementary_energy_jump_and_cojump_context_only
strategy_mechanic: monthly-wti-self-relative-two-disjoint-252-return-common-energy-jump-beta-low-minus-high-regime
sources:
  - "[[sources/HOLLSTEIN-WTI-JUMPBETA-REG-2026]]"
concepts:
  - "[[concepts/aggregate-jump-risk-premium]]"
  - "[[concepts/common-energy-jump-beta]]"
  - "[[concepts/crude-oil-structural-premium]]"
indicators:
  - "[[indicators/realized-jump-factor]]"
  - "[[indicators/ordinary-least-squares]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, common-jump-beta, factor-sensitivity, self-relative-regime, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
read_only_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 203040000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly WTI positions/year after the 505-close synchronized warm-up because only a numerical tie or invalid state stays flat; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify an outright WTI monthly common-energy jump-beta regime whose two own-history coefficient blocks differ from the existing paired energy rank, WTI smooth-vol beta, marginal tail/moment, trend, calendar, event, and XNG oscillator neighbors; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exactly_505_synchronized_completed_closes, two_disjoint_252_return_blocks, block_local_inverse_volatility_weights, sample_standard_deviations, fixed_two_sigma_realized_jump_factor, at_least_six_jump_rows, exact_252_row_three_column_ols, self_relative_low_beta_direction, xng_read_only, monthly_attempt_state, risk_mode_dual, friday_close_disabled, option_realized_proxy, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-13_qm5_20304_wti_jumpbeta_reg_g0.md: R1 tier-A peer-reviewed complete-read source with explicit WTI membership, aggregate-jump-beta construction, negative high-minus-low orientation, energy-jump supplement, and sibling Q08 failure preserved; R2 locked synchronized two-block factor/OLS estimator and monthly lifecycle; R3 registered XTI/XNG D1 route with XNG read-only; R4 deterministic native arithmetic. No exact identity across 4,369 registry rows and 480 cards; one expected source-family fuzzy neighbor was manually resolved."
---

# QM5_20304 WTI Self-Relative Common-Jump-Beta Regime

## Hypothesis

WTI's sensitivity to common energy jumps can move through slow physical-market
regimes as production, inventories, transport, refining, hedging, policy, and
demand conditions change. If the source's negative high-minus-low jump-beta
relation has a price-native time-series analogue, WTI may earn a positive
premium when its recent common-energy jump beta falls below its preceding
state and a negative premium when it rises above.

The direct crude-oil carrier and jump-sensitivity state differ from the
certified XAU, SP500, NDX, and short-horizon XNG book. That does not prove
decorrelation, profitability, or portfolio suitability. Q02 owns density and
economics; unchanged later gates, especially Q09, own robustness and realized
overlap.

## Source Traceability And Claim Boundary

The source of record is the bounded packet
`strategy-seeds/sources/HOLLSTEIN-WTI-JUMPBETA-REG-2026/source.md`. Its
content-bound parent records the complete accepted article and online appendix
for Hollstein, Prokopczuk, and Tharann (2021), a peer-reviewed *Quarterly
Journal of Finance* article. The source defines an option-derived aggregate
jump beta, controls for market return, renews monthly, and reports a negative
high-minus-low commodity spread. Nguyen and Prokopczuk (2019) supports only
the commodity/energy jump context.

The sources do not test a realized two-CFD factor, two own-history blocks, an
outright WTI rule, continuous CFDs, fixed-dollar risk, or the QM book. Every
such element is a disclosed translation. No source return, alpha,
significance, WTI-only effect, drawdown, cost, trade count, CFD equivalence, or
correlation statistic transfers.

## Family Evidence And Non-Duplicate Decision

The paired sibling `QM5_13147_energy-jumpbeta` passed through Q07 but failed
Q08 hard on runs-test `p=0.04487`; its low- and normal-volatility regime P&L
were negative. Its Q08 baseline PF 1.10 and 83 trades are adverse family
context, not inherited performance.

The canonical pre-allocation checker found no exact identity across 4,369
registry rows and 480 cards and surfaced the expected fuzzy sibling:

- `QM5_13147` estimates XTI and XNG betas concurrently in one block, ranks the
  two assets, trades both legs, and splits package risk. This card compares
  WTI beta across two disjoint blocks, trades only WTI, and makes XNG read-only.
- `QM5_20303_wti-volbeta-reg` fits a smooth rolling-volatility-change
  coefficient on non-jump days. This card fits the extreme-day jump residual
  coefficient itself and has no rolling-volatility series.
- WTI kurtosis, VoV, MAX, ES, ALIQ, trend, calendar, event, breakout,
  reversal, robust-location, and variance-ratio builds use other state
  objects or clocks. `QM5_12567` is a five-day long-only RSI pullback.

Verdict:
`CLEAN_AUTHORIZED_WTI_TIME_SERIES_COMMON_JUMP_BETA_AFTER_MANUAL_REVIEW`.

## Concept And Formula

On the first processed D1 host bar after a genuine broker-month transition,
load exactly 505 synchronized completed D1 closes for WTI and XNG. Form 504
chronological simple returns and split them into preceding `0..251` and recent
`252..503` blocks. The blocks share one boundary close and no return.

For each block independently:

```text
sd_XTI, sd_XNG = sample standard deviations over 252 returns
w_i             = inverse(sd_i) / sum inverse(sd_i)
m_t             = w_XTI*r_XTI,t + w_XNG*r_XNG,t
mean_m, sd_m    = mean and sample sd of m_t
jump_t          = m_t - mean_m if abs(m_t-mean_m) >= 2*sd_m, else 0
r_XTI,t          = alpha + beta_energy*m_t + beta_jump*jump_t + error_t
```

Use exactly 252 OLS rows and require at least six nonzero jump rows in each
block. Buy when recent jump beta is lower than preceding by more than `1e-12`;
sell when it is higher by more than `1e-12`. A tie or invalid state consumes
the month flat. Beta magnitude never scales risk.

## Markets And Timeframe

- Host/traded symbol: `XTIUSD.DWX`, D1, slot 0, magic `203040000`.
- Read-only factor input: `XNGUSD.DWX`, D1; never traded or assigned a magic.
- Decision: genuine broker-month transition after the 505-close warm-up.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Exit: next-month replacement, hard stop, or forty-day stale guard.
- Runtime inputs: native MT5 time, OHLC, ATR, spread, deal/position state, and
  contract metadata only.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to log returns, population deviations, equal/pooled
weights, alternate thresholds, dropped rows, regularized regression,
trend/calendar filters, external series, optimizer results, or portfolio
state.

## 4. Entry Rules

1. Require exact EA ID 20304, `XTIUSD.DWX` D1, magic slot 0, read-only
   `XNGUSD.DWX`, and every locked input.
2. Process lifecycle exits before entry-only gates and evaluate only after a
   genuine broker-month transition.
3. Persist the month as consumed before history, signal, spread, quote, news,
   ATR, sizing, or order checks. No outcome may retry that month.
4. Reject owned exposure or any same-month entry deal for the WTI magic.
5. Load exactly 505 completed closes per symbol. Require exact timestamp
   synchronization, strict chronology, positive finite closes, and a fresh
   completed endpoint before the decision bar.
6. Form exactly 504 chronological simple returns and split at offset 252 so
   the blocks share only their boundary close and no return.
7. For each block independently, calculate sample deviations, inverse-
   volatility weights, the common-energy factor, its sample mean/deviation,
   inclusive two-sigma jump residual, and exactly 252 OLS rows.
8. Require at least six jump rows and a full-rank finite solution in each
   block.
9. Buy strictly below the preceding jump beta by more than `1e-12`; sell
   strictly above it; a tie consumes the month flat.
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
  sample deviation or weights, fewer than six jumps, singular OLS, beta tie,
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
| `strategy_returns_per_block` | 252 | [252] | returns and OLS rows per independent block |
| `strategy_recent_block_offset` | 252 | [252] | recent block's first chronological return |
| `strategy_history_bars_d1` | 505 | [505] | exact synchronized completed close count |
| `strategy_jump_z` | 2.0 | [2.0] | inclusive realized-jump threshold |
| `strategy_min_jump_days` | 6 | [6] | minimum nonzero jump rows per block |
| `strategy_max_endpoint_gap_days` | 10 | [10] | completed-history freshness guard |
| `strategy_beta_tolerance` | 1e-12 | [1e-12] | symmetric block-comparison tolerance |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values, return type, block support, weights, sample-deviation denominator,
jump handling, OLS design, direction, entry clock, risk, stop, hold, and
no-retry policy are locked. Any change requires a new card and pipeline.

## Author Claims

Hollstein, Prokopczuk, and Tharann define aggregate jump beta, form monthly
commodity portfolios, and report a negative high-minus-low spread. They do not
claim that the realized XTI/XNG proxy reproduces their option factor, that a
two-block beta change predicts WTI, that a continuous CFD reproduces
collateralized futures, or that this candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: option-to-realized and cross-sectional-to-
time-series translation, endogenous two-CFD factor construction, block-local
weight drift, coarse D1 jump approximation, OLS conditioning, two-year warm-
up, persistent outright WTI states, continuous-CFD roll/financing effects,
sibling Q08 failure, stop slippage, and correlation with XNG or risk assets
can dominate the premise.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong close/return count, timestamp misalignment, overlapping
  returns, pooled/equal weights, population rather than sample deviations,
  wrong jump threshold or row handling, fewer than six jump rows, singular OLS
  acceptance, high-beta-long direction, XNG order, repeated attempt, hold
  beyond forty days, missing hard stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing formation, blocks, weights, estimator,
  threshold, regression, direction, stop, hold, spread, retry, or carrier.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | Tier-A peer-reviewed primary and supplementary sources with DOI, complete-read evidence, proxy caveat, and sibling Q08 failure disclosed. |
| R2 | PASS | Fixed synchronized blocks, inverse-volatility benchmark, two-sigma jump factor, OLS, direction, attempt, stop, rollover, and stale exit. |
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
compile/Q01, and one non-live paced Q02 handoff. It does not authorize a manual
backtest; live, demo, shadow, optimization, or stress setfile; AutoTrading;
`T_Live`; deploy or T_Live manifest; portfolio-gate change; portfolio
admission; or a correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-13 | initial WTI self-relative common-jump-beta regime | G0 | APPROVED; build pending |
| v1-q01 | 2026-08-13 | deterministic V5 build, strict compile, synchronized-history guardrails, independent jump-beta vectors, deployment verification, and P1 artifact validation | Q01 | PASS |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | APPROVED; R1-R4 PASS | `decisions/2026-08-13_qm5_20304_wti_jumpbeta_reg_g0.md`; bounded source packet |
| Q01 Build Validation | 2026-08-13 | PASS; strict compile 0 errors/0 warnings, build check 0 failures/0 warnings, 7 reference tests PASS, deploy verification PASS, P1 PASS | `D:/QM/reports/compile/20260813_104828/summary.csv`; `D:/QM/reports/framework/21/build_check_20260813_104828.json`; `D:/QM/strategy_farm/artifacts/deploy/QM5_20304_wti-jumpbeta-reg_deploy_20260813T104905Z.json`; `D:/QM/reports/pipeline/QM5_20304/P1/P1_QM5_20304_result.json` |
| Q02 Baseline Screening | - | NOT ENQUEUED | - |
