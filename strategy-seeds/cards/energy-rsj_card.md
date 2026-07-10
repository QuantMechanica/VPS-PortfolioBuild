---
strategy_id: KISS-RSJ-2025_XTI_XNG_S01
source_id: KISS-RSJ-2025
ea_id: QM5_13129
slug: energy-rsj
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citations:
  - type: paper
    citation: "Kiss, Tamas, and Igor Ferreira Batista Martins (2025). Good Volatility, Bad Volatility and the Cross Section of Commodity Returns. Finance Research Letters 86, Part D, article 108656."
    location: "Complete 12-page publication; Sections 2-6, Equations 1-4, Tables 1-5, Appendices A-B; DOI https://doi.org/10.1016/j.frl.2025.108656"
    quality_tier: A
    role: primary
strategy_type_flags: [atr-hard-stop, time-stop, symmetric-long-short]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13129_ENERGY_RSJ_D1
period: D1
expected_trade_frequency: "One monthly XTI/XNG relative-signed-jump package after warm-up; approximately 12 completed packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.05
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, narrow_cross_section]
g0_approval_reasoning: "OWNER mission-directed G0 approval 2026-07-11: complete peer-reviewed FRL source; deterministic one-completed-month RSJ formula and monthly low-RSJ/high-RSJ energy rank; native registered XTI/XNG D1 data; no ML/banned/external/grid/martingale logic; repository dedup CLEAN before atomic QM5_13129 allocation."
---

# XTI/XNG Relative-Signed-Jump Rank

## Hypothesis

Commodity producers and consumers hedge asymmetrically around gains and losses,
so the balance between upside and downside realized semivariance can affect
hedging demand and subsequent futures risk premia. The source finds a negative
cross-sectional relation between RSJ and next-month commodity returns. This
card tests that structural premium in a paired energy carrier: long the lower-
RSJ leg and short the higher-RSJ leg.

Opposite legs and equal fixed-risk allocation reduce common energy direction
but do not guarantee dollar or beta neutrality. Low correlation to the current
XAU/SP500/NDX/XNG book is an objective only; Q09 is the correlation judge.

## Source And Evidence Boundary

The sole source is Kiss and Ferreira Batista Martins (2025), *Finance Research
Letters* 86, DOI `10.1016/j.frl.2025.108656`. The complete open-access
publication was read, including all tables and appendices. It computes monthly
upside and downside realized semivariance from daily returns, ranks 36 futures,
and holds the extreme portfolios for one month. WTI crude oil and natural gas
are explicit source instruments.

One bounded author claim is: "RSJ factor earns a negative risk premium in the
cross section of commodity excess returns" (Section 4.2, p. 6). Source
portfolio performance is not a claim for this two-leg CFD carrier.

## Concept And Formula

On the first tradable `XTIUSD.DWX` D1 bar of each broker month, use only daily
close-to-close returns from the immediately preceding complete broker month.
For each leg compute:

```text
RV_plus  = sum(r_d^2 for r_d > 0)
RV_minus = sum(r_d^2 for r_d < 0)
RSJ      = (RV_plus - RV_minus) / (RV_plus + RV_minus)
```

The source's negative premium fixes the profitable orientation:

- `RSJ_XTI < RSJ_XNG`: BUY XTI and SELL XNG.
- `RSJ_XTI > RSJ_XNG`: SELL XTI and BUY XNG.
- Numerical tie, zero total realized variance, or insufficient history: flat.

## Markets And Timeframe

- Logical basket: `QM5_13129_ENERGY_RSJ_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Signal cadence: first tradable D1 bar of each broker month.
- Formation: the one complete broker-calendar month immediately before the
  decision month; the live month is excluded.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split equally across the two legs.
- Runtime data: MT5-native D1 OHLC, ATR, spread, broker calendar, and position
  state only.

## Rules

The following entry, exit, and lifecycle rules are the complete authorized
mechanization; anything not stated here is out of scope.

## 4. Entry Rules

- Require exact host `XTIUSD.DWX`, timeframe D1, and magic slot 0.
- Evaluate only once on the first new host D1 bar of a broker month.
- Reconstruct bounded synchronized D1 history for XTI and XNG; calculate
  simple close-to-close returns inside the preceding complete month.
- Require at least `strategy_min_return_observations=15` returns per leg.
- Require finite `RV+`, `RV-`, positive total realized variance, and RSJ in
  `[-1, 1]` for both legs.
- Buy the lower-RSJ leg and sell the higher-RSJ leg.
- Reject an exact numerical tie, missing history, invalid arithmetic/ATR/lot
  metadata, excess spread, an existing package, or a month already entered.
- Split the fixed package risk equally and attach a frozen
  `ATR(20) * 3.5` hard stop to each leg.

## 5. Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month before
  evaluating a replacement package.
- Close both legs after 35 calendar days as a stale-package guard.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source's one-month hold.

## 6. Filters (No-Trade module)

- Framework kill switch is first and authoritative.
- News compliance gates entries only; lifecycle management and repair remain
  active through news windows.
- One bounded history read per leg on the monthly decision path.

## 7. Trade Management Rules

- One package per EA and no same-month re-entry after a successful open.
- No take profit, trailing stop, break-even, partial close, scale-in, grid,
  martingale, pyramiding, external data, adaptive PnL fit, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_lookback_months` | 1 | [1] | source-defined completed-month RSJ window |
| `strategy_history_bars` | 80 | [60, 80, 120] | bounded D1 reconstruction buffer |
| `strategy_min_return_observations` | 15 | [15, 18] | fail-closed monthly data sufficiency |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg hard-stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard around monthly reset |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG entry spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The one-completed-month daily-return window, normalized RSJ formula, low-minus-
high orientation, monthly rebalance, equal half-risk paired carrier, and no
same-month re-entry are locked. A skewness proxy, momentum confirmation,
adaptive threshold, longer formation window, or single-leg RSJ signal requires
a new card.

## Non-Duplicate Decision

- `QM5_12567_cum-rsi2-commodity` is a short-horizon RSI pullback.
- `QM5_12733`, `QM5_12840`, `QM5_12850`, and `QM5_13089` use relative
  momentum, return-spread z-score, volatility contraction, or carry.
- `QM5_13113`, `QM5_13115`, `QM5_13120`, `QM5_13121`, `QM5_13123`, and
  `QM5_13126` use momentum-IVol, same-calendar return, reversal, trend,
  value, or momentum-carry interaction.
- `QM5_13118_energy-skew-rank` uses a 12-month third standardized moment. RSJ
  uses one month of positive and negative squared returns normalized by total
  variance; the source's factor and spanning tests explicitly distinguish RSJ
  from realized skewness.

Repository pre-allocation dedup verdict: `CLEAN`.

## Risk

## Initial Risk Profile And Kill Criteria

- `expected_pf: 1.05` is a conservative queue prior, not evidence.
- `expected_dd_pct: 25.0` reflects XNG gap risk, legging risk, monthly rank
  flips, and the narrow two-asset cross-section.
- Retire at Q02 below five completed packages/year, on zero trades, invalid
  formation windows, nondeterministic reruns, repeated init failure, orphan
  exposure, or risk-mode mismatch.
- Do not change the direction, add a signal filter, widen the universe, or
  lower the observation floor after a poor baseline.
- Treat the 36-future-to-two-CFD narrowing and futures/CFD basis mismatch as
  falsification risks, never waiver grounds.

## Strategy Allowability Check

- [x] R1 single source: peer-reviewed paper with DOI and institutional full text.
- [x] R2 mechanical: fixed RSJ formula, rank direction, lifecycle, and stops.
- [x] R3 testable: registered XTIUSD.DWX and XNGUSD.DWX D1 histories.
- [x] R4 compliant: deterministic one-position-per-magic/symbol execution; no
  banned indicator, ML, external feed, grid, martingale, or pyramiding.
- [x] Three controlled strategy flags are present.
- [x] Repository dedup was clean before atomic EA-ID allocation.

## Framework Alignment

- no_trade: exact host/slot, locked baseline, history, observation, arithmetic,
  spread, ATR, lot, monthly-attempt, and package guards.
- trade_entry: source-defined completed-month RSJ rank, paired market orders,
  equal fixed-risk allocation, and frozen ATR stops.
- trade_management: next-month rollover, 35-day stale close, composition
  validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

`hard_rules_at_risk`:

- `basket_execution`: Q02 must evaluate one logical two-leg package.
- `friday_close`: disabled only for the source-aligned monthly hold.
- `magic_schema`: slots 0 and 1 must remain registry-resolved.
- `risk_mode_dual`: only a RISK_FIXED backtest setfile is authorized.
- `cfd_futures_basis`: no continuous-CFD/futures equivalence is assumed.
- `narrow_cross_section`: two energy legs are not the paper's extreme portfolios.

No `T_Live`, AutoTrading setting, live setfile, deploy manifest, portfolio gate,
portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial source-backed extraction, build, and logical-basket enqueue | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-11 | APPROVED by OWNER mission directive | this card |
| Q01 Build Validation | 2026-07-11 | PASS | `artifacts/qm5_13129_build_result.json` |
| Q02 Baseline Screening | 2026-07-11 | ENQUEUED | `docs/ops/evidence/2026-07-11_qm5_13129_energy_rsj_q02_enqueue.md` |
