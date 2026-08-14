---
card_schema_version: 2
type: strategy
strategy_id: MOP-EIA-WTI-DECOUP-2026_S01
variant_id: MOP-EIA-WTI-DECOUP-2026_S01
source_id: MOP-EIA-WTI-DECOUP-2026
ea_id: QM5_21516
slug: wti-decoup-trend
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_21516_wti-decoup-trend_card.md
execution_contract_status: DRAFT
created: 2026-08-14
created_by: Research+Development
last_updated: 2026-08-14
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250; Villar and Joutz (2006), U.S. EIA; Ramberg and Parsons (2012), The Energy Journal 33(2), 13-35."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: primary_wti_membership_twelve_month_own_return_sign_and_monthly_cadence
  - type: government_research
    citation: "Villar, J. A., and Joutz, F. L. (2006). The Relationship Between Crude Oil and Natural Gas Prices. U.S. Energy Information Administration."
    location: "complete-report evidence strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: oil_gas_link_instability_and_decoupling_context
  - type: peer_reviewed_energy_paper
    citation: "Ramberg, D. J., and Parsons, J. E. (2012). The Weak Tie Between Natural Gas and Oil Prices. The Energy Journal 33(2), 13-35."
    location: "DOI 10.5547/01956574.33.2.2; complete-paper evidence strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: weak_time_varying_oil_gas_relationship_and_adverse_context
strategy_mechanic: monthly-wti-twelve-month-return-sign-trend-gated-by-weak-absolute-63-synchronized-d1-xti-xng-return-correlation
sources:
  - "[[sources/MOP-EIA-WTI-DECOUP-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/oil-gas-decoupling]]"
  - "[[concepts/crude-oil-structural-premium]]"
indicators:
  - "[[indicators/pearson-return-correlation]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, time-series-momentum, weak-common-energy-state, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
read_only_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 215160000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately five to nine completed WTI positions per full post-warm-up year when the weak-correlation state qualifies; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify an outright WTI twelve-month trend that enters only in weak synchronized WTI/XNG return-correlation regimes, adding a crude-oil driver distinct from the XAU/SP500/NDX/XNG book; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exactly_thirteen_consecutive_completed_month_ends, exact_twelve_month_log_return, exactly_sixty_four_synchronized_completed_d1_closes, exactly_sixty_three_simple_returns, sample_pearson_correlation, absolute_correlation_ceiling, xng_read_only, monthly_attempt_state, risk_mode_dual, friday_close_disabled, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-14_qm5_21516_wti_decoup_trend_g0.md: R1 peer-reviewed JFE trend source with complete-paper evidence plus complete government and peer-reviewed oil-gas relationship evidence; R2 exact twelve-month trend, synchronized 63-return sample Pearson gate, fixed absolute 0.30 ceiling, consumed monthly lifecycle, stop, and exit; R3 registered XTI/XNG D1 route with XNG read-only; R4 deterministic native arithmetic. The canonical pre-allocation checker returned CLEAN across 4,388 registry rows and 484 cards, and manual review separated unconditional trend and cross-energy relative-value families."
---

# QM5_21516 WTI Decoupled Trend

## Hypothesis

WTI's own twelve-month return sign may retain the broad time-series-momentum
effect when crude oil is not moving as part of a strong common oil/natural-gas
daily-return state. Restricting entries to weak recent XTI/XNG correlation is
intended to select crude-specific production, transport, refining, policy, and
demand regimes rather than a broad common-energy move.

The candidate trades WTI outright and therefore introduces a direct crude-oil
return driver that is absent from the certified XAU, SP500, NDX, and XNG book.
The correlation gate does not prove low correlation to that book. Q02 owns
density and economics; Q09 owns realized portfolio overlap.

## Source Traceability And Claim Boundary

Moskowitz, Ooi, and Pedersen (2012) form monthly time-series-momentum positions
from the sign of each instrument's own past return, explicitly include WTI,
and report the selected twelve-month strategy across a diversified futures
universe. Villar and Joutz (2006) and Ramberg and Parsons (2012) document an
economically linked but unstable and weak oil-gas relationship. Modern EIA
context records little daily WTI/Henry Hub return correlation in its cited
period.

The sources do not test this conjunction, the 63-return sample, the absolute
`0.30` threshold, a continuous Darwinex CFD, fixed-dollar risk, ATR hard stop,
or the QM book. No source return, significance, Sharpe ratio, drawdown, trade
count, cost, CFD equivalence, threshold, or correlation statistic transfers.
The governed composite packet is
`strategy-seeds/sources/MOP-EIA-WTI-DECOUP-2026/source.md`.

## Non-Duplicate Decision

The canonical checker returned `CLEAN` for slug `wti-decoup-trend`, strategy ID
`MOP-EIA-WTI-DECOUP-2026_S01`, and the complete mechanic string across 4,388
registry rows and 484 cards. Manual review separates the nearest families:

- `QM5_12603_wti-tsmom12m` and other WTI trend variants are unconditional or
  use WTI-only horizon, path, location, vote, pullback, weekday, or calendar
  transforms. They never require weak synchronized XTI/XNG daily correlation.
- `QM5_20237_xtixng-ecm-rv` estimates a trend-augmented oil/gas log-price
  residual and trades both legs toward convergence. This EA uses Pearson daily
  return correlation only as a gate and trades one WTI leg with its own trend.
- XTI/XNG ratio, return-spread, rank, beta, jump, volatility, and tail baskets
  trade or rank a cross-energy state rather than admit an outright WTI trend.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG oscillator
  pullback, not a monthly symmetric crude-oil trend.

The WTI carrier, exact twelve-month sign, exact 63-return synchronized sample
Pearson state, absolute `0.30` ceiling, XNG read-only boundary, consumed monthly
attempt, and single-leg fixed-risk execution are jointly load-bearing.
Verdict: `CLEAN_AUTHORIZED_WTI_WEAK_COMMON_ENERGY_CORRELATION_TREND`.

## Markets, Timeframe, And Formula

- Host and traded symbol: `XTIUSD.DWX`, D1, slot 0, magic `215160000`.
- Read-only state symbol: `XNGUSD.DWX`, D1, no magic or order authority.
- Decision clock: first processed host D1 bar after a genuine broker-month
  transition.
- Trend formation: exactly thirteen consecutive completed broker-month WTI
  endpoints ending in the immediately prior broker month.
- Correlation state: exactly the latest 64 timestamp-matched completed D1
  closes per symbol, yielding 63 chronological simple returns.
- Hold: until the next broker-month boundary, with a forty-day stale guard.

```text
trend_12m = ln(WTI_month_end_latest / WTI_month_end_12_months_ago)

x_i = XTI_close_i / XTI_close_(i-1) - 1
y_i = XNG_close_i / XNG_close_(i-1) - 1

rho = sample_covariance(x,y) /
      sqrt(sample_variance(x) * sample_variance(y))

qualified = abs(rho) <= 0.30 + 1e-12
BUY  when qualified and trend_12m > 0
SELL when qualified and trend_12m < 0
FLAT otherwise
```

The endpoint log return must equal the sum of the twelve component monthly log
returns within `1e-10`. Sample covariance and both sample variances use
denominator `63-1`; zero variance and non-finite arithmetic fail closed.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. No alternate threshold, horizon, estimator, carrier,
calendar, risk scale, or fallback is authorized.

## 4. Entry Rules

1. Require exact EA ID 21516, `XTIUSD.DWX` D1 host, slot 0, magic
   `215160000`, and read-only `XNGUSD.DWX`.
2. Process lifecycle repair and prior-month liquidation before entry-only
   gates. Evaluate only after a genuine broker-month transition.
3. Persist the broker month as consumed before history, signal, spread, quote,
   news, ATR, sizing, or order checks. A failed or stopped entry may not retry.
4. Load a bounded 500 completed-D1-bar buffer for each symbol and intersect
   exact timestamps. Require strict chronology, positive finite closes, at
   least 64 common closes, a newest common endpoint before the decision bar,
   and no more than ten calendar days stale.
5. From the latest 64 common closes form exactly 63 chronological simple
   returns per symbol. Require positive finite sample variance and a finite
   Pearson coefficient inside `[-1-1e-12, 1+1e-12]`.
6. Consume the month flat unless `abs(rho) <= 0.30 + 1e-12`.
7. From the synchronized history derive exactly thirteen consecutive completed
   broker-month WTI endpoints ending in the immediately prior broker month.
   Require the endpoint and chained twelve-month log-return calculations to
   agree within `1e-10`.
8. Buy on a strictly positive twelve-month return; sell on a strictly negative
   return; consume exact zero flat.
9. Require no owned exposure, no same-month entry deal, spread in `[0,1500]`
   points, an executable quote, completed `ATR(20,D1)`, and valid fixed-risk
   contract metadata.
10. Open at most one WTI position with one `RISK_FIXED=1000` budget, a frozen
    `3.5 * ATR(20,D1)` broker hard stop, and no take-profit. Never order XNG.

## 5. Exit Rules

1. Close the prior WTI position on the first processed D1 bar of every new
   broker month before considering replacement risk, even if direction is
   unchanged.
2. Close after forty elapsed calendar days as a missed-rollover stale guard.
3. Close duplicate, wrong-symbol, invalid-type, or missing-stop exposure owned
   by this EA's magic.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source-aligned hold spans weekends.
6. There is no intramonth opposite-signal exit, target, trail, break-even,
   partial close, scale-in, grid, martingale, pyramid, or discretionary exit.

## 6. Filters (No-Trade Module)

- Fail closed outside exact host, timeframe, EA ID, slot, fixed-risk, news,
  Friday, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  incomplete/stale/misaligned history, wrong common-close or return count,
  nonfinite return, zero variance, out-of-range correlation, high-correlation
  state, nonconsecutive month endpoints, zero trend, excessive spread, invalid
  quote, unavailable ATR, invalid stop, or invalid contract metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not order XNG or read a futures chain, inventory, external file
  or API, analyst forecast, trained output, optimizer result, or portfolio
  state.

## 7. Trade Management Rules

- Maintain at most one WTI position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly replacement or after
  forty calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; tester initialization clears a future marker so
  historical runs remain deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, invalid-type, or missing-
  stop exposure before new entry logic.
- XNG remains read-only. Correlation magnitude never scales risk.
- No randomness, adaptive PnL fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_trend_months` | 12 | [12] | exact completed-month trend horizon |
| `strategy_corr_return_days` | 63 | [63] | synchronized simple-return sample |
| `strategy_corr_abs_max` | 0.30 | [0.30] | weak common-energy admission ceiling |
| `strategy_corr_tolerance` | 1e-12 | [1e-12] | threshold and range tolerance |
| `strategy_history_bars_d1` | 500 | [500] | bounded completed-D1 copy per symbol |
| `strategy_max_endpoint_gap_days` | 10 | [10] | common endpoint freshness guard |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop multiple |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values, return types, sample denominators, synchronization, threshold,
direction, attempt clock, risk, stop, hold, and no-retry policy are locked.

## Author Claims

The primary source supports a diversified twelve-month time-series-momentum
family that includes WTI. The oil-gas sources support a weak and changing
relationship. They do not claim that the fixed correlation state improves WTI
trend, that a continuous CFD reproduces collateralized futures, or that the
candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: the cross-source conjunction, selected
window and threshold, correlation estimator instability, two-series history
alignment, WTI gaps and rolls, fixed-risk stop slippage, sparse weak-correlation
states, futures/CFD basis, and possible overlap with XNG or risk assets can
dominate the premise.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong month-end or return count, timestamp mismatch, nonconsecutive
  months, population or rank correlation, wrong return type, high-correlation
  entry, inverted trend direction, XNG order, repeated attempt, hold beyond
  forty days, missing hard stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the trend horizon, correlation window,
  estimator, threshold, carrier, direction, stop, hold, spread, or retry rule.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | Peer-reviewed JFE trend source with complete-paper evidence, plus complete government and peer-reviewed oil-gas relationship sources. |
| R2 | PASS | Fixed month endpoints, return sign, synchronized sample Pearson gate, threshold, attempt, stop, rollover, and stale exit. |
| R3 | PASS | Registered XTI/XNG D1 closes; XNG is read-only and no external series is required. |
| R4 | PASS | Deterministic arithmetic only, without trained output, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: deterministic exact/fuzzy check clean; manual mechanic review
  separates unconditional trend and cross-energy relative-value families.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, XNG read-only contract,
  fixed-risk/news/Friday contract, and cheap parameter guards.
- trade_entry: persistent month attempt, exact synchronized histories,
  correlation state, completed-month trend, spread/quote/ATR/stop checks, and
  one fixed-risk WTI order.
- trade_management: malformed-state repair, broker-month exit, and forty-day
  stale exit before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff when CPU capacity permits. It
does not authorize a manual backtest; live, demo, shadow, optimization, or
stress setfile; AutoTrading; `T_Live`; deploy or T_Live manifest; portfolio-
gate change; portfolio admission; or a correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-14 | initial WTI weak-common-energy-correlation trend | G0 | APPROVED; build pending |
| v2 | 2026-08-14 | implement locked WTI trend and read-only XNG state | Q01 | PASS; Q02 handoff pending capacity gate |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-14 | APPROVED; R1-R4 PASS | `decisions/2026-08-14_qm5_21516_wti_decoup_trend_g0.md`; bounded source packet |
| Q01 Build Validation | 2026-08-14 | PASS | strict compile 0/0; target build check 0 failures/0 warnings; six independent reference tests; P1 artifact PASS |
| Q02 Baseline Screening | - | NOT ENQUEUED | - |
