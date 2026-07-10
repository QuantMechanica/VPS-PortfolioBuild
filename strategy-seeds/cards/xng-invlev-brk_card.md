---
ea_id: QM5_13111
slug: xng-invlev-brk
type: strategy
strategy_id: KRISTOUFEK-XNG-INVLEV-2014_S01
source_id: KRISTOUFEK-ENERGY-LEV-2014
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Kristoufek, Ladislav. Leverage effect in energy futures. Energy Economics 45 (2014), 1-9. DOI 10.1016/j.eneco.2014.06.009."
source_citations:
  - type: paper
    citation: "Kristoufek, Ladislav. (2014). Leverage effect in energy futures. Energy Economics 45, 1-9."
    location: "Complete paper; especially Data and Results pp. 5-7, Table 4, and Conclusion pp. 7-8; DOI https://doi.org/10.1016/j.eneco.2014.06.009; institutional full text https://library.utia.cas.cz/separaty/2014/E/kristoufek-0433531.pdf"
    quality_tier: A
    role: primary
  - type: paper
    citation: "Carnero, M. Angeles and Perez, Ana. (2019). Leverage effect in energy futures revisited. Energy Economics 82, 237-252."
    location: "Replication and sensitivity analysis; DOI https://doi.org/10.1016/j.eneco.2017.12.029; accepted manuscript https://uvadoc.uva.es/bitstream/handle/10324/37950/ENEECO3868.pdf"
    quality_tier: A
    role: supplement
source_links:
  - "https://doi.org/10.1016/j.eneco.2014.06.009"
  - "https://library.utia.cas.cz/separaty/2014/E/kristoufek-0433531.pdf"
  - "https://doi.org/10.1016/j.eneco.2017.12.029"
sources:
  - "[[sources/KRISTOUFEK-ENERGY-LEV-2014]]"
concepts:
  - "[[concepts/natural-gas-inverse-leverage]]"
  - "[[concepts/positive-impulse-volatility]]"
  - "[[concepts/close-confirmed-range-expansion]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [vol-regime-gate, atr-hard-stop, time-stop, symmetric-long-short, friday-close-flatten]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_13111_XNG_INVLEV_BRK_H4
period: H4
timeframes: [H4, D1]
expected_trade_frequency: "Once-weekly-capped XNG H4 expansion after a large same-session positive impulse; estimate 8-20 completed trades/year before Q02 validation."
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
review_focus: "Adds positive-return-conditioned, direction-neutral natural-gas volatility exposure to the XAU/SP500/NDX/XNG book. It is not the incumbent RSI pullback or a calendar/trend direction bet; Q09 alone may establish return-stream orthogonality."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine, cfd_futures_basis]
g0_approval_reasoning: "Mission-directed G0 approval on 2026-07-10: R1 PASS peer-reviewed Energy Economics primary paper reviewed end-to-end plus peer-reviewed replication; R2 PASS fixed positive H4/D1 impulse regime, separate completed-H4 range confirmation, structural SL, fixed-R target, weekly gate, and time exit; R3 PASS registered XNGUSD.DWX H4/D1 data; R4 PASS native OHLC/ATR only with no DCCA/DMCA/GARCH/Hurst runtime, ML, grid, martingale, or external feed."
---

# XNG Inverse-Leverage Range Breakout

## Hypothesis

Kristoufek finds a statistically significant positive relationship between
standardized natural-gas futures returns and logarithmic range volatility,
opposite the standard leverage effect reported for crude oil. The source does
not establish a directional return premium or a long-lived forecast. This card
therefore uses a completed positive same-session impulse only as a short-lived
volatility regime, then requires a separate completed H4 bar to break the
impulse bar's range and discover trade direction.

The portfolio role is asymmetric natural-gas volatility exposure. It is not a
bet that gas must keep rising after a positive shock: a close through the setup
high buys expansion, while a full close through the setup low sells a violent
reversal. The weekly gate keeps the expression low-frequency and prevents a
single gas shock from creating a cluster of correlated entries.

## Source Citation

The primary source is the peer-reviewed *Energy Economics* article, DOI
`10.1016/j.eneco.2014.06.009`. The complete paper was reviewed, including its
nonparametric range-volatility method, long-memory treatment, front-futures
sample from 2000 through June 2013, Tables 1-5, and conclusions.

Table 4 reports positive natural-gas return/volatility correlations for both
detrended methods, whereas Brent and WTI correlations are negative. The paper
also reports weak effect sizes and no long-range cross-correlation. The 2019
peer-reviewed replication is included as a supplement because it finds that
natural-gas significance depends on methodology and return definition.

Neither source publishes this breakout system. The partial-D1 positive
impulse, H4 confirmation, weekly gate, stop, target, and hold are explicitly a
falsifiable CFD mechanization. No source performance number is imported.

## Concept

Only `XNGUSD.DWX` H4/D1 OHLC, D1 ATR, spread, broker calendar, and V5 framework
state are read. There is no futures maturity panel, roll series, storage,
weather, EIA report, GARCH, DCCA/DMCA, Hurst calculation, volume, open interest,
API, CSV, ML model, adaptive fit, grid, martingale, pyramiding, or discretionary
switch.

## Non-Duplicate Boundary

- `QM5_12567_cum-rsi2-commodity`: two-day cumulative-RSI pullback; this card
  has no oscillator and trades only a completed range expansion after a
  positive impulse.
- `QM5_12817_xng-volshock-fade`: symmetric multi-day shock fade toward an SMA;
  this card never fades the impulse directly and requires a later H4 range
  break to choose direction.
- `QM5_13101_xng-1w-mom-vol`: five-D1 directional continuation in low realized
  volatility; this card conditions on an intraday positive impulse, expects
  high volatility, and permits either break direction.
- `QM5_13102_xng-1w-rev-vol`: five-D1 high-volatility return fade; this card is
  not a five-day reversal and does not force a side opposite the shock.
- `QM5_13104_xng-mon-range`: compressed-Friday, Monday-only expansion; this
  card has no weekday or prior-Friday compression gate.
- `QM5_13105_xng-idnr4-brk`: inside/NR4 compression breakout; this card requires
  a large positive impulse and no inside/narrow-range pattern.
- `QM5_13110_xng-svol-brk`: source-calendar breakout of the prior D1 range;
  this card has no month gate and breaks the positive-impulse H4 range.

Repository dedup was clean before EA-ID allocation for slug
`xng-invlev-brk`, strategy ID `KRISTOUFEK-XNG-INVLEV-2014_S01`, and the full
mechanic description.

## Target Symbols And Period

- Symbol: `XNGUSD.DWX`, magic slot 0.
- Host period: H4; the current D1 open and prior completed D1 ATR normalize the
  setup without reading incomplete D1 volatility.
- Expected frequency: 8-20 completed trades/year; Q02 enforces at least five
  trades/year/symbol.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The completed positive impulse forecasts only a short-lived volatility state.
The following completed H4 confirmation bar independently selects long or
short, and the EA enters at the next H4 bar.

## 4. Entry Rules

- Evaluate only on a new `XNGUSD.DWX` H4 bar.
- Load the two immediately prior completed H4 bars: `setup` is older and
  `confirmation` is newer. Setup, confirmation, and the current entry bar must
  share one broker-calendar D1 session.
- Load the current D1 open and prior completed D1 ATR(20).
- Positive impulse regime: setup is bullish, setup close is at least
  `strategy_min_impulse_atr * ATR` above the current D1 open, setup range is
  between `strategy_min_setup_range_atr * ATR` and
  `strategy_max_setup_range_atr * ATR`, and setup close location is at least
  `strategy_min_setup_close_location`.
- Long confirmation: the next completed H4 bar is bullish and closes above
  setup high plus `strategy_break_buffer_atr * ATR`, with close location at or
  above `strategy_min_confirm_close_location`.
- Short confirmation: the next completed H4 bar is bearish and closes below
  setup low minus the same buffer, with close location at or below the
  complementary threshold.
- Enter at market on the next H4 bar in the confirmation direction.
- Reject if this magic has an open position, the broker week already accepted
  an entry, spread exceeds `strategy_max_spread_points`, or data are invalid.

## 5. Exit Rules

- Long stop: setup low minus `strategy_stop_buffer_atr * ATR(D1)`.
- Short stop: setup high plus the same ATR buffer.
- Profit target: `strategy_rr_target`, default 1.50R, times actual
  entry-to-stop distance.
- Close after `strategy_max_hold_hours=24` calendar hours.
- Framework Friday close remains enabled at broker hour 21.
- No signal reversal, break-even move, trailing stop, partial close, or
  same-week re-entry.

## 6. Filters (No-Trade Module)

- Exact symbol/timeframe guard: `XNGUSD.DWX`, H4.
- Magic slot must be 0; one position per magic/symbol.
- Parameter-domain, same-D1-session, H4/D1 history, ATR, impulse, setup range,
  close-location, confirmation, spread, open-position, and weekly gates fail
  closed.
- Standard V5 kill switch, news compliance, Friday close, and connection
  protections remain authoritative.

## 7. Trade Management Rules

- Symmetric long/short after the positive-regime setup; the confirmation bar
  alone determines direction.
- Fixed structural SL and fixed-R TP are placed at entry.
- Only time, broker SL/TP, and framework Friday exits apply.
- No pyramiding, grid, martingale, partial close, trailing, or live adaptation.

## Parameters To Test

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_impulse_atr
  default: 0.75
  sweep_range: [0.60, 0.75, 1.00]
- name: strategy_min_setup_range_atr
  default: 0.35
  sweep_range: [0.25, 0.35, 0.50]
- name: strategy_max_setup_range_atr
  default: 2.50
  sweep_range: [2.00, 2.50, 3.00]
- name: strategy_min_setup_close_location
  default: 0.65
  sweep_range: [0.60, 0.65, 0.75]
- name: strategy_break_buffer_atr
  default: 0.05
  sweep_range: [0.00, 0.05, 0.10]
- name: strategy_min_confirm_close_location
  default: 0.60
  sweep_range: [0.55, 0.60, 0.70]
- name: strategy_stop_buffer_atr
  default: 0.10
  sweep_range: [0.05, 0.10, 0.20]
- name: strategy_rr_target
  default: 1.50
  sweep_range: [1.25, 1.50, 1.75]
- name: strategy_max_hold_hours
  default: 24
  sweep_range: [16, 24, 32]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

The positive-only setup regime, separate confirmation bar, symmetric
confirmation direction, same-D1-session rule, one accepted entry per week, and
absence of calendar/trend/compression filters are locked. No post-hoc direction
or calendar sweep is authorized.

## Author Claims

"For natural gas, we find the inverse leverage effect." (Kristoufek 2014,
abstract and conclusion.)

The source establishes a return/volatility relationship, not breakout
profitability or next-bar direction. The replication weakens confidence in the
natural-gas result; no return, Sharpe, win rate, or PF claim is imported.

## Initial Risk Profile

- `expected_pf: 1.05` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 24.0` is a risk-budget prior, not a forecast.
- Risk class is high because natural-gas impulse breaks can gap or reverse.
- Source silent on V5 sizing; backtests use `RISK_FIXED=1000`.

## Strategy Allowability Check

- [x] Mechanical native-price volatility setup and close-confirmed entry.
- [x] Peer-reviewed primary citation, DOI, complete paper, and exact table.
- [x] Peer-reviewed replication limitation is recorded rather than hidden.
- [x] No DCCA/DMCA/GARCH/Hurst runtime, ML, banned indicator, external feed,
  grid, martingale, pyramiding, or adaptive fitting.
- [x] Expected frequency exceeds the Q02 five-trades/year floor.
- [x] Friday close remains enabled.
- [x] Non-duplicate boundaries are explicit and dedup check is clean.

## Framework Alignment

- no_trade: symbol/timeframe, slot, parameter, same-session, history, ATR,
  impulse, setup-range, close-location, spread, open-position, and weekly
  guards; framework protections remain active.
- trade_entry: positive same-session impulse plus a separate completed H4
  break of the setup range; structural stop and 1.50R target.
- trade_management: 24-hour close only.
- trade_close: broker structural SL/TP, time exit, and framework Friday
  flatten.

## Risk

Q02 falsifies the card if realized density is below five completed trades/year,
economics/drawdown gates fail, or the report is missing/invalid. The
front-futures daily result to continuous-CFD partial-D1/H4 translation is an
explicit basis risk. Correlation is not inferred; Q09 alone may measure
orthogonality after survival.

This build must not touch `T_Live`, AutoTrading, a deploy manifest, a live
setfile, the portfolio gate, portfolio admission, or portfolio KPI code.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial XNG inverse-leverage volatility build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by mission directive | this card |
| Q01 Build Validation | 2026-07-10 | PASS; strict compile/build check; smoke deferred at CPU ceiling | `artifacts/qm5_13111_build_result.json` |
| Q02 Baseline Screening | 2026-07-10 | QUEUED; pending and unclaimed | work item `91fa45bb-7c0e-47f3-91dd-238689b7884b` |
