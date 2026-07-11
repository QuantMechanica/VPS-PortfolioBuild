---
strategy_id: YIYI-ALIQ-2025_XTI_XNG_S01
source_id: YIYI-ALIQ-2025
ea_id: QM5_13140
slug: energy-aliq-rank
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citations:
  - type: paper
    citation: "Qin, Yiyi; Cai, Jun; Zhu, Jie; and Webb, Robert (2025). Commodity Futures Characteristics and Asset Pricing Models. Journal of Futures Markets 45(3), 176-207."
    location: "Complete open paper; data and portfolio-construction sections, Table 3, characteristic-correlation table, IPCA results, Appendix A ALIQ definition, and Appendix D; DOI https://doi.org/10.1002/fut.22559"
    quality_tier: A
    role: primary
strategy_type_flags: [atr-hard-stop, time-stop, symmetric-long-short]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13140_XTI_XNG_ALIQ_D1
period: D1
expected_trade_frequency: "One XTI/XNG ALIQ package each broker calendar month after 12 completed months and at least 220 daily observations; approximately 12 packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.02
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Falsify whether MT5 tick volume is a usable, stable activity proxy for the source's dollar-volume ALIQ rank in a two-leg energy CFD carrier. The broad futures result is not inherited evidence."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, tick_volume_proxy, cfd_futures_basis, low_frequency, narrow_cross_section]
g0_approval_reasoning: "OWNER mission-directed G0 approval: complete peer-reviewed source review; locked 12-month ALIQ rank and monthly XTI/XNG package; equal fixed risk, ATR stops, restart guard and orphan cleanup; native D1 data, no ML or banned logic. Tick-volume fidelity and two-CFD breadth remain Q02 kill risks."
---

# XTI/XNG Monthly Amihud-Illiquidity Rank

## Hypothesis

Commodity futures with persistently high absolute price movement per unit of
trading activity may command an illiquidity premium. This card translates the
source characteristic to a symmetric energy package: buy the higher trailing
ALIq leg and short the lower ALIq leg for one broker calendar month.

The edge is structural and low frequency. It is not a short-run reversal,
cointegration, gold/silver ratio, trend, seasonality, or claim that the legs
are dollar- or beta-neutral. Equal fixed-risk legs reduce outright direction;
only later portfolio evidence may establish realized correlation.

## Source And Evidence Boundary

The sole canonical source is Qin, Cai, Zhu, and Webb (2025), Journal of
Futures Markets 45(3), DOI https://doi.org/10.1002/fut.22559. The complete
open paper, appendices, and tables were reviewed end to end. The paper:

- studies 34 commodity futures from January 1981 through June 2022;
- forms monthly top and bottom 30 percent characteristic portfolios using
  information available in the previous month;
- defines ALIQ as average daily absolute return divided by dollar volume over
  the previous 12 months, scaled by 1,000,000;
- reports a positive high-minus-low one-way ALIQ portfolio; and
- does not find ALIQ significant in its IPCA latent-factor specification.

Only the transparent one-way characteristic sort is mechanized. The source
uses exchange dollar volume and a broad futures cross-section. Darwinex D1
tick volume is a broker activity count, so the implementation is a new proxy
falsification rather than a replication. No source performance, alpha,
drawdown, correlation, cost estimate, or IPCA model is imported.

## Concept And Formula

On the first tradable XTIUSD.DWX D1 bar of each broker calendar month, inspect
daily bars belonging to the 12 fully completed calendar months immediately
before the decision month. For leg i:

    r_i[t]       = log(close_i[t] / close_i[t-1])
    aliq_i[t]    = abs(r_i[t]) / tick_volume_i[t] * 1,000,000
    ALIQ_i       = sum(aliq_i[t]) / valid_daily_observations_i

Every one of the 12 expected months must be represented and each leg must
have at least 220 valid daily observations. A nonpositive close, nonpositive
tick volume, missing expected month, invalid arithmetic, insufficient bounded
history, or numerical tie stays flat.

Direction is locked:

- ALIQ_XTI greater than ALIQ_XNG: BUY XTI and SELL XNG.
- ALIQ_XTI less than ALIQ_XNG: SELL XTI and BUY XNG.
- Equal within 1e-12 or invalid: remain flat.

## Rules

### Markets And Timeframe

- Logical basket: QM5_13140_XTI_XNG_ALIQ_D1.
- Host and traded slot 0: XTIUSD.DWX, D1.
- Traded slot 1: XNGUSD.DWX, D1.
- Formation: exactly the prior 12 completed broker calendar months, current
  D1 bar and current calendar month excluded.
- Rebalance: first tradable D1 bar of every broker calendar month.
- Backtest risk: RISK_FIXED=1000, RISK_PERCENT=0,
  PORTFOLIO_WEIGHT=1, split equally across the two legs.
- Runtime data: MT5-native D1 close, tick volume, ATR, spread, broker calendar,
  deal history, and position state only.

## 4. Entry Rules

- Require exact host XTIUSD.DWX, timeframe D1, and magic slot 0.
- Detect the first tradable monthly bar by comparing the current host D1
  month with the preceding completed host D1 bar.
- For both legs, scan at most 400 completed D1 bars and accept observations
  only from the 12 expected previous calendar months.
- Fail closed if an expected-month bar has invalid close or tick volume, any
  expected month is absent, either leg has fewer than 220 observations, the
  ALIQ values tie, or arithmetic is invalid.
- Buy the higher-ALIq leg and short the lower-ALIq leg.
- Reject invalid ATR, price, lot metadata, excess spread, existing package, or
  a calendar month already entered.
- Scan current positions and entry deals so a restart or stopped leg cannot
  create another package in the same month.
- Split fixed package risk equally and attach a frozen ATR(20) times 3.5 hard
  stop to each leg.
- If the second order fails, immediately flatten the first leg.

## 5. Exit Rules

- Close both legs on the first tradable D1 bar of the next broker calendar
  month before evaluating a replacement package.
- Close both legs after strategy_max_hold_days=40 as a stale time stop.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source-aligned monthly hold.

## 6. Filters (No-Trade Module)

- Framework kill switch remains first and authoritative.
- Locked parameter, host, history, expected-month, observation-count,
  arithmetic, tick-volume, spread, ATR, lot, prior-attempt, magic, and
  composition checks fail closed.
- News compliance gates new entries for both symbols; lifecycle management and
  orphan repair remain active. The Q02 structural setfile disables news axes.

## 7. Trade Management Rules

- Exactly two opposite-side legs with equal fixed-risk shares.
- Close both legs together at the monthly reset or 40-day stale limit, and
  flatten any orphan or invalid composition on the next tick.
- No TP, trail, break-even, partial close, scale-in, grid, martingale,
  pyramiding, external feed, exchange-volume substitution, adaptive PnL fit,
  banned indicator, PCA, IPCA, regression, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| strategy_aliq_window_months | 12 | [12] | source-aligned completed-month window |
| strategy_history_bars | 400 | [350, 400, 500] | bounded D1 retrieval buffer only |
| strategy_min_daily_observations | 220 | [200, 220, 240] | data sufficiency, not alpha fit |
| strategy_atr_period_d1 | 20 | [14, 20, 30] | per-leg stop volatility estimate |
| strategy_atr_sl_mult | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| strategy_max_hold_days | 40 | [40] | stale guard around monthly reset |
| strategy_xti_max_spread_pts | 1500 | [1000, 1500, 2500] | XTI entry spread cap |
| strategy_xng_max_spread_pts | 3000 | [2000, 3000, 4500] | XNG entry spread cap |
| strategy_deviation_points | 20 | [10, 20, 50] | basket order deviation |

The 12-month window, absolute log return per same-day tick volume, 1,000,000
scale, arithmetic mean, high-minus-low direction, monthly renewal, equal
half-risk carrier, and no same-month re-entry are locked. Reversal direction,
exchange-volume claims, a spread filter inside the ALIQ formula, a shorter
formation window, or a momentum overlay requires a new card.

## Author Claim

"average of daily illiquidity measures over prior months t-12 to t-1"
(Appendix A).

This bounded definition and the one-way sort motivate a queue candidate; they
do not validate the tick-volume two-CFD translation.

## Risk

- expected_pf 1.02 is a low queue-ordering prior, not evidence.
- expected_dd_pct 30.0 reflects XNG gaps, legging, activity-proxy instability,
  narrow ranking, continuous-CFD basis, hard stops, and month-long holds.
- Expected frequency is 12 packages/year after warm-up. Missing volume or
  filters may reduce density below the Q02 low-frequency floor.
- Source dollar volume is unavailable. Tick-volume proxy failure is the
  primary kill criterion, not a parameter-search invitation.
- A two-contract rank cannot reproduce source top and bottom 30 percent
  portfolios, diversification, collateral treatment, or transaction costs.
- risk_class high; ml_required false.

## Strategy Allowability Check

- [x] Mechanical structural cross-sectional illiquidity-premium thesis.
- [x] Peer-reviewed primary source, DOI, open full text, and complete review.
- [x] No ML, IPCA, PCA, regression, banned indicator, external runtime feed,
      futures curve, grid, martingale, pyramiding, or adaptive PnL fitting.
- [x] D1/monthly expected density is 12 packages/year before Q02 validation.
- [x] Backtests use RISK_FIXED; no live setfile is authorized.
- [x] Friday-close exception is source-aligned and documented.
- [x] Canonical repository dedup review was clean before atomic allocation.

## Non-Duplicate Decision

- QM5_10330_illiq-rev: H1 single-symbol liquidity-shock reversal using spread
  and tick-volume percentiles, not a monthly ALIQ level premium.
- cs-spread-rev: high-low inferred spread reversal, not absolute return per
  activity unit or an energy cross-sectional hold.
- QM5_13123, QM5_13132, QM5_13133, QM5_13118, QM5_13129, QM5_13130,
  QM5_13131, QM5_13134, QM5_13139: value, beta, IVOL, skew, signed
  semivariance, MAX, kurtosis, variance-ratio momentum, and CV ranks; none uses
  ALIQ.
- QM5_12567_cum-rsi2-commodity: short-horizon long-only RSI pullback, not a
  monthly symmetric structural basket.

The dedup checker found no exact or fuzzy slug, strategy-ID, author, or
mechanic match. Manual formula and code review verdict: CLEAN.

## Framework Alignment

- no_trade: exact host and slot, locked formula, bounded history, expected
  months, observation sufficiency, arithmetic, spread, ATR, lot, prior
  attempt, magic, and package guards.
- trade_entry: completed-month ALIQ rank, paired orders, equal fixed-risk
  allocation, and frozen ATR stops.
- trade_management: next-month reset, 40-day stale close, restart-safe deal
  scan, composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

No T_Live, AutoTrading setting, live setfile, deploy manifest, portfolio gate,
portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial monthly XTI/XNG ALIQ basket | Q02 | ENQUEUED |

## Lessons Captured

- 2026-07-11: A broad futures liquidity characteristic can seed a narrow
  native-data falsification only when tick volume is labelled as a proxy and
  proxy failure remains a binding kill criterion.
