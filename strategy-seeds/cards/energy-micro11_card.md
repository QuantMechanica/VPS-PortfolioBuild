---
strategy_id: FAN-MICROMOM-2014_XTI_XNG_S01
source_id: FAN-MICROMOM-2014
ea_id: QM5_13144
slug: energy-micro11
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citations:
  - type: doctoral_thesis
    citation: "Fan, John Hua (2014). Momentum Investing in Commodity Futures. PhD thesis, Griffith University."
    location: "Complete Chapter 3, Microscopic Momentum, pp. 62-106; institutional full text https://research-repository.griffith.edu.au/server/api/core/bitstreams/5b940466-77cf-5789-bdf3-14987ca5a12a/content"
    quality_tier: B
    role: primary
  - type: academic_working_paper
    citation: "Bianchi, Robert J.; Drew, Michael E.; and Fan, John Hua (2020). Commodity Futures Momentum: Sources of Risk and Anomalies."
    location: "Complete-paper record and abstract; SSRN 2827237, DOI https://doi.org/10.2139/ssrn.2827237"
    quality_tier: B
    role: supplement
strategy_type_flags: [cross-sectional-rank, market-neutral-basket, monthly-rebalance, symmetric-long-short, atr-hard-stop, time-stop]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13144_XTI_XNG_MICRO11_D1
period: D1
expected_trade_frequency: "One XTI/XNG microscopic-momentum package per broker calendar month after eleven completed months of warm-up; approximately 12 packages/year before Q02 validation."
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
review_focus: "Falsify whether the isolated 11-to-10-month commodity return slice survives as an opposite-side XTI/XNG carrier. It is neither the certified XNG RSI pullback nor cumulative trend, fixed seasonality, ratio reversion, or a metal/index signal; realized book orthogonality remains unclaimed until Q09."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, low_frequency, narrow_cross_section]
g0_approval_reasoning: "APPROVED under the OWNER commodity-sleeve mission: the complete bounded institutional source defines an exact mechanical 11-to-10-month commodity rank; R1-R4 pass; canonical and manual dedup are clean; no ML or banned indicator is present. Thesis/working-paper evidence quality, the broad-futures-to-two-CFD narrowing, and CFD basis remain binding Q02 kill risks."
---

# XTI/XNG 11-to-10-Month Microscopic Momentum

## Hypothesis

Commodity leadership can contain a delayed continuation component concentrated
in the isolated return month roughly one year before portfolio formation. The
source separates that one-month slice from conventional trailing momentum and
finds materially different return dynamics. This card expresses the same
cross-sectional direction as a paired energy carrier: buy the XTI/XNG leg that
outperformed between the t-11 and t-10 month boundaries and short the other.

Opposite directions and equal fixed-risk halves reduce common energy direction.
They do not guarantee dollar, beta, volatility, factor, or realized market
neutrality. Only a surviving return stream at Q09 may establish correlation to
the certified XAU/SP500/NDX/XNG book.

## Source And Evidence Boundary

The bounded primary source is Fan (2014), Griffith University doctoral thesis,
Chapter 3, pages 62-106. The full chapter was reviewed, including the data and
roll design, monthly portfolio construction, results, robustness, transaction
costs, factor tests, and conclusion. A paper based on the chapter was reviewed
for the 2013 Auckland Finance Meeting; the authors later posted the expanded
working paper under SSRN 2827237.

The source ranks as many as 27 diversified commodity futures into terciles on
one isolated historical month, buys the winner tercile, shorts the loser
tercile, and holds one month. WTI crude oil and natural gas are explicit source
instruments. Its conclusion says the strategy uses "11 to 10 months of prior
return" (Chapter 3, p. 105).

The evidence is deliberately bounded:

- The exact microscopic rule is institutional doctoral and working-paper
  evidence, not a peer-reviewed journal result.
- The source's broad terciles, embedded futures roll yield, collateral
  treatment, and diversification are absent from this two-CFD carrier.
- Energy-sector membership in the source does not prove a two-name energy rank.
- No source performance, significance, drawdown, cost, or correlation result is
  imported as a QM result or expectation.

## Concept And Formula

On the first tradable XTIUSD.DWX D1 bar of broker month t, obtain for each leg
the last completed D1 close strictly before the broker-month boundaries t-11
and t-10:

    micro11_i = log(close_i(t-10 boundary) / close_i(t-11 boundary))

The interval is exactly one completed historical broker month. The current
month, the prior ten complete months, and cumulative trailing momentum do not
enter the rank.

- micro11_XTI greater than micro11_XNG: BUY XTI and SELL XNG.
- micro11_XTI less than micro11_XNG: SELL XTI and BUY XNG.
- Numerical tie, missing/stale endpoint, nonpositive close, or invalid
  arithmetic: remain flat.

## Markets And Timeframe

- Logical basket: QM5_13144_XTI_XNG_MICRO11_D1.
- Host and traded slot 0: XTIUSD.DWX, D1.
- Traded slot 1: XNGUSD.DWX, D1.
- Formation: synchronized completed D1 closes before t-11 and t-10 broker
  month boundaries.
- Rebalance: first tradable D1 bar of every broker month.
- Backtest risk: RISK_FIXED=1000, RISK_PERCENT=0,
  PORTFOLIO_WEIGHT=1, split equally across both legs.
- Runtime data: native MT5 D1 close/time, ATR, spread, broker calendar, deal
  history, position state, and contract metadata only.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

- Require exact host XTIUSD.DWX, timeframe D1, and magic slot 0.
- Detect the first tradable host D1 bar of each new broker month.
- Derive the t-11 and t-10 calendar boundaries from the decision month.
- For both legs, select the last completed D1 close strictly before each
  boundary from at most strategy_history_bars=420 bars.
- Require endpoint ordering, positive closes, and no endpoint more than
  strategy_max_boundary_gap_days=10 calendar days before its boundary.
- Compute the single log return between those two endpoints for each leg.
- Buy the higher-return leg and short the lower-return leg.
- Reject a numerical tie, missing/nonpositive/stale endpoint, invalid return,
  invalid ATR/price/lot metadata, excess spread, existing package, or a broker
  month already entered.
- Scan positions and entry deals so restart or a stopped leg cannot create
  another package in the same month.
- Split fixed package risk equally and attach a frozen ATR(20) times 3.5 hard
  stop to each leg.
- If the second order fails, immediately flatten the first leg.

## 5. Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month before
  evaluating a replacement package.
- Close both legs after strategy_max_hold_days=35 as a stale time stop.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source-aligned monthly hold.

## 6. Filters (No-Trade Module)

- Framework kill switch remains first and authoritative.
- Parameter, exact-host, history, boundary freshness/order, arithmetic,
  spread, ATR, lot, month-attempt, magic, and composition checks fail closed.
- News compliance gates new entries for both symbols; lifecycle management and
  orphan cleanup remain active. The Q02 structural setfile disables both news
  axes.

## 7. Trade Management Rules

- Exactly two opposite-side legs use equal fixed-risk shares.
- One paired package per broker month; a stopped or manually missing leg does
  not authorize same-month re-entry.
- No TP, trail, break-even, partial close, scale-in, grid, martingale,
  pyramiding, regression, PCA, external feed, futures curve, banned indicator,
  adaptive PnL fit, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| strategy_far_boundary_months | 11 | [11] | source-defined far endpoint |
| strategy_near_boundary_months | 10 | [10] | source-defined near endpoint |
| strategy_history_bars | 420 | [380, 420, 500] | bounded D1 endpoint buffer only |
| strategy_max_boundary_gap_days | 10 | [7, 10] | endpoint freshness guard |
| strategy_atr_period_d1 | 20 | [14, 20, 30] | per-leg stop volatility estimate |
| strategy_atr_sl_mult | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| strategy_max_hold_days | 35 | [35] | stale guard around monthly reset |
| strategy_xti_max_spread_pts | 1500 | [1000, 1500, 2500] | XTI spread cap |
| strategy_xng_max_spread_pts | 3000 | [2000, 3000, 4500] | XNG spread cap |
| strategy_deviation_points | 20 | [10, 20, 50] | basket order deviation |

The 11/10 completed-month boundaries, isolated one-month log return,
higher-minus-lower rank, monthly renewal, equal half-risk carrier, and no
same-month re-entry are locked. A cumulative return, other microscopic month,
same-calendar average, sign-only single-symbol signal, magnitude threshold, or
direction reversal requires a new card and full pipeline run.

## Author Claim

The source describes the 11,10 carrier as having "unique dynamics of returns"
relative to conventional momentum (Chapter 3, p. 64). That bounded claim
motivates a queue candidate; it does not validate this two-CFD adaptation.

## Risk

## Initial Risk Profile And Kill Criteria

- expected_pf 1.01 is a low queue-ordering prior, not evidence.
- expected_dd_pct 30.0 reflects XNG gaps, legging, sparse two-name ranks,
  continuous-CFD rolls, month-long holds, and source-quality limitations.
- Expected density is twelve packages/year after warm-up. Retire below five
  completed packages/year under the binding Q02 economic floor.
- Fail Q02 on zero trades, invalid logical-basket accounting,
  nondeterminism, persistent orphan exposure, stale endpoints, or risk mismatch.
- Do not alter the 11/10 interval, add cumulative momentum, reverse direction,
  add a volatility/seasonality filter, or relax package guards to rescue a weak
  baseline.
- Source-to-carrier narrowing, futures/CFD basis, and the absence of journal
  review for the exact microscopic rule are kill risks, never waiver grounds.

## Strategy Allowability Check

- [x] Mechanical structural delayed-momentum thesis.
- [x] Complete institutional primary source with precise reproducible chapter,
      method, tables, robustness checks, limitations, and working-paper record.
- [x] No banned indicator, ML, external runtime feed, option input, futures
      curve, grid, martingale, pyramiding, or adaptive PnL fitting.
- [x] D1/monthly expected density is twelve packages/year before Q02.
- [x] Backtests use RISK_FIXED; no live setfile is authorized.
- [x] Friday-close exception is source-aligned and documented.
- [x] Canonical dedup plus manual signal/input/window/direction review is clean.

## Non-Duplicate Decision

- QM5_12567 cum-rsi2-commodity: two-day RSI pullback, not distant return rank.
- QM5_12603 wti-tsmom12m: standalone WTI cumulative 12-month return sign.
- QM5_12733 xti-xng-xmom: recent cumulative cross-energy momentum.
- QM5_13115 energy-samecal: average matching calendar-month return across
  prior years, not one isolated t-11/t-10 interval.
- QM5_13120 energy-momrev: interacting cumulative 12- and 18-month ranks.
- QM5_13121 energy-tfmom: cumulative 12-month rank with seven-month trend mean.
- QM5_13126 energy-momcarry: cumulative momentum and broker-carry interaction.

No canonical or fuzzy duplicate was returned. Manual signal-input, transform,
direction, window, and exit review verdict: CLEAN_AFTER_MANUAL_REVIEW.

## Framework Alignment

- no_trade: exact host/slot, locked 11/10 endpoints, bounded history, endpoint
  freshness/order, arithmetic, spread, ATR, lot, month-attempt, magic, and
  package guards.
- trade_entry: isolated t-11/t-10 return rank, paired orders, equal fixed-risk
  allocation, and frozen hard stops.
- trade_management: next-month reset, 35-day stale close, restart-safe deal
  guard, composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

No T_Live, AutoTrading setting, live setfile, deploy manifest, portfolio gate,
portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial XTI/XNG 11-to-10-month microscopic rank | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-11 | APPROVED under OWNER commodity-sleeve mission; R1-R4 and dedup clean | this card |
| Q01 Build Validation | 2026-07-11 | PASS: clean staged resolver; strict compile and build check 0/0 | artifacts/qm5_13144_build_result.json |
| Q02 Baseline Screening | 2026-07-11 | ENQUEUED: pending, attempt 0 | docs/ops/evidence/2026-07-11_qm5_13144_energy_micro11_q02_enqueue.md |

## Lessons Captured

- 2026-07-11: The microscopic signal stays distinct only when the isolated
  t-11/t-10 month is explicit; a trailing return or same-calendar average is a
  different strategy.
