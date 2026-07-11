---
strategy_id: MEHLITZ-AUER-MEM-2024_XTI_S01
source_id: MEHLITZ-AUER-MEM-2024
ea_id: QM5_13134
slug: energy-vr-mom
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citation: "Mehlitz and Auer (2024), Memory-enhanced momentum in commodity futures markets, The European Journal of Finance 30(8), 773-802."
source_citations:
  - type: peer_reviewed_paper
    citation: "Mehlitz, Julia S., and Benjamin R. Auer (2024). Memory-enhanced momentum in commodity futures markets. The European Journal of Finance 30(8), 773-802."
    location: "Canonical DOI https://doi.org/10.1080/1351847X.2023.2220118; publisher page https://www.tandfonline.com/doi/full/10.1080/1351847X.2023.2220118; complete open precursor in Mehlitz (2021) doctoral thesis, Chapter 3 pp. 51-74 and Appendix C pp. 110-113, https://www.researchgate.net/publication/357152829_Risk_and_return_of_passive_and_active_commodity_futures_strategies"
    quality_tier: A
    role: primary
sources:
  - "[[sources/MEHLITZ-AUER-MEM-2024]]"
concepts:
  - "[[concepts/memory-enhanced-momentum]]"
  - "[[concepts/variance-ratio]]"
  - "[[concepts/wti-structural-trend-reversal]]"
indicators:
  - "[[indicators/lo-mackinlay-variance-ratio]]"
  - "[[indicators/monthly-return-sign]]"
  - "[[indicators/atr]]"
strategy_type_flags: [symmetric-long-short, structural-momentum-reversal, atr-hard-stop, monthly-time-exit]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
period: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 6-10 completed XTI trades/year after a 33-month warm-up; one attempt at most per broker month."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.03
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Adds a WTI-only monthly autocorrelation-regime return stream to the XAU/SP500/NDX/XNG book; Q02 must first validate density/economics and Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, cfd_futures_basis, low_frequency, narrow_carrier]
g0_approval_reasoning: "OWNER mission G0: R1 peer-reviewed EJF paper plus complete open precursor chapter; R2 locked monthly R1-q2 robust variance-ratio rule; R3 native XTI MN1/D1; R4 deterministic non-ML, one position per magic; exact dedup clean after manual fuzzy review."
---

# XTI Memory-Enhanced Variance-Ratio Momentum

## Hypothesis

One-month WTI direction should be followed only when the latest 32 monthly
returns show statistically significant short-memory persistence. When the same
test instead shows significant anti-persistence, the one-month direction is
reversed. Insignificant memory means no position.

This is a structural WTI carrier, not another index/metal rule and not another
XNG oscillator. It is intended to add a different return driver to the current
XAU/SP500/NDX/XNG book, but no decorrelation claim is imported from the source.
Q09 must measure portfolio correlation after the carrier survives Q02-Q08.

## Source And Evidence Boundary

The single canonical source is Mehlitz and Auer (2024), *The European Journal
of Finance* 30(8), 773-802, DOI `10.1080/1351847X.2023.2220118`. Its complete
open precursor is Chapter 3 of Mehlitz's 2021 doctoral thesis, pp. 51-74 with
Appendix C on pp. 110-113. The chapter was reviewed end-to-end.

The source universe explicitly includes WTI. Its `R1-q2` rule combines the
sign of the most recent monthly return with a q=2 Lo-MacKinlay variance ratio
estimated on 32 monthly log returns. Only a two-sided 10% significant variance
ratio is actionable. No source return, Sharpe ratio, drawdown, trade count,
correlation, or constituent statistic is imported into a QM gate or forecast.

## Concept And Non-Duplicate Decision

At the first completed D1 transition into each broker month:

1. Derive 33 completed month-end closes from completed D1 bars and form 32
   chronological monthly log returns.
2. Estimate first-order autocorrelation and `VR(2) = 1 + rho_hat(1)`.
3. Estimate the heteroskedasticity-robust Lo-MacKinlay standard error from the
   source equation (3.3).
4. Require `abs((VR-1)/se) > 1.64485362695147`.
5. Multiply the sign of the latest one-month return by the sign of the test:
   significant persistence continues the return; significant anti-persistence
   reverses it.
6. Stay flat on insignificant memory, zero return, invalid arithmetic, or
   incomplete history.

This is mechanically distinct from:

- `QM5_11070_persistent-anti`, a weekly direction-transition counter with no
  variance-ratio estimator or statistical test;
- the Chan time-series-momentum card, whose approved rule uses an N-day return
  sign and overlapping slots rather than the locked monthly `R1-q2` matrix;
- `QM5_12784_progo-xti`, a D1 overnight/session-flow crossover; and
- existing energy momentum/carry, factor rank, ratio, calendar, oscillator,
  breakout, seasonality, and mean-reversion sleeves.

The repository dedup tool found no exact slug or strategy-ID collision. Manual
review cleared the generic `energy-*` fuzzy matches and the educational `SRC05`
variance-ratio mention because none implements this four-state source rule.

## Markets And Timeframe

- Traded symbol: `XTIUSD.DWX`, magic slot 0.
- Host timeframe: D1.
- Signal data: 33 completed month-end closes derived from completed D1 bars /
  32 monthly log returns. Native MN1 bars are not required in the tester.
- Signal cadence: first new XTI D1 bar of each broker month.
- Holding cadence: until the next broker month, with a 35-calendar-day stale
  guard and broker-side hard stop.
- Expected density: approximately 6-10 completed trades/year after warm-up;
  Q02 retires below five completed trades/year.
- Runtime inputs: native MT5 monthly/D1 prices, ATR, spread, broker calendar,
  framework position/deal state, and no external feed.

## 4. Entry Rules

- Evaluate only on a new D1 bar and only when the current broker-month key
  differs from the preceding completed D1 bar's month key.
- Group completed D1 bars by broker calendar month, retain each month's last
  close, require at least 33 completed month-end closes, and form the latest 32
  log returns in chronological order.
- Compute the mean and sum of squared deviations across the 32 returns.
- Estimate first-order autocorrelation as the lag-one cross-product sum divided
  by the full squared-deviation sum.
- Set `VR(2) = 1 + rho_hat(1)`.
- Estimate the q=2 robust variance-ratio standard error as the square root of
  the sum of adjacent squared-deviation products divided by the squared full
  sum of squared deviations.
- Set `z = (VR(2)-1)/se`. Require finite arithmetic and
  `abs(z) > 1.64485362695147`.
- Let `m` be the sign of the latest monthly return and `p` the sign of z.
  Enter long when `m*p > 0`; enter short when `m*p < 0`.
- Stay flat on an insignificant test, zero latest return, incomplete history,
  nonpositive price, zero denominator, or invalid number.
- Require no current EA position, no current-month entry deal, spread within
  1500 points, valid ATR, and entry news compliance.
- Attach a frozen `ATR(20, D1) * 3.0` stop and no take-profit.
- Size through the V5 framework's fixed stop-risk model. Q02 uses
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- Permit at most one entry attempt per broker month, including after restart or
  a same-month hard stop.

## 5. Exit Rules

- On the first tradable D1 bar of the next broker month, close the existing
  position before considering the new month's signal.
- Close after 35 calendar days as a stale-position guard.
- Broker hard stop remains authoritative between D1 bars.
- A stop-out does not permit same-month re-entry.
- Friday close is disabled only to preserve the source's one-month hold.

## 6. Filters (No-Trade Module)

- Fail closed unless the host is exactly `XTIUSD.DWX`, D1, slot 0, EA 13134.
- Lock the source baseline to `R=1`, `q=2`, 32 monthly returns, two-sided 10%
  significance, and one-month lifecycle.
- Reject invalid parameters, incomplete D1/month-end history, nonpositive closes,
  nonfinite log returns, zero variance or robust standard error, invalid ATR,
  excessive spread, duplicate position, or current-month entry history.
- The framework kill switch remains authoritative. News compliance gates new
  entries only and never blocks month transition or stale-position exits.

## 7. Trade Management Rules

- Exactly one position is allowed for the registered XTI magic.
- Manage month transition and stale exits before the entry news gate.
- Do not trail, break even, partially close, scale in, pyramid, grid, martingale,
  adapt parameters, use PnL feedback, or import external data.
- No RSI, MACD, stochastic, Bollinger, ML, ONNX, or banned indicator is used.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_vr_window_months` | 32 | [32] | source test window |
| `strategy_vr_q` | 2 | [2] | source `R1-q2` order |
| `strategy_significance_z` | 1.64485362695147 | [1.64485362695147] | two-sided 10% gate |
| `strategy_history_bars_d1` | 1200 | [900, 1200, 1600] | tester-safe buffer used only to recover 33 month ends |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | hard-stop ATR |
| `strategy_atr_sl_mult` | 3.0 | [2.5, 3.0, 4.0] | frozen stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard |
| `strategy_max_spread_points` | 1500 | [1000, 1500, 2500] | XTI entry spread cap |

The return interval, monthly cadence, 32-observation window, q=2 estimator,
robust test, critical value, continuation/reversal matrix, and no same-month
re-entry are locked. Changing one requires a new card and full pipeline run.

## Author Claim

The source's actionable matrix is: persistent winners long, persistent losers
short, anti-persistent winners short, and anti-persistent losers long. It
requires significance at 10% over 32 months and specifies no position when the
variance ratio is not significantly different from one. No performance number
is imported.

## Initial Risk Profile And Kill Criteria

- `expected_pf: 1.03` is only a conservative queue-ordering prior.
- `expected_dd_pct: 25.0` reflects single-WTI concentration, CFD gaps and roll,
  slow signal updates, and a narrow port of a diversified source portfolio.
- Fail Q02 below five completed trades/year, on zero trades, risk-mode mismatch,
  invalid monthly history, nondeterminism, or unacceptable baseline economics.
- Do not relax significance, shorten the 32-month test, substitute D1 returns,
  add trend confirmation, remove anti-persistence reversal, or allow same-month
  re-entry to rescue a sparse or losing baseline.
- Treat the futures-index-to-continuous-CFD translation as a falsification risk,
  not a waiver ground.

## Strategy Allowability Check

- [x] R1 reputable: one peer-reviewed journal source with DOI and a complete
  openly readable doctoral precursor of the strategy chapter.
- [x] R2 mechanical: estimator, critical value, direction matrix, cadence,
  stop, sizing, exits, and restart-safe monthly attempt rule are deterministic.
- [x] R3 testable: registered native `XTIUSD.DWX` D1 prices and broker metadata
  are sufficient; WTI appears in the source universe and monthly closes are
  deterministically derived from completed D1 bars.
- [x] R4 compliant: no ML, banned indicator, external feed, random path, grid,
  martingale, pyramiding, or more than one position per magic.
- [x] Expected source-aligned activity is above the five-trade Q02 floor.
- [x] Exact dedup is clean and fuzzy matches were manually rejected.

## Risk

Backtests use only `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. There is no live setfile. This card authorizes no T_Live
change, AutoTrading action, deploy manifest, portfolio gate, admission file, or
portfolio KPI edit.

## Framework Alignment

- no_trade: exact symbol/timeframe/slot, fixed estimator, history, arithmetic,
  spread, ATR, position, and current-month deal guards.
- trade_entry: monthly four-state `R1-q2` direction with frozen ATR stop and
  framework fixed-risk sizing.
- trade_management: next-month reset, 35-day stale close, and restart-safe deal
  guard.
- trade_close: framework close helper plus broker-side hard stop.

## Hard Rules At Risk

- `friday_close`: disabled only because weekly flattening conflicts with the
  source's monthly hold; any future live use requires separate review.
- `risk_mode_dual`: Q02 setfile uses only RISK_FIXED; no live setfile exists.
- `cfd_futures_basis`: Darwinex XTI is a continuous CFD proxy, not the source's
  fully collateralized futures index.
- `enhancement_doctrine`: signal, sample, significance, or cadence changes are
  new entry hypotheses and invalidate prior evidence.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial source-backed WTI variance-ratio build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-11 | APPROVED by OWNER mission directive | this card |
| Q01 Build Validation | 2026-07-11 | PASS | `artifacts/qm5_13134_build_result.json` |
| Q02 Baseline Screening | 2026-07-11 | ENQUEUED; pending and unclaimed | work item `3b9928b5-3fdc-4866-b9c0-b73556e40e13` |

## Lessons Captured

- 2026-07-11: D1 month-end reconstruction preserves the source's monthly
  observation interval without depending on unavailable custom-symbol MN1
  tester bars. This is data plumbing, not a signal enhancement.
