---
card_schema_version: 2
type: strategy
strategy_id: MOP-SILV-WTI-FALLCORR-2026_S01
variant_id: MOP-SILV-WTI-FALLCORR-2026_S01
source_id: MOP-SILV-WTI-FALLCORR-2026
ea_id: QM5_21527
slug: wti-fallcorr-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_21527_wti-fallcorr-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-15
created_by: Research+Development
last_updated: 2026-08-15
g0_status: APPROVED
g0_decision: decisions/2026-08-15_qm5_21527_wti_fallcorr_trend_g0.md
source_approval: decisions/2026-08-15_wti_fallcorr_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Annastiina Silvennoinen; Susan Thorp"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Annastiina Silvennoinen; Susan Thorp"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250; Silvennoinen and Thorp (2013), Journal of International Financial Markets, Institutions and Money 24, 42-65."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: twelve_month_own_return_sign_direction_monthly_cadence_and_wti_membership
  - type: peer_reviewed_correlation_paper
    citation: "Silvennoinen, A., and Thorp, S. (2013). Financialization, Crisis and Commodity Correlation Dynamics. Journal of International Financial Markets, Institutions and Money 24, 42-65."
    location: "DOI 10.1016/j.intfin.2012.11.007; complete 46-page institutional-preprint review and retrieval hash in strategy-seeds/sources/MOP-SILV-WTI-FALLCORR-2026/source.md"
    quality_tier: A
    role: time_varying_wti_equity_integration_and_adverse_diversification_context
strategy_mechanic: monthly-wti-exact-twelve-completed-month-return-sign-trend-gated-by-falling-absolute-pearson-correlation-across-two-disjoint-63-return-wti-sp500-blocks
sources:
  - "[[sources/MOP-SILV-WTI-FALLCORR-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/commodity-financialization]]"
  - "[[concepts/equity-decoupling-state]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/pearson-return-correlation]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, time-series-momentum, falling-equity-correlation, equity-decoupling-gate, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
read_only_symbols: [SP500.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 215270000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately five to seven completed WTI positions per full post-warm-up year because the monthly trend is admitted only when absolute WTI/SP500 correlation falls across adjacent disjoint blocks; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_FOR_DISCLOSED_PROXY
r2_mechanical: PASS
r3_data_available: PASS_FOR_DISCLOSED_PROXY
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify a WTI twelve-month trend admitted only after absolute WTI/SP500 correlation falls across disjoint daily blocks; verify SP500 stays read-only. Q09 alone may establish realized decorrelation from XAU, SP500, NDX, and XNG."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_thirteen_consecutive_completed_wti_month_ends, exact_twelve_month_log_trend, exactly_127_synchronized_completed_correlation_closes, two_disjoint_63_simple_return_blocks, block_local_means, sample_pearson_correlation, strict_falling_absolute_correlation_gate, sp500_read_only, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-15_qm5_21527_wti_fallcorr_trend_g0.md after durable source approval and atomic allocation: R1 two peer-reviewed complete-read sources with the untested conjunction and adverse correlation evidence explicit; R2 locked independent monthly trend reconstruction plus exact synchronized disjoint-block Pearson gate and lifecycle; R3 registered XTI/SP500 D1 route with SP500 read-only; R4 deterministic native arithmetic. The canonical checker returned CLEAN across 4,499 registry rows and 595 root-card files; WTI/XNG correlation gating, SP500 downside-beta gating, WTI/XAU sign divergence, energy DownBeta, oil-predicts-equity, unconditional TSMOM, and XNG RSI families were manually separated."
---

# QM5_21527 WTI Falling Equity-Correlation Trend

## Hypothesis

WTI trend may provide a more distinct physical-energy return stream when its
recent equity co-movement is weakening rather than strengthening. The
candidate follows WTI's exact twelve-completed-month own-return sign only
when the absolute Pearson correlation of WTI and SP500 D1 returns is strictly
lower in the recent 63-return block than in the preceding disjoint block.

This is a falsifiable composite. Falling sample correlation neither predicts
WTI returns nor proves portfolio decorrelation. Q02 owns trade density and
baseline economics; unchanged later gates, especially Q09, own robustness
and realized overlap with the certified XAU/SP500/NDX/XNG book.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/MOP-SILV-WTI-FALLCORR-2026/source.md`.

Moskowitz, Ooi, and Pedersen supply the twelve-month own-return-sign momentum
rule, monthly cadence, and WTI membership. Silvennoinen and Thorp establish
that WTI/equity correlation is time-varying and that financial integration
can reduce commodity diversification benefits.

Silvennoinen and Thorp use weekly collateralized multi-contract futures
returns, fitted conditional means and variances, and nonlinear transition
correlations. Their preferred WTI/S&P transition is crisis-timed rather than
VIX-driven. They do not test a trading filter or show that low or falling
correlation improves trend returns. The raw D1 Pearson proxy and the exact
conjunction are QM falsifications.

Neither source tests the two disjoint 63-return blocks, SP500 CFD proxy,
fixed-dollar risk, hard stop, spread cap, continuous-CFD carrier, restart
ledger, or QM book. No source return, alpha, significance, threshold,
drawdown, density, cost, CFD equivalence, decorrelation, or portfolio result
transfers.

## Non-Duplicate Decision

The canonical pre-allocation checker returned CLEAN across 4,499 registry
rows and 595 root-card files for the slug, strategy ID, author set, and
complete mechanic. Manual review separates the closest families:

- `QM5_21516_wti-decoup-trend` uses one 63-return WTI/XNG correlation block
  and a fixed 0.30 absolute ceiling. This card uses SP500, compares recent
  and preceding disjoint blocks, and has no fixed correlation-level ceiling.
- `QM5_21522_wti-lowdb-trend` estimates two 252-return conditional
  downside-beta slopes on below-mean SP500 days. This card uses all rows in
  two 63-return blocks and compares absolute Pearson correlations.
- `QM5_21523_wti-xau-div-tr` gates on opposite twelve-month WTI/gold return
  signs and contains no correlation estimator or equity factor.
- `QM5_13203_energy-downbeta` ranks and trades an XTI/XNG two-leg package.
  This card trades one WTI leg in its own time-series trend direction.
- `QM5_1178_qp-oil-equity-lag-sign` and `QM5_12397_oil-eq-reg` use oil
  information to trade equity indices. This card never orders SP500.
- Pure WTI time-series momentum enters every non-tied month and has no
  changing equity-correlation eligibility state.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG
  oscillator pullback; it shares neither carrier, direction, factor, nor
  cadence.

The independent WTI month-end trend, exact synchronized WTI/SP500 daily
intersection, two block-local Pearson correlations, strict absolute decline,
WTI-only topology, and consumed monthly attempt are jointly load-bearing.
Verdict:
`CLEAN_WTI_TREND_FALLING_ABSOLUTE_EQUITY_CORRELATION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Formula

- Host and traded symbol: `XTIUSD.DWX`, D1, slot 0, magic `215270000`.
- Read-only signal symbol: `SP500.DWX`, D1, with no magic or order authority.
- Decision: first processed host D1 bar after a genuine broker-month change.
- Trend formation: thirteen consecutive completed WTI broker-month endpoints.
- Correlation formation: exactly 127 timestamp-intersected completed
  WTI/SP500 D1 closes selected from bounded raw histories.
- Hold: until the next broker-month transition, with a forty-day stale guard.

The independent trend is:

```text
trend_12m = ln(WTI_latest_completed_month_end
               / WTI_month_end_12_months_older)
```

With common closes indexed newest first, form simple returns chronologically
and split the 126 returns without overlap:

```text
recent block    = newest 63 returns
preceding block = immediately prior 63 returns

rho_b = sum((r_wti - mean_wti_b) * (r_sp500 - mean_sp500_b))
        / sqrt(sum((r_wti - mean_wti_b)^2)
             * sum((r_sp500 - mean_sp500_b)^2))

eligible = abs(rho_recent) + 1e-12 < abs(rho_preceding)
BUY  when eligible and trend_12m > 0
SELL when eligible and trend_12m < 0
FLAT otherwise
```

Correlation level and trend magnitude never scale risk.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. There is no fallback estimator or parameter sweep.

## 4. Entry Rules

1. Require exact EA ID 21527, XTIUSD.DWX D1 host, slot 0, magic 215270000,
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
   completed-month log returns within `1e-10`.
7. Intersect bounded completed WTI and SP500 D1 histories by exact timestamp.
   Retain the newest exactly 127 common closes, require strict chronology,
   positive finite closes, and a newest common endpoint before the decision
   bar and no more than ten calendar days stale.
8. Form exactly 126 simple-return pairs. Split them into the newest 63 returns
   and immediately preceding 63 returns so the blocks share only their
   boundary close and no return observation.
9. In each block independently, compute both all-row sample means, demeaned
   sums of squares, and Pearson correlation. Require positive finite WTI and
   SP500 variance and a finite correlation within `[-1,1]` plus tolerance.
10. Admit only when the recent absolute correlation is below the preceding
    absolute correlation by more than `1e-12`. A tie, non-decline, invalid
    state, or exact-zero trend consumes the month flat.
11. Buy for a positive admitted twelve-month trend and sell for a negative
    admitted trend. Require spread in `[0,1500]` points, executable quote,
    completed ATR(20,D1), valid stop distance, registered magic, and valid
    contract and volume metadata.
12. Open at most one WTI market position using exactly one
    `RISK_FIXED=1000` budget and a frozen `3.5 * ATR(20,D1)` broker hard
    stop. There is no take-profit.

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
6. There is no intramonth correlation or trend exit, target, trail,
   break-even, partial close, scale-in, grid, martingale, pyramid, or
   discretionary exit.

## 6. Filters (No-Trade Module)

- Fail closed outside exact host symbol, D1 timeframe, EA ID, slot,
  fixed-risk contract, news/Friday contract, or locked strategy inputs.
- Reject a consumed month, owned or same-month exposure, missing or
  nonconsecutive WTI month end, stale or misaligned daily history, wrong
  close/return count, nonfinite return, overlapping return blocks, zero
  variance, nonfinite or out-of-range correlation, non-falling absolute
  correlation, zero trend, excessive spread, invalid quote, ATR, stop, magic,
  contract, or volume state.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  and position repair run before entry-only gates.
- Runtime may not order SP500 or read VIX, open interest, a futures chain,
  external file or API, analyst forecast, trained output, optimizer result,
  or portfolio state.

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
| `strategy_trend_months` | 12 | [12] | exact completed-month WTI trend horizon |
| `strategy_trend_history_bars_d1` | 500 | [500] | bounded independent WTI month-end reconstruction |
| `strategy_corr_returns_per_block` | 63 | [63] | returns in each Pearson block |
| `strategy_corr_recent_block_offset` | 0 | [0] | recent block's newest-first return offset |
| `strategy_corr_preceding_block_offset` | 63 | [63] | preceding block's newest-first return offset |
| `strategy_corr_common_closes` | 127 | [127] | exact synchronized WTI/SP500 close count |
| `strategy_corr_history_bars_d1` | 350 | [350] | bounded raw history intersection buffer |
| `strategy_corr_tolerance` | 1e-12 | [1e-12] | strict absolute-correlation decline and range tolerance |
| `strategy_variance_epsilon` | 1e-16 | [1e-16] | demeaned sum-of-squares floor |
| `strategy_max_endpoint_gap_days` | 10 | [10] | completed daily-history freshness guard |
| `strategy_atr_period_d1` | 20 | [20] | completed WTI stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop multiple |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

Every return type, month mapping, common-timestamp rule, block offset,
denominator, absolute-correlation direction, trend direction, risk, stop,
hold, spread, and retry rule is locked.

## Author Claims

Moskowitz, Ooi, and Pedersen define own-return-sign time-series momentum and
report broad futures evidence for the twelve-month rule. Silvennoinen and
Thorp document changing commodity/equity correlation and weaker
diversification in higher-integration states. Neither source claims that a
fall in raw WTI/SP500 Pearson correlation makes WTI trend profitable,
reproduces the source futures series, or creates a portfolio hedge.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: the cross-source conjunction is novel;
the source correlation model is materially richer than the proxy; only about
half of monthly signals may qualify; WTI roll, financing, gaps, geopolitics,
and changing equity integration remain; Pearson estimates are unstable;
hard stops can slip; and a falling recent statistic does not remove full-book
or XNG overlap.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full
  post-warm-up year.
- Fail on wrong month mapping, fewer or more than thirteen endpoints, wrong
  close or return count, timestamp mismatch, shared return across blocks,
  log/simple return substitution, pooled block means, zero variance,
  population shortcut that changes the result, signed rather than absolute
  comparison, wrong inequality, entry without the trend, repeated attempt,
  SP500 order, hold beyond forty days, missing hard stop, invalid risk mode,
  or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing a window, block, estimator, threshold,
  direction, carrier, risk, stop, hold, spread, or retry rule.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS_FOR_DISCLOSED_PROXY | Two peer-reviewed sources with complete governed reads, explicit WTI coverage, and the untested conjunction and adverse correlation evidence preserved. |
| R2 | PASS | Independent month-end trend, exact synchronized disjoint Pearson blocks, strict eligibility, attempt state, stop, rollover, and stale exit are fixed. |
| R3 | PASS_FOR_DISCLOSED_PROXY | Registered WTI/SP500 D1 closes supply every runtime input; SP500 is read-only and source futures/index fidelity is not assumed. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: deterministic CLEAN; manual review separates WTI/XNG
  correlation-gated trend, SP500 downside-beta trend, WTI/XAU sign
  divergence, energy DownBeta, oil-predicts-equity, unconditional TSMOM, and
  XNG oscillator families.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, SP500 read-only contract,
  fixed-risk/news/Friday contract, and cheap parameter guards.
- trade_entry: consumed monthly attempt, independent WTI month-end trend,
  synchronized WTI/SP500 intersection, two block-local Pearson correlations,
  strict absolute decline, spread/quote/ATR/stop checks, and one fixed-risk
  WTI order.
- trade_management: malformed-state repair, broker-month exit, and forty-day
  stale exit before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, one XTIUSD.DWX D1 `RISK_FIXED` backtest setfile, and one paced
non-live Q02 handoff when CPU capacity permits. It does not authorize a
manual backtest; live, demo, shadow, stress, or optimization artifact;
AutoTrading; T_Live; deploy or T_Live manifest; portfolio-gate change;
portfolio admission; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-15 | initial falling-equity-correlation-gated WTI trend | G0 | APPROVED; build pending |
| v2 | 2026-08-15 | implement locked disjoint-block falling-correlation gate and WTI lifecycle | Q01 | PASS; Q02 handoff pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-15 | APPROVED; R1-R4 pass for disclosed proxy | `decisions/2026-08-15_qm5_21527_wti_fallcorr_trend_g0.md`; governed composite source packet |
| Q01 Build Validation | 2026-08-15 | PASS | strict compile 0/0; build check 0/0; seven reference tests; SPEC and P1 PASS |
| Q02 Baseline Screening | - | NOT ENQUEUED | - |
