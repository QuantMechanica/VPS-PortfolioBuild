---
ea_id: QM5_13108
slug: xti-mtsm-s2
type: strategy
strategy_id: LIU-MTSM-2021_XTI_S01
source_id: LIU-MTSM-2021
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Liu, Z.; Lu, S.; and Wang, S. (2021). Asymmetry, tail risk and time series momentum. International Review of Financial Analysis 78, 101938."
source_citations:
  - type: paper
    citation: "Liu, Zhenya; Lu, Shanglin; and Wang, Shixuan (2021). Asymmetry, tail risk and time series momentum. International Review of Financial Analysis 78, 101938."
    location: "Full paper; especially Sections 3.1-4.4, pp. 9-31; DOI https://doi.org/10.1016/j.irfa.2021.101938; accepted manuscript https://centaur.reading.ac.uk/100824/1/FINANA-D-21-00329-R1.pdf"
    quality_tier: A
    role: primary
source_links:
  - "https://doi.org/10.1016/j.irfa.2021.101938"
  - "https://centaur.reading.ac.uk/100824/1/FINANA-D-21-00329-R1.pdf"
sources:
  - "[[sources/LIU-MTSM-2021]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/asymmetric-partial-moments]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [n-period-max-continuation, signal-reversal-exit, symmetric-long-short, atr-hard-stop, friday-close-flatten]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13108_XTI_MTSM_S2_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 state changes plus framework weekend packages; estimate 20-52 completed trades/year on XTIUSD.DWX before Q02 validation."
expected_trades_per_year_per_symbol: 30
expected_pf: 1.05
expected_dd_pct: 20.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Adds tail-state-managed WTI momentum/reversal exposure to the XAU/SP500/NDX/XNG book; the driver is oil-specific directional persistence and reversal risk, with realized correlation deferred to Q09."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, enhancement_doctrine, cfd_futures_basis]
g0_approval_reasoning: "Mission-directed G0: R1 peer-reviewed IRFA 2021 DOI/full institutional manuscript; R2 fixed 30D momentum plus 5D UPM/LPM 80th-percentile MTSM-S2 map; R3 native XTIUSD.DWX D1 closes; R4 deterministic non-ML logic; pre-allocation dedup CLEAN."
---

# XTI Managed Time-Series Momentum S2

## Hypothesis

Commodity time-series momentum can fail abruptly when the most recent upside
and downside return energy becomes asymmetric. Liu, Lu, and Wang split recent
returns into upper and lower partial moments and use their joint tail state to
override a base momentum direction before a reversal deepens. This card tests
that structural state machine on WTI, adding a crude-oil return driver rather
than another index, metal, RSI, calendar-month, inventory-event, or channel
variant.

The primary evidence is portfolio-level Chinese commodity-futures evidence,
not WTI evidence. `XTIUSD.DWX` is an explicit carrier port. The source's
direction logic is retained; V5 `RISK_FIXED` sizing, an ATR hard stop, a bounded
historical quantile window, and Friday flatten are transparent implementation
adaptations. Q02 must reject the port if its single-symbol economics do not
survive those differences.

## Source Citation

Primary source: Liu, Lu, and Wang (2021), *International Review of Financial
Analysis* 78, article 101938, DOI `10.1016/j.irfa.2021.101938`. The complete
accepted manuscript is held by the University of Reading's CentAUR repository.
Sections 3.1-3.2 define the momentum and partial moments; Section 4.1 and Figure
3 define the four regions and MTSM-S2 actions; Sections 4.2-4.4 report the
subsample and crash checks.

One bounded author claim is retained: "upper and lower partial moments can help
to partly predict reversals of time series momentum" (Section 5). The source's
portfolio performance is not a forecast for WTI.

## Concept And Non-Duplicate Decision

On each new D1 bar, use only completed `XTIUSD.DWX` closes. The base state is
the sign of the sum of 30 simple daily returns. The overlay computes the mean
squared positive and negative returns over the latest five completed days,
then compares them with separately calculated 80th-percentile reference levels
from older partial-moment observations.

This is deliberately different from:

- `QM5_12603_wti-tsmom12m` and `QM5_12616_tsmom-9m-commodity-xtiusd`, which
  use slow return signs without an asymmetric tail-state override;
- `QM5_13100_wti-dmac16`, which uses month-end price versus a six-month mean;
- `QM5_12594_yang-wti-reversal` and `QM5_12621_comm-reversal-4wk-xtiusd`,
  which fade medium/short return extremes without joint partial moments;
- `QM5_12844_commodity-trend-crude`, which uses Donchian/ADX breakout state;
- `QM5_12567_cum-rsi2-commodity`, which is a short-horizon RSI pullback;
- all WTI event, inventory, OPEC, roll, calendar, ratio, commodity-FX, NR7,
  IDNR4, volatility-shock, and simple moving-average builds.

Repository dedup returned `CLEAN`, and a content search found no upper/lower
partial-moment or MTSM implementation.

## Target Market And Timeframe

- Symbol: `XTIUSD.DWX`, magic slot 0.
- Timeframe: D1 only.
- Expected frequency: 20-52 completed packages/year before Q02; binding floor
  remains five trades/year/symbol.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

### State Calculation

- Run once on a new `XTIUSD.DWX` D1 bar using completed closes only.
- Base momentum is the arithmetic sum of the latest
  `strategy_momentum_days=30` simple close-to-close returns.
- Current UPM is the mean of squared positive returns over the latest
  `strategy_partial_moment_days=5` returns; non-positive observations
  contribute zero.
- Current LPM is the mean of squared negative returns over the same five
  returns; non-negative observations contribute zero.
- Build older UPM and LPM samples from the immediately preceding
  `strategy_percentile_history=252` completed observations. Each historical
  observation uses its own five returns. No sample may contain the current
  five-return window or a future close.
- Compute separate nearest-rank
  `strategy_tail_percentile=80` reference levels. A current value at or above
  its positive reference is in the tail.
- Fail closed if required history, prices, returns, or percentile levels are
  invalid.

### MTSM-S2 Target Map

- Region 1, UPM tail and LPM tail: target flat.
- Region 2, only LPM tail: target long regardless of base momentum.
- Region 3, neither tail: target long if 30-day cumulative return is positive,
  otherwise target short.
- Region 4, only UPM tail: target short regardless of base momentum.

The S2 region map is locked. MTSM-S1 is not an allowed sweep axis.

### Entry

- If target is long and no magic position is open, buy at market.
- If target is short and no magic position is open, sell at market.
- Place a frozen ATR(`strategy_atr_period=20`) times
  `strategy_atr_sl_mult=3.0` broker-side hard stop.
- Reject entry if symbol/timeframe/slot/parameters/history/ATR/spread are
  invalid or spread exceeds `strategy_max_spread_points=1500`.

### Exit And Management

- On a new D1 state, close if the target is flat or opposite to the open side.
- A same-bar reversal may enter only after the old position is confirmed
  closed by the framework trade manager.
- Close an unknown-history position rather than carrying an unevaluable state.
- Close a position older than `strategy_max_hold_days=8` as a stale safeguard.
- Framework Friday close remains enabled at broker hour 21. A persistent
  target may form a new package after the weekend.
- No take profit, trailing stop, break-even move, partial close, grid,
  martingale, pyramiding, external data, adaptive PnL logic, or discretionary
  switch.

## Filters

- Exact symbol/timeframe guard: `XTIUSD.DWX`, D1.
- Magic slot 0 and one position per magic/symbol.
- Parameter-domain, history, arithmetic, percentile, ATR, and spread guards
  fail closed.
- Standard V5 kill switch, news compliance, connection protection, and Friday
  close stay authoritative.

## Parameters To Test

| param | default | authorized range | role |
|---|---:|---|---|
| `strategy_momentum_days` | 30 | [20, 30, 40] | source-tested base momentum horizon |
| `strategy_partial_moment_days` | 5 | [5] | source-defined weekly partial-moment window |
| `strategy_percentile_history` | 252 | [126, 252, 504] | bounded no-lookahead approximation to recursive history |
| `strategy_tail_percentile` | 80.0 | [80.0] | source-defined tail reference |
| `strategy_atr_period` | 20 | [14, 20, 30] | V5 hard-stop volatility estimate |
| `strategy_atr_sl_mult` | 3.0 | [2.5, 3.0, 4.0] | V5 hard-stop distance |
| `strategy_max_hold_days` | 8 | [7, 8] | stale safeguard around Friday flatten |
| `strategy_max_spread_points` | 1500 | [1000, 1500, 2000] | entry spread cap |

The five-day window, 80th percentile, S2 action map, D1 carrier, and symmetric
direction are locked. Later phases may not introduce S1, a new indicator, an
event feed, or a post-hoc region map.

## Author Claims

The authors report that the managed portfolio improved risk-adjusted results
across lookbacks and reduced drawdown in their out-of-sample and COVID checks.
Those are diversified Chinese-futures results with daily volatility scaling
and no transaction costs. They do not validate WTI, Darwinex CFD basis/spread,
Friday packages, fixed-risk sizing, or the 252-observation reference window.

## Initial Risk Profile

- `expected_pf: 1.05` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 20.0` is a risk-budget prior, not a forecast.
- Risk is high because the source is not WTI-specific and the fixed-risk port
  omits the paper's daily volatility scaling.
- Source sizing is incompatible with the V5 backtest contract; use
  `RISK_FIXED=1000`, never a volatility-targeted lot override.

## Strategy Allowability Check

- [x] Mechanical D1 price-state strategy.
- [x] Peer-reviewed primary source with DOI and complete institutional copy.
- [x] No ML, prohibited runtime input, grid, martingale, pyramiding, or
  discretionary judgment.
- [x] Expected frequency is above the Q02 floor.
- [x] Friday close remains enabled and risk is bounded by a broker-side stop.
- [x] Non-duplicate against WTI momentum, reversal, trend, breakout, calendar,
  event, ratio, carry, volatility, and RSI inventory.

## Framework Alignment

- no_trade: exact carrier, timeframe, slot, parameter, history, arithmetic,
  percentile, ATR, spread, and one-position guards; framework protections stay
  active.
- trade_entry: MTSM-S2 target long/short opens at market with a frozen ATR
  hard stop.
- trade_management: each new D1 state closes unknown, flat, opposed, or stale
  exposure.
- trade_close: state change, stale guard, broker ATR stop, and framework Friday
  flatten.

## Risk

Q02 falsifies the card if realized density is below five completed trades/year,
the strategy fails economics/drawdown criteria, or evidence is invalid. The
Chinese-portfolio-to-WTI port, recursive-to-rolling percentile approximation,
volatility-scaling removal, and futures-to-CFD basis are explicit kill risks.
Portfolio correlation is not inferred and may only be measured at Q09 after a
surviving return stream exists.

This build must not touch `T_Live`, AutoTrading, a deploy manifest, a live
setfile, the portfolio gate, portfolio admission, or portfolio KPI code.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial MTSM-S2 WTI carrier build | Q02 | PLANNED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by mission directive | this card |
| Q01 Build Validation | TBD | TBD | TBD |
| Q02 Baseline Screening | TBD | TBD | TBD |

