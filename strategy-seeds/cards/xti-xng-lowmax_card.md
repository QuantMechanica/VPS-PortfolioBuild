---
strategy_id: HOLLSTEIN-MAX-2021_XTI_XNG_S01
source_id: HOLLSTEIN-MAX-2021
ea_id: QM5_13130
slug: xti-xng-lowmax
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citations:
  - type: paper
    citation: "Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), article 2150017."
    location: "Complete 57-page accepted article and online appendix; especially pp. 7-10, 15, 23-25, Appendix B p. 29, Tables A3-A5; DOI https://doi.org/10.1142/S2010139221500178"
    quality_tier: A
    role: primary
strategy_type_flags: [atr-hard-stop, time-stop, symmetric-long-short]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13130_XTI_XNG_LOWMAX_D1
period: D1
expected_trade_frequency: "One monthly XTI/XNG low-MAX package after 253 completed D1 bars of warm-up; approximately 12 completed packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.03
expected_dd_pct: 27.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Out-of-sample test of the source's post-financialization negative MAX relation in an equal-risk XTI/XNG package. Full-sample and two-portfolio source results are null, so Q02 must falsify rather than inherit the effect."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, narrow_cross_section, subsample_evidence]
g0_approval_reasoning: "OWNER mission-directed G0 approval on 2026-07-11: complete peer-reviewed source and appendix; deterministic 252-return top-five MAX rank, monthly paired hold, equal fixed risk, ATR hard stops, and no same-month re-entry; native registered XTI/XNG D1 data; no ML/banned/external/grid/martingale logic; repository dedup CLEAN before atomic QM5_13130 allocation. Approval explicitly preserves the source's full-sample null and post-financialization-only evidence as kill risks."
---

# XTI/XNG Post-Financialization Low-MAX Rank

## Hypothesis

The source tests whether investors overpay for commodity futures with
lottery-like recent upside extremes. Its full-sample MAX result is null, but
its post-financialization subsample reports that high-MAX commodities
underperform low-MAX commodities. This card performs a strict out-of-sample
test of that modern-period relation: buy the lower-MAX energy leg and short the
higher-MAX leg for one broker month.

Opposite legs and equal fixed-risk allocation reduce common energy direction,
but do not guarantee dollar, beta, or volatility neutrality. Low correlation
to the XAU/SP500/NDX/XNG book is an objective only; Q09 is the correlation
judge if the edge survives earlier gates.

## Source And Evidence Boundary

The sole source is Hollstein, Prokopczuk, and Tharann (2021), *Quarterly
Journal of Finance* 11(4), DOI `10.1142/S2010139221500178`. The complete
accepted article and online appendix were read end to end. The paper computes
MAX as the average of the five largest daily commodity-futures excess returns
during the prior 12 months, ranks commodities at month-end, and holds the
long-short portfolio for one month. WTI crude oil and natural gas are explicit
source instruments.

The evidence is deliberately not overstated:

- The full-sample MAX hedge return is statistically insignificant.
- The full-sample two-portfolio robustness split is also insignificant.
- The negative relation is concentrated in the December 2000-December 2015
  post-financialization subsample.
- The source's 2015 endpoint makes the QM 2017+ Q02 window a genuine
  out-of-sample test.
- The paper ranks a broad futures cross-section; this card ranks only two
  continuous CFDs.

No paper return, alpha, drawdown, correlation, or transaction-cost result is
imported into `expected_pf`, the portfolio book, or any gate.

## Concept And Formula

On the first tradable `XTIUSD.DWX` D1 bar of each broker month, use the most
recent 253 completed D1 closes for each energy leg. Compute 252 simple daily
returns, sort them, and define:

```text
MAX_i = arithmetic_mean(five_largest_daily_returns_i)
```

The post-financialization negative relation fixes the package direction:

- `MAX_XTI < MAX_XNG`: BUY XTI and SELL XNG.
- `MAX_XTI > MAX_XNG`: SELL XTI and BUY XNG.
- Numerical tie, incomplete history, or invalid arithmetic: remain flat.

The paper uses daily excess returns and a trailing 12-calendar-month window.
The EA uses simple close-to-close CFD returns and 252 completed D1
observations. That is a declared carrier translation, not a replication.

## Rules

## Markets And Timeframe

- Logical basket: `QM5_13130_XTI_XNG_LOWMAX_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Signal cadence: first tradable D1 bar of each broker month.
- Formation: exactly 252 completed D1 returns; the live D1 bar is excluded.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split equally across the two legs.
- Runtime data: MT5-native D1 closes, ATR, spread, broker calendar, deal
  history, and position state only.

## 4. Entry Rules

- Require exact host `XTIUSD.DWX`, timeframe D1, and magic slot 0.
- Detect a month transition by comparing the current host D1 bar's month with
  the immediately preceding completed host D1 bar's month.
- Load at least 253 completed D1 closes for each leg and calculate exactly 252
  simple close-to-close returns.
- Sort each return vector ascending and average its five largest values.
- Buy the lower-MAX leg and sell the higher-MAX leg.
- Reject a numerical tie, missing or nonpositive close, invalid return,
  incomplete history, invalid ATR/price/lot metadata, excess spread, an
  existing package, or a month already entered.
- Scan current positions and deal history so a restart or stopped leg cannot
  create a second package in the same broker month.
- Split the fixed package risk equally and attach a frozen
  `ATR(20) * 3.5` hard stop to each leg.
- If the second order fails, immediately flatten the first leg.

## 5. Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month before
  evaluating a replacement package.
- Close both legs after `strategy_max_hold_days=35` as a stale-package guard.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source's one-month hold.

## 6. Filters (No-Trade Module)

- Framework kill switch is first and authoritative.
- Fail closed on wrong host, timeframe, magic offset, or parameter domain.
- Entry requires valid synchronized history, arithmetic, spread, ATR, price,
  broker-volume metadata, and registered magics for both legs.
- News compliance gates new entries for both traded symbols only; lifecycle
  management and orphan repair remain active.
- Q02's structural baseline explicitly disables both news axes.

## 7. Trade Management Rules

- Exactly two traded legs with opposite sides and equal fixed-risk shares.
- One package per broker month, including after a hard stop or restart.
- No take profit, trailing stop, break-even, partial close, scale-in, grid,
  martingale, pyramiding, external feed, adaptive PnL fit, or ML.

## 8. Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_lookback_d1` | 252 | [252] | source-aligned prior-year completed return count |
| `strategy_top_return_count` | 5 | [5] | source-defined MAX order statistic count |
| `strategy_history_bars` | 320 | [280, 320, 380] | bounded D1 retrieval buffer; does not change the 252-return signal |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg hard-stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard around monthly reset |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG entry spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The 252-return window, top-five arithmetic mean, low-minus-high direction,
monthly renewal, equal half-risk carrier, and no same-month re-entry are
locked. A shorter formation period, threshold gate, RSJ/skew/momentum filter,
or single-leg MAX signal requires a new card.

## 9. Author Claims

"Post-financialization, there is a strong and significant negative effect
across all specifications." (subperiod discussion, p. 24)

"All anomalies tend to get weaker for this holding period." (annual-hold
discussion, p. 25)

These statements motivate the modern monthly test while preserving the
paper's full-sample null. They do not validate the two-leg CFD carrier.

## Risk

## 10. Initial Risk Profile

- `expected_pf: 1.03` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 27.0` reflects XNG gaps, legging, rank flips, the narrow
  cross-section, and weak source robustness.
- `expected_trade_frequency: 12 packages/year` must clear the binding Q02
  minimum of five completed packages/year.
- `risk_class: high`.
- `ml_required: false`.

## 11. Strategy Allowability Check

- [x] Mechanical structural tail-demand thesis with deterministic rules.
- [x] Peer-reviewed primary source, DOI, institutional full text, and complete
  article/appendix review.
- [x] No ML, banned indicator, external runtime data, futures curve, API, CSV,
  grid, martingale, or pyramiding.
- [x] D1/monthly with expected density above the five-trades/year Q02 floor.
- [x] Backtests use `RISK_FIXED`; no live setfile is authorized.
- [x] Friday-close exception is source-aligned and explicitly documented.
- [x] Repository dedup was clean before atomic EA-ID allocation.

## 12. Framework Alignment

- no_trade: exact host/slot, locked signal dimensions, history, arithmetic,
  spread, ATR, lot, monthly-attempt, magic, and package guards.
- trade_entry: prior-252-return top-five MAX rank, paired market orders, equal
  fixed-risk allocation, and frozen ATR stops.
- trade_management: next-month reset, 35-day stale close, restart-safe deal
  scan, composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

`hard_rules_at_risk`:

- `basket_execution`: Q02 must evaluate one logical two-leg package.
- `friday_close`: disabled only for the source-aligned monthly hold.
- `magic_schema`: slots 0 and 1 remain registry-resolved.
- `risk_mode_dual`: only a RISK_FIXED backtest setfile is authorized.
- `cfd_futures_basis`: no continuous-CFD/futures equivalence is assumed.
- `narrow_cross_section`: two energy legs are not the paper's portfolios.
- `subsample_evidence`: the source direction is modern-subsample-only and
  must be rejected if it does not persist out of sample.

No `T_Live`, AutoTrading setting, live setfile, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI path is authorized.

## 14. Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial post-financialization low-MAX energy basket | Q02 | ENQUEUED |

## 15. Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-11 | APPROVED by OWNER mission directive | this card |
| Q01 Build Validation | 2026-07-11 | PASS; 0 errors, 0 warnings | `docs/ops/evidence/2026-07-11_qm5_13130_xti_xng_lowmax_q02_enqueue.md` |
| Q02 Baseline Screening | 2026-07-11 | ENQUEUED; pending, attempt 0 | `docs/ops/evidence/2026-07-11_qm5_13130_xti_xng_lowmax_q02_enqueue.md` |

## 16. Lessons Captured

- 2026-07-11: The source's full-sample null and modern-only MAX effect are
  binding falsification context, not details to omit from the card.
