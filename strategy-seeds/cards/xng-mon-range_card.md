---
ea_id: QM5_13104
slug: xng-mon-range
type: strategy
strategy_id: MU-XNG-MONVOL-2007_S01
source_id: MU-XNG-MONVOL-2007
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Mu, Xiaoyi. Weather, Storage, and Natural Gas Price Dynamics: Fundamentals and Volatility. Energy Economics 29(1), 2007, pp. 46-63. DOI 10.1016/j.eneco.2006.04.003."
source_citations:
  - type: paper
    citation: "Mu, Xiaoyi. Weather, Storage, and Natural Gas Price Dynamics: Fundamentals and Volatility. Energy Economics 29(1), 2007, pp. 46-63. DOI 10.1016/j.eneco.2006.04.003."
    location: "Journal pp. 46-63; complete author working paper pp. 1-30, especially pp. 7, 11, 17-20 and Tables 2, 4A, 4B, 5A, 5B."
    quality_tier: A
    role: primary
source_links:
  - "https://doi.org/10.1016/j.eneco.2006.04.003"
  - "https://www.iaee.org/en/students/best_papers/xiaoyi_mu2.pdf"
sources:
  - "[[sources/MU-XNG-MONVOL-2007]]"
concepts:
  - "[[concepts/natural-gas-monday-volatility]]"
  - "[[concepts/friday-compression-monday-expansion]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [narrow-range-breakout, vol-regime-gate, atr-hard-stop, time-stop, symmetric-long-short, friday-close-flatten]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_13104_XNG_MON_RANGE_H4
period: H4
timeframes: [H4, D1]
expected_trade_frequency: "Once-weekly eligible XNG Monday H4 expansion after a compressed Friday; estimate 8-20 completed trades/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.05
expected_dd_pct: 24.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Adds weekly natural-gas volatility-expansion exposure to the XAU/SP500/NDX/XNG book; unlike QM5_12567 it is symmetric breakout logic, and any return-stream orthogonality claim remains for Q09 evidence."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-10: R1 PASS peer-reviewed Energy Economics paper plus complete primary-author working paper; R2 PASS fixed Friday compression and Monday H4 close-expansion rule with structural SL, fixed-R target, and Tuesday/time exit; R3 PASS XNGUSD.DWX H4/D1 data registered; R4 PASS native OHLC/ATR only with no GARCH runtime, ML, grid, martingale, or external feed."
---

# XNG Monday Range Expansion

## Hypothesis

Mu finds that natural-gas futures have materially higher conditional volatility
on Mondays, while the paper does not establish a dependable Monday return
direction. The QM expression is therefore symmetric: after a relatively
compressed Friday, enter only when a completed Monday H4 bar closes beyond the
Friday range, then flatten when Monday ends or the fixed time stop expires.

The return driver is weekly natural-gas information accumulation and range
expansion. It is not the cumulative-RSI2 pullback logic in `QM5_12567`, a fixed
Monday long/Friday short calendar bet, or the existing Monday weekend-gap
continuation rule: the Monday D1 open must remain inside Friday's range, so a
weekend gap is explicitly excluded.

## Source Citation

The primary source is Mu's peer-reviewed *Energy Economics* paper, DOI
`10.1016/j.eneco.2006.04.003`. The complete primary-author working-paper
version was reviewed end-to-end, including its methodology, empirical results,
tables, references, and appendices. It studies daily nearest- and second-month
natural-gas futures from 1997 through 2000, models a Monday dummy in the
conditional variance, and reports a positive, statistically significant Monday
coefficient across the reported specifications.

The paper supplies the Monday volatility anomaly, not a trading system. The
compressed-Friday setup, H4 close confirmation, structural stop, and fixed-R
target are an explicit falsifiable QM mechanization. No source performance is
imported and no GARCH model runs inside the EA.

## Concept

Only `XNGUSD.DWX` H4/D1 OHLC, ATR, spread, broker calendar, and V5 framework
state are read. There is no weather forecast, storage report, futures curve,
volume, open interest, API, CSV, GARCH fit, ML model, adaptive sizing, grid,
martingale, pyramiding, or discretionary switch.

## Target Symbols And Period

- Symbol: `XNGUSD.DWX`, magic slot 0.
- Host period: H4; D1 supplies the completed Friday range and ATR scale.
- Expected frequency: 8-20 trades/year; Q02 enforces the binding five-trades-
  per-year floor.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Rules

### Setup

- Evaluate only on a new `XNGUSD.DWX` H4 bar.
- The current D1 session and the prior completed H4 signal bar must both be
  broker-calendar Monday.
- The prior completed D1 bar must be broker-calendar Friday.
- Friday's high-low range must be between
  `strategy_min_friday_range_atr * ATR(D1, 20)` and
  `strategy_max_friday_range_atr * ATR(D1, 20)`.
- Monday's D1 open must lie inside Friday's high-low range. This rejects the
  weekend-gap family already represented by `QM5_12738`.
- A setup is eligible for at most one entry package per Monday.

### Entry

- Long when the prior completed Monday H4 bar closes above Friday high plus
  `strategy_break_buffer_atr * ATR(D1, 20)`, is bullish, and closes in at least
  the top `strategy_min_close_location` fraction of its own range.
- Short when that H4 bar closes below Friday low minus the same ATR buffer, is
  bearish, and closes in at most the bottom complementary range fraction.
- Entry is at market on the next Monday H4 bar after close confirmation.
- Reject if spread exceeds `strategy_max_spread_points`, a position for this
  magic is open, or H4/D1/ATR data are invalid.

### Stop And Target

- Long stop: Friday low minus `strategy_stop_buffer_atr * ATR(D1, 20)`.
- Short stop: Friday high plus the same ATR buffer.
- Profit target: `strategy_rr_target` times actual entry-to-stop risk, default
  2R.
- The structural stop and target are fixed when the trade opens.

### Exit And Management

- Close on the first broker-calendar tick outside Monday if stop/target has not
  fired.
- Also close after `strategy_max_hold_hours`, default 30 hours, as a stale-
  position guard.
- Framework Friday close remains enabled at broker hour 21.
- No partial close, break-even move, trailing stop, reversal, grid, martingale,
  or pyramiding in v1.

## Filters

- Exact symbol/timeframe guard: `XNGUSD.DWX`, H4.
- Magic slot must be 0; one position per magic/symbol.
- Parameter-domain, Friday-compression, non-gap, open-position, and spread
  guards fail closed.
- Standard V5 kill switch, news compliance, Friday close, and connection
  protections remain authoritative.

## Parameters To Test

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_friday_range_atr
  default: 0.15
  sweep_range: [0.10, 0.15, 0.25]
- name: strategy_max_friday_range_atr
  default: 0.85
  sweep_range: [0.65, 0.85, 1.05]
- name: strategy_break_buffer_atr
  default: 0.05
  sweep_range: [0.00, 0.05, 0.10]
- name: strategy_min_close_location
  default: 0.60
  sweep_range: [0.55, 0.60, 0.70]
- name: strategy_stop_buffer_atr
  default: 0.10
  sweep_range: [0.05, 0.10, 0.20]
- name: strategy_rr_target
  default: 2.00
  sweep_range: [1.50, 2.00, 2.50]
- name: strategy_max_hold_hours
  default: 30
  sweep_range: [18, 24, 30]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

"the conditional volatility is considerably higher on Monday" (complete
primary-author working paper, p. 17; published journal version pp. 46-63).

No directional-return or trading-performance claim is imported.

## Initial Risk Profile

- `expected_pf: 1.05` is a conservative ordering prior, not evidence.
- `expected_dd_pct: 24.0` is a risk-budget prior, not a forecast.
- Natural-gas gaps and a Friday-range structural stop make risk class high.
- Source silent on V5 sizing; backtests use `RISK_FIXED=1000`.

## Strategy Allowability Check

- [x] Mechanical native-price volatility setup and close-confirmed entry.
- [x] No GARCH runtime, ML, external feed, grid, martingale, or pyramiding.
- [x] Expected frequency is above the Q02 five-trades/year floor before test.
- [x] Friday close remains enabled.
- [x] Peer-reviewed primary citation and complete author manuscript are
  precisely identified and reproducible.
- [x] Non-duplicate against XNG cumulative RSI2, fixed weekday direction,
  weekend gap, storage, weather-event, expiry, monthly ORB, squeeze, long-term
  momentum/reversal, carry, relative-value, and volatility-shock-fade builds.

## Framework Alignment

- no_trade: symbol/timeframe, magic-slot, parameter, open-position, non-gap,
  Friday-compression, and spread guards; framework protections remain active.
- trade_entry: completed Monday H4 close beyond a compressed Friday range;
  structural stop and fixed-R target.
- trade_management: Tuesday/session-end flatten and max-hold close only.
- trade_close: hard structural SL/TP, session/time close, and framework Friday
  flatten.

## Risk

Q02 falsifies the card if realized density is below five trades/year, the
strategy fails phase economics/drawdown gates, or the report is missing or
invalid. Correlation is not inferred here; only Q09 surviving return evidence
may decide portfolio orthogonality. This build must not touch `T_Live`,
AutoTrading, a deploy manifest, the portfolio gate, or a live setfile.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial XNG Monday range-expansion build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by mission directive | this card |

