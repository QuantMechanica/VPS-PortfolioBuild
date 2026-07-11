---
strategy_id: SHPAK-IDMOM-2017_XTI_XNG_S01
source_id: SHPAK-IDMOM-2017
ea_id: QM5_13145
slug: energy-idmom
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citations:
  - type: academic_working_paper
    citation: "Shpak, Iuliia; Human, Ben; and Nardon, Andrea (2017/2018). Idiosyncratic Momentum in Commodity Futures."
    location: "Complete article, Cross Border Benefits Alliance-Europe Review, July 2018, pp. 56-85; SSRN 3035397; https://www.cbba-europe.eu/wp-content/uploads/2018/07/CBBA-Europe-review_July-2018.pdf"
    quality_tier: B
    role: primary
strategy_type_flags: [symmetric-long-short, atr-hard-stop, time-stop]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
factor_symbols: [XTIUSD.DWX, XNGUSD.DWX, XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13145_ENERGY_IDMOM_D1
period: D1
expected_trade_frequency: "One XTI/XNG residual-momentum package per broker calendar month after eleven completed months of warm-up; approximately 12 packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Falsify whether price-only commodity-market residualization preserves a distinct XTI/XNG idiosyncratic-momentum carrier. It is not the certified XNG RSI pullback, raw trend, seasonality, ratio reversion, or an index/metal trade; realized orthogonality remains unclaimed until Q09."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, benchmark_proxy, low_frequency, narrow_cross_section]
g0_approval_reasoning: "APPROVED under the OWNER commodity-sleeve mission: the complete bounded source defines an exact 11/1 residual-momentum rank and explicitly includes WTI and natural gas; R1-R4 pass; canonical and manual dedup are clean; no ML or banned indicator is present. Working-paper evidence quality, omitted non-price source factors, four-CFD benchmark substitution, futures/CFD basis, and two-name breadth remain binding Q02 kill risks."
---

# XTI/XNG 11-Month Idiosyncratic Momentum

## Hypothesis

Raw commodity momentum can carry unstable exposure to broad commodity moves.
Ranking the component left after stripping a fixed market-factor beta targets
commodity-specific underreaction instead. This card expresses that structure
as a paired energy carrier: buy the higher XTI/XNG cumulative residual-return
score and short the lower score for one broker month.

Opposite directions and equal fixed-risk halves reduce common energy direction.
They do not guarantee dollar, beta, volatility, factor, or realized market
neutrality. Only a surviving return stream at Q09 can establish correlation to
the certified XAU/SP500/NDX/XNG book.

## Source And Evidence Boundary

The primary source is Shpak, Human, and Nardon, "Idiosyncratic Momentum in
Commodity Futures," complete article pp. 56-85 and SSRN 3035397. It studies 28
futures, explicitly including WTI crude oil and natural gas, ranks cumulative
residual returns, uses equal winner/loser weights, and identifies 11-month
formation with a one-month hold as its highest-return construction.

The source uses market, term-structure, and size factors. This carrier uses
only a fixed equal-weight XTI/XNG/XAU/XAG price factor because futures curves,
open interest, and external runtime feeds are unavailable and may not be
invented. That is a disclosed proxy falsification, not a replication. No source
performance, significance, drawdown, cost, or correlation result is imported.

## Concept And Formula

At the first tradable D1 host bar of broker month t, reconstruct eleven
completed monthly log returns for all four fixed factor members:

    factor[m] = 0.25 * (r_XTI[m] + r_XNG[m] + r_XAU[m] + r_XAG[m])

For each traded energy leg i, estimate a closed-window OLS beta across the
eleven monthly observations and follow the source's equation-3 treatment:

    beta_i  = cov(r_i, factor) / var(factor)
    idmom_i = sum_m(r_i[m] - beta_i * factor[m])

The fitted intercept is a model-control term and is deliberately not subtracted
from the ranking residual.

- `idmom_XTI > idmom_XNG`: BUY XTI and SELL XNG.
- `idmom_XTI < idmom_XNG`: SELL XTI and BUY XNG.
- Numerical tie, singular factor, missing/stale endpoint, or invalid
  arithmetic: remain flat.

## Markets And Timeframe

- Logical basket: QM5_13145_ENERGY_IDMOM_D1.
- Host and traded slot 0: XTIUSD.DWX, D1.
- Traded slot 1: XNGUSD.DWX, D1.
- Read-only factor members: XAUUSD.DWX and XAGUSD.DWX, D1.
- Formation: eleven complete broker months immediately before the decision
  month; current month is excluded.
- Rebalance: first tradable D1 bar of every broker month.
- Backtest risk: RISK_FIXED=1000, RISK_PERCENT=0,
  PORTFOLIO_WEIGHT=1, split equally across both traded legs.
- Runtime data: native MT5 D1 time/close, ATR, spread, broker calendar, deal
  history, position state, and contract metadata only.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

- Require exact host XTIUSD.DWX, timeframe D1, and magic slot 0.
- Detect the first tradable host D1 bar of each new broker month.
- For every factor member, select the last completed D1 close strictly before
  each of the twelve month boundaries needed for eleven returns.
- Require ordered positive endpoints and no endpoint more than
  `strategy_max_boundary_gap_days=10` calendar days before its boundary.
- Compute eleven synchronized completed-month log returns.
- Construct the fixed equal-weight four-CFD market factor.
- Require positive finite factor variance, finite OLS betas, positive fitted
  residual variance, and a nonzero XTI/XNG score difference.
- Buy the higher-idiosyncratic-momentum leg and short the lower leg.
- Reject missing history, invalid arithmetic/ATR/lot metadata, excess spread,
  existing package, or a broker month already entered.
- Scan positions and entry deals so restart or a stopped leg cannot create a
  second package in the same month.
- Split fixed package risk equally and attach a frozen ATR(20) times 3.5 hard
  stop to each leg. If the second order fails, flatten the first immediately.

## 5. Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month before
  evaluating a replacement package.
- Close both legs after `strategy_max_hold_days=35` as a stale time stop.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source-aligned one-month hold.

## 6. Filters (No-Trade Module)

- Framework kill switch remains first and authoritative.
- Locked ranking window, exact host, bounded history, endpoint freshness/order,
  factor variance, regression arithmetic, spread, ATR, lot, month-attempt,
  magic, and package checks fail closed.
- News compliance gates new entries for both traded symbols; lifecycle
  management and orphan cleanup remain active. Q02 disables both news axes.

## 7. Trade Management Rules

- Exactly two opposite-side traded legs use equal fixed-risk shares.
- XAU and XAG are read-only; the EA never orders them.
- One paired package per broker month; a stopped or missing leg does not
  authorize same-month re-entry.
- No TP, trail, break-even, partial close, scale-in, grid, martingale,
  pyramiding, external feed, futures curve, open interest, banned indicator,
  adaptive PnL fit, PCA, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| strategy_ranking_months | 11 | [11] | source-best formation period |
| strategy_history_bars | 420 | [380, 420, 500] | bounded D1 endpoint buffer only |
| strategy_max_boundary_gap_days | 10 | [7, 10] | endpoint freshness guard |
| strategy_atr_period_d1 | 20 | [14, 20, 30] | per-leg stop volatility estimate |
| strategy_atr_sl_mult | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| strategy_max_hold_days | 35 | [35] | stale guard around monthly reset |
| strategy_xti_max_spread_pts | 1500 | [1000, 1500, 2500] | XTI spread cap |
| strategy_xng_max_spread_pts | 3000 | [2000, 3000, 4500] | XNG spread cap |
| strategy_deviation_points | 20 | [10, 20, 50] | basket order deviation |

The eleven completed months, no skipped month, four-CFD equal-weight factor,
closed-window beta, alpha-not-subtracted residual score, higher-minus-lower
direction, monthly renewal, equal half-risk carrier, and no same-month re-entry
are locked. Changing any requires a new card and full pipeline run.

## Author Claim

The source states that idiosyncratic-return momentum is "materially more
persistent than total return momentum" (abstract, p. 56). This bounded source
claim motivates queue admission; it does not validate the two-CFD proxy.

## Risk

## Initial Risk Profile And Kill Criteria

- expected_pf 1.01 is a low queue-ordering prior, not evidence.
- expected_dd_pct 30.0 reflects XNG gaps, legging, factor misspecification,
  source-quality limits, narrow ranks, continuous-CFD rolls, and month holds.
- Expected density is twelve packages/year after warm-up. Retire below five
  completed packages/year under the binding Q02 economic floor.
- Fail Q02 on zero trades, invalid logical-basket accounting, singular factor,
  nondeterminism, persistent orphan exposure, stale endpoints, or risk mismatch.
- Do not change the 11-month window, add skipped months, add unavailable source
  factors, reverse direction, add a magnitude filter, or relax package guards
  to rescue a weak baseline.
- Missing term-structure/size factors, futures/CFD basis, and the two-name
  carrier are kill risks, never waiver grounds.

## Strategy Allowability Check

- [x] Mechanical structural commodity-specific momentum thesis.
- [x] Complete named primary source with equations, data, results, robustness,
      limitations, full-text publication, and SSRN DOI.
- [x] No banned indicator, ML, external runtime feed, futures curve, grid,
      martingale, pyramiding, or adaptive PnL fitting.
- [x] D1/monthly expected density is twelve packages/year before Q02.
- [x] Backtests use RISK_FIXED; no live setfile is authorized.
- [x] Friday-close exception is source-aligned and documented.
- [x] Canonical dedup plus manual signal/input/window/direction review is clean.

## Non-Duplicate Decision

- QM5_12567 cum-rsi2-commodity: two-day RSI pullback, not residual momentum.
- QM5_12733 xti-xng-xmom: raw recent return rank, no factor residualization.
- QM5_13113 energy-mom-ivol: raw momentum must agree with lower residual
  volatility; it does not rank cumulative residual return.
- QM5_13133 energy-ivol: residual standard-deviation rank only.
- QM5_13141 energy-ie-rank: residual tail-probability asymmetry, not residual
  return momentum.
- QM5_13144 energy-micro11: one isolated t-11/t-10 return slice, not eleven
  months of market-factor residual returns.

Pre-allocation canonical verdict: CLEAN across 4,031 registry rows and 333
cards. Manual verdict: CLEAN_AFTER_MANUAL_REVIEW.

## Framework Alignment

- no_trade: exact host/slot, locked 11-month model, bounded synchronized
  history, endpoint freshness/order, factor variance, residual arithmetic,
  spread, ATR, lot, month-attempt, magic, and package guards.
- trade_entry: source-defined cumulative residual-return rank, paired orders,
  equal fixed-risk allocation, and frozen hard stops.
- trade_management: next-month reset, 35-day stale close, restart-safe deal
  guard, composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

No T_Live, AutoTrading setting, live setfile, deploy manifest, portfolio gate,
portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial XTI/XNG 11-month idiosyncratic-momentum rank | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-11 | APPROVED under OWNER commodity-sleeve mission; R1-R4 and dedup clean | this card |
| Q01 Build Validation | 2026-07-11 | PASS: clean staged resolver; strict compile and build check 0/0 | artifacts/qm5_13145_build_result.json |
| Q02 Baseline Screening | 2026-07-11 | ENQUEUED: pending, attempt 0 | docs/ops/evidence/2026-07-11_qm5_13145_energy_idmom_q02_enqueue.md |

## Lessons Captured

- 2026-07-11: The rule is distinct only while the cumulative ranking input is
  factor-residual return; replacing it with raw momentum or residual volatility
  would duplicate an existing energy carrier.
