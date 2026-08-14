---
card_schema_version: 2
type: strategy
strategy_id: MOP-HOLLSTEIN-WTI-LOWDB-2026_S01
variant_id: MOP-HOLLSTEIN-WTI-LOWDB-2026_S01
source_id: MOP-HOLLSTEIN-WTI-LOWDB-2026
ea_id: QM5_21522
slug: wti-lowdb-trend
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_21522_wti-lowdb-trend_card.md
execution_contract_status: APPROVED
created: 2026-08-14
created_by: Research+Development
last_updated: 2026-08-14
g0_status: APPROVED
g0_decision: decisions/2026-08-14_qm5_21522_wti_lowdb_trend_g0.md
source_approval: decisions/2026-08-14_wti_lowdb_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250; Hollstein, Prokopczuk, and Tharann (2021), Quarterly Journal of Finance 11(4), article 2150017."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md; governed retrieval SHA-256 7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379"
    quality_tier: A
    role: exact_twelve_month_own_return_sign_direction_and_monthly_cadence
  - type: peer_reviewed_trading_paper
    citation: "Hollstein, F., Prokopczuk, M., and Tharann, B. (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), article 2150017."
    location: "DOI 10.1142/S2010139221500178; complete-paper evidence strategy-seeds/sources/HOLLSTEIN-DOWNBETA-2021/source.md"
    quality_tier: A
    role: downside_beta_definition_low_beta_orientation_monthly_cadence_and_null_evidence
strategy_mechanic: monthly-wti-exact-twelve-completed-month-return-sign-trend-gated-by-recent-below-preceding-two-disjoint-252-return-sp500-downside-beta
sources:
  - "[[sources/MOP-HOLLSTEIN-WTI-LOWDB-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/downside-beta]]"
  - "[[concepts/equity-decoupling-state]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/ordinary-least-squares]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, time-series-momentum, downside-beta, equity-decoupling-gate, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
read_only_symbols: [SP500.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 215220000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately five to seven completed WTI positions per full post-warm-up year because the monthly trend is admitted only in a strictly falling downside-beta state; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_ADVERSE_EVIDENCE
r2_mechanical: PASS
r3_data_available: PASS_FOR_DISCLOSED_PROXY
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: PENDING
review_focus: "Falsify a WTI twelve-month trend stream admitted only after a strict fall in SP500 downside beta across disjoint daily blocks; verify read-only factor discipline and preserve the DownBeta null. Q09 alone may establish realized decorrelation from XAU, SP500, NDX, and XNG."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_thirteen_consecutive_completed_wti_month_ends, exact_twelve_month_log_trend, exactly_505_synchronized_completed_beta_closes, two_disjoint_252_simple_return_blocks, block_local_sp500_means, strict_below_mean_down_days, minimum_100_down_days_per_block, intercept_ols_downside_beta, falling_recent_beta_gate, sp500_read_only, monthly_attempt_state, risk_mode_dual, friday_close_disabled, risk_free_zero_proxy, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-14_qm5_21522_wti_lowdb_trend_g0.md after durable source approval and atomic allocation: R1 two tier-A peer-reviewed complete-read sources with explicit WTI membership and the DownBeta null preserved; R2 locked independent monthly trend reconstruction plus synchronized disjoint-block conditional OLS gate and lifecycle; R3 registered XTI/SP500 D1 route with SP500 read-only; R4 deterministic native arithmetic. The canonical checker returned CLEAN across 4,394 registry rows and 490 cards; energy DownBeta, weak oil-gas correlation gating, unconditional TSMOM, factor-beta, tail, event, calendar, and XNG RSI families were manually separated."
---

# QM5_21522 WTI Low-Downside-Beta Trend

## Hypothesis

WTI trend returns may be more useful as a diversifying physical-energy sleeve
when crude oil has become less sensitive to equity-market downside than it was
in the preceding disjoint year. The candidate therefore follows WTI's exact
twelve-completed-month own-return sign only after a strict fall in its
SP500-conditioned downside beta.

This is a falsifiable composite, not a claim that a falling beta predicts
returns or guarantees low portfolio correlation. WTI supplies a different
physical-energy carrier from the certified XAU, SP500, NDX, and XNG book.
Q02 owns density and baseline economics; unchanged later gates, especially
Q09, own robustness and realized book overlap.

## Source Traceability And Claim Boundary

The governed composite packet is
strategy-seeds/sources/MOP-HOLLSTEIN-WTI-LOWDB-2026/source.md.

Moskowitz, Ooi, and Pedersen supply the twelve-month own-return-sign momentum
rule, monthly cadence, and WTI membership. Hollstein, Prokopczuk, and Tharann
supply the downside-beta information object: regress commodity return on
market return only when market return is below its own trailing mean. They
also supply the low-beta orientation.

The downside-beta source reports an insignificant characteristic, a null
cross-sectional slope, and unstable subperiod signs, and concludes that
DownBeta is mostly unpriced. That adverse evidence remains binding. It is used
only as a predeclared eligibility state for the separately sourced WTI trend.

Neither source tests the exact conjunction, two time-series beta blocks,
SP500 CFD proxy, risk-free-zero substitution, fixed-dollar risk, hard stop,
spread cap, continuous-CFD carrier, restart ledger, or QM book. No source
return, alpha, significance, drawdown, density, cost, CFD equivalence,
decorrelation, or portfolio result transfers.

## Non-Duplicate Decision

The canonical pre-allocation checker returned CLEAN across 4,394 EA-registry
rows and 490 root cards for the slug, strategy ID, author set, and complete
mechanic. Manual review separates the closest families:

- QM5_13203_energy-downbeta estimates concurrent XTI and XNG betas in one
  252-return block, ranks them, and trades an opposite-leg basket. This card
  compares two disjoint WTI beta histories, uses beta only as an admission
  gate, and trades one WTI leg in a separate twelve-month trend direction.
- QM5_21516_wti-decoup-trend admits WTI trend under weak absolute 63-D1
  XTI/XNG correlation. This card uses no XNG input; it uses SP500 down-day
  conditional beta in two 252-return blocks.
- Pure WTI time-series momentum trades every non-tied signal and has no
  equity-factor state. WTI volatility-beta, jump-beta, realized-VoV, tail,
  moment, robust-location, calendar, event, breakout, and reversal systems
  use different information objects or clocks.
- QM5_12567_cum-rsi2-commodity is a short-horizon, long-only XNG cumulative-
  RSI pullback above a slow price trend. It shares neither carrier, factor
  state, direction map, nor monthly lifecycle.

The independent WTI month-end trend, exact synchronized WTI/SP500 daily
intersection, block-local market means, strict down-day subsets, two OLS
slopes, falling-beta eligibility, WTI-only topology, and consumed monthly
attempt are jointly load-bearing. Verdict:
CLEAN_WTI_FALLING_DOWNSIDE_BETA_GATED_TWELVE_MONTH_TREND.

## Markets, Timeframe, And Formula

- Host and traded symbol: XTIUSD.DWX, D1, slot 0, magic 215220000.
- Read-only signal symbol: SP500.DWX, D1, with no magic or order authority.
- Decision: first processed host D1 bar after a genuine broker-month change.
- Trend formation: thirteen consecutive completed WTI broker-month endpoints.
- Beta formation: exactly 505 timestamp-intersected completed WTI/SP500 D1
  closes selected from bounded raw histories.
- Hold: until the next broker-month transition, with a forty-day stale guard.

The independent trend is:

    trend_12m = ln(WTI_latest_completed_month_end
                   / WTI_month_end_12_months_older)

For the 504 chronological synchronized daily simple-return pairs:

    preceding block = indices 0..251
    recent block    = indices 252..503

Within each block b:

    market_mean_b = arithmetic mean of all 252 SP500 returns
    down rows     = observations where r_SP500 < market_mean_b
    r_WTI         = alpha_b + beta_down_b * r_SP500 + error

Require at least 100 down rows and positive finite selected-market variance.
The demeaned covariance divided by variance is exactly the intercept OLS slope.

    eligible = beta_recent < beta_preceding - 1e-12
    BUY  when eligible and trend_12m > 0
    SELL when eligible and trend_12m < 0
    FLAT otherwise

Beta level and trend magnitude never scale risk.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. There is no fallback estimator or parameter sweep.

## 4. Entry Rules

1. Require exact EA ID 21522, XTIUSD.DWX D1 host, slot 0, magic 215220000,
   read-only SP500.DWX, and every locked baseline input.
2. Process malformed-position repair and prior-month liquidation before
   entry-only gates. Evaluate only after a genuine broker-month transition.
3. Persist the new broker month as consumed before history, signal, news,
   spread, quote, ATR, sizing, or order checks. No flat, blocked, failed,
   stopped, or closed decision may retry that month.
4. Reject any owned exposure or any same-month entry deal for this magic.
5. From an independent bounded WTI completed-D1 read, reconstruct exactly
   thirteen consecutive broker-month endpoints ending in the just-completed
   broker month. Reject missing, duplicate, current-month, stale, nonpositive,
   or nonfinite endpoints.
6. Compute the exact twelve-month log return from the oldest and newest
   retained endpoints. Verify it equals the sum of the twelve adjacent
   completed-month log returns within 1e-10.
7. Intersect bounded completed WTI and SP500 D1 histories by exact timestamps.
   Retain the newest exactly 505 common closes, require strict chronology,
   positive finite closes, and a newest common endpoint before the decision
   bar and no more than ten calendar days stale.
8. Form exactly 504 chronological simple-return pairs. Split at offset 252 so
   the preceding and recent blocks share only their boundary close and no
   return observation.
9. In each block independently, compute the mean of all 252 SP500 returns,
   retain only strict below-mean rows, require at least 100 selected rows, and
   estimate the intercept OLS WTI downside beta from selected-row covariance
   divided by selected-row SP500 variance.
10. Admit only when recent beta is below preceding beta by more than 1e-12.
    A beta tie, rising beta, invalid regression, or exact-zero trend consumes
    the month flat.
11. Buy for a positive admitted twelve-month trend and sell for a negative
    admitted trend. Require spread in [0,1500] points, executable quote,
    completed ATR(20,D1), valid stop distance, registered magic, and valid
    contract and volume metadata.
12. Open at most one WTI market position using exactly one RISK_FIXED=1000
    budget and a frozen 3.5 times ATR(20,D1) broker hard stop. There is no
    take-profit.

## 5. Exit Rules

1. Close the prior WTI position on the first processed D1 bar of each new
   broker month before evaluating replacement risk, even when the new
   direction would be unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Immediately close duplicate, wrong-symbol, invalid-type, or missing-stop
   exposure owned by the EA's magic.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source-aligned monthly hold spans
   weekends.
6. There is no intramonth beta or trend exit, target, trail, break-even,
   partial close, scale-in, grid, martingale, pyramid, or discretionary exit.

## 6. Filters (No-Trade Module)

- Fail closed outside exact host symbol, D1 timeframe, EA ID, slot,
  fixed-risk contract, news/Friday contract, or locked strategy inputs.
- Reject a consumed month, owned or same-month exposure, missing or
  nonconsecutive WTI month end, stale or misaligned daily history, wrong
  close/return count, nonfinite return, overlapping blocks, wrong block-local
  mean, fewer than 100 down days, zero selected-market variance, nonfinite
  beta, non-falling beta, zero trend, excessive spread, invalid quote, ATR,
  stop, magic, contract, or volume state.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  and position repair run before entry-only gates.
- Runtime may not order SP500 or read a risk-free series, CRSP data, futures
  chain, inventory, external file or API, analyst forecast, trained output,
  optimizer result, or portfolio state.

## 7. Trade Management Rules

- Maintain at most one correctly typed XTIUSD.DWX position under slot 0 and
  one consumed attempt per broker month.
- Preserve the original broker hard stop; close before monthly replacement or
  after forty calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history. Tester initialization clears only a future-dated
  marker so historical runs remain deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, invalid-type, or
  missing-stop exposure before any new entry logic.
- SP500 remains read-only. No randomness, PnL-adaptive fit, external state,
  partial close, scale-in, grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| strategy_trend_months | 12 | [12] | exact completed-month WTI trend horizon |
| strategy_trend_history_bars_d1 | 500 | [500] | bounded independent WTI month-end reconstruction |
| strategy_beta_returns_per_block | 252 | [252] | returns in each downside-beta block |
| strategy_beta_recent_block_offset | 252 | [252] | recent block's first chronological return |
| strategy_beta_common_closes | 505 | [505] | exact synchronized WTI/SP500 close count |
| strategy_beta_history_bars_d1 | 900 | [900] | bounded raw history intersection buffer |
| strategy_min_down_days | 100 | [100] | minimum strict below-mean rows per block |
| strategy_beta_tolerance | 1e-12 | [1e-12] | strict falling-beta comparison tolerance |
| strategy_variance_epsilon | 1e-16 | [1e-16] | selected-market variance floor |
| strategy_max_endpoint_gap_days | 10 | [10] | completed daily-history freshness guard |
| strategy_atr_period_d1 | 20 | [20] | completed WTI stop estimator |
| strategy_atr_sl_mult | 3.5 | [3.5] | frozen hard-stop multiple |
| strategy_max_hold_days | 40 | [40] | monthly stale guard |
| strategy_max_spread_points | 1500 | [1500] | WTI entry spread ceiling |

Every return type, month mapping, common-timestamp rule, block offset,
down-day inequality, row floor, denominator, beta direction, trend direction,
risk, stop, hold, spread, and retry rule is locked.

## Author Claims

Moskowitz, Ooi, and Pedersen define own-return-sign time-series momentum and
report broad futures evidence for the twelve-month rule. Hollstein,
Prokopczuk, and Tharann define DownBeta and monthly commodity sorts, but their
DownBeta return is insignificant and unstable. Neither source claims that a
fall in WTI's raw-SP500 downside beta makes WTI trend profitable, equivalent
to its futures construction, or uncorrelated with the QM book.

## Risk

Q02-Q10 use exactly RISK_FIXED=1000, RISK_PERCENT=0, and PORTFOLIO_WEIGHT=1.
Risk is high: the cross-source conjunction is novel; the DownBeta source is a
null; raw SP500 CFD return is not CRSP market excess return; the risk-free
rate is omitted; only about half of monthly signals may be eligible; WTI roll,
financing, gaps, and geopolitics remain; conditional OLS can be unstable;
hard stops can slip; and low downside beta does not remove full-sample equity
or XNG overlap.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full
  post-warm-up year.
- Fail on wrong month mapping, fewer or more than thirteen endpoints, wrong
  close or return count, timestamp mismatch, shared return across blocks,
  simple/log return substitution, pooled block means, non-strict down-day
  selection, fewer than 100 selected rows, population-only shortcut,
  singular regression acceptance, wrong beta inequality, entry without the
  trend, repeated attempt, SP500 order, hold beyond forty days, missing hard
  stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing a window, block, estimator, threshold,
  direction, carrier, risk, stop, hold, spread, or retry rule.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS_WITH_ADVERSE_EVIDENCE | Two tier-A peer-reviewed papers with complete governed reads and explicit WTI coverage; the DownBeta null is retained. |
| R2 | PASS | Independent month-end trend, exact synchronized disjoint beta blocks, strict conditional OLS gate, attempt state, stop, rollover, and stale exit are fixed. |
| R3 | PASS_FOR_DISCLOSED_PROXY | Registered WTI/SP500 D1 closes supply every runtime input; SP500 is read-only and CRSP/risk-free fidelity is not assumed. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: deterministic CLEAN; manual review separates paired energy
  DownBeta, oil-gas correlation-gated trend, unconditional TSMOM, factor-beta,
  tail, event, calendar, and XNG oscillator families.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, SP500 read-only contract,
  fixed-risk/news/Friday contract, and cheap parameter guards.
- trade_entry: consumed monthly attempt, independent WTI month-end trend,
  synchronized WTI/SP500 intersection, two block-local downside betas, strict
  eligibility, spread/quote/ATR/stop checks, and one fixed-risk WTI order.
- trade_management: malformed-state repair, broker-month exit, and forty-day
  stale exit before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, one XTIUSD.DWX D1 RISK_FIXED backtest setfile, and one paced
non-live Q02 handoff when CPU capacity permits. It does not authorize a manual
backtest; live, demo, shadow, stress, or optimization artifact; AutoTrading;
T_Live; deploy or T_Live manifest; portfolio-gate change; portfolio
admission; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-14 | initial WTI falling-downside-beta-gated twelve-month trend | G0 | APPROVED; build pending |
| v2 | 2026-08-14 | implement locked disjoint-block downside-beta gate and WTI lifecycle | Q02 | Q01 PASS; Q02 enqueued |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-14 | APPROVED; R1-R4 PASS with DownBeta null | decisions/2026-08-14_qm5_21522_wti_lowdb_trend_g0.md; governed composite source packet |
| Q01 Build Validation | 2026-08-14 | PASS | strict compile 0/0; build check 0/0; seven reference tests; P1 artifact PASS |
| Q02 Baseline Screening | 2026-08-14 | ENQUEUED; pending | work item `fe4d6ae0-b23e-401a-822d-bc8a83a2bdc2`; no tester dispatched by this build |
