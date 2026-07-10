---
ea_id: QM5_13112
slug: xti-levbrk
type: strategy
strategy_id: KRISTOUFEK-XTI-LEV-2014_S02
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
    location: "Complete paper; especially Data and Results pp. 6-7, Figure 3, and Conclusion pp. 7-8; DOI https://doi.org/10.1016/j.eneco.2014.06.009; institutional full text https://library.utia.cas.cz/separaty/2014/E/kristoufek-0433531.pdf"
    quality_tier: A
    role: primary
source_links:
  - "https://doi.org/10.1016/j.eneco.2014.06.009"
  - "https://library.utia.cas.cz/separaty/2014/E/kristoufek-0433531.pdf"
sources:
  - "[[sources/KRISTOUFEK-ENERGY-LEV-2014]]"
concepts:
  - "[[concepts/crude-oil-leverage-effect]]"
  - "[[concepts/negative-impulse-volatility]]"
  - "[[concepts/close-confirmed-downside-continuation]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [vol-regime-gate, atr-hard-stop, time-stop, friday-close-flatten]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13112_XTI_LEVBRK_H4
period: H4
timeframes: [H4, D1]
expected_trade_frequency: "Once-weekly-capped WTI H4 downside continuation after a large completed negative D1 impulse; estimate 6-14 completed trades/year before Q02 validation."
expected_trades_per_year_per_symbol: 9
expected_pf: 1.05
expected_dd_pct: 22.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Adds negative-shock WTI downside-trend exposure to the XAU/SP500/NDX/XNG book. It is neither the incumbent commodity RSI pullback nor an ordinary symmetric WTI momentum rule; only Q09 return evidence may establish orthogonality."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine, cfd_futures_basis]
g0_approval_reasoning: "Mission-directed G0 approval on 2026-07-10: R1 PASS peer-reviewed Energy Economics primary paper reviewed end-to-end; R2 PASS fixed negative D1 impulse regime, later completed-H4 downside break, structural SL, fixed-R target, weekly gate, and time exit; R3 PASS registered XTIUSD.DWX H4/D1 data; R4 PASS native OHLC/ATR only with no DCCA/DMCA/GARCH/Hurst runtime, ML, grid, martingale, or external feed."
---

# XTI Negative-Impulse Leverage Breakout

## Hypothesis

Kristoufek finds a stable, statistically significant standard leverage effect
for WTI and Brent crude-oil futures: returns and range-based volatility are
negatively related, and the effect is stronger at longer measurement scales.
The source does not establish return continuation or publish a trading rule.
This card therefore treats a large completed negative `XTIUSD.DWX` D1 candle
only as a short-lived high-volatility regime, then requires a later completed
H4 close below that impulse day's low before taking a short trend-continuation
position.

The portfolio role is asymmetric crude-oil downside expansion. It is not a
general long/short momentum system and never buys after a positive shock. One
accepted entry per broker week prevents a single oil selloff from generating a
cluster of correlated entries.

## Source Citation

The primary source is the peer-reviewed *Energy Economics* article, DOI
`10.1016/j.eneco.2014.06.009`. The complete nine-page paper was reviewed,
including the literature review, Garman-Klass range-volatility construction,
long-memory tests, detrended correlation methods, 2000-2013 front-futures
sample, Tables 1-4, Figure 3, conclusion, and references.

The paper reports negative WTI return/volatility correlations of roughly
0.2-0.3 in magnitude across its detrended measures, statistically significant
and stronger at longer scales. It also reports no long-range return/volatility
cross-correlation, and its literature review records mixed earlier WTI
asymmetry evidence. Those limitations are retained: no source return, Sharpe,
win rate, or PF claim is imported.

## Concept

Only native `XTIUSD.DWX` H4/D1 OHLC, prior-completed D1 ATR, spread, broker
calendar, and V5 framework state are read. There is no futures roll series,
curve, inventory, options, WPSR, COT, DCCA/DMCA, GARCH, Hurst calculation,
volume, open interest, API, CSV, ML model, adaptive fit, grid, martingale,
pyramiding, or discretionary switch.

## Non-Duplicate Boundary

- `QM5_12567_cum-rsi2-commodity`: two-day cumulative-RSI pullback; this card
  has no oscillator and follows downside expansion rather than buying a dip.
- `QM5_12603_wti-tsmom12m`, `QM5_12616_tsmom-9m-commodity-xtiusd`, and
  `QM5_13100_wti-dmac16`: slow symmetric trend systems; this card is short-only
  after a one-day negative volatility impulse and an H4 continuation close.
- `QM5_13049_xti-1w-mom-vol`: symmetric five-D1 momentum in low volatility;
  this card requires a high-volatility negative D1 impulse and cannot go long.
- `QM5_13050_xti-1w-rev-vol` and `QM5_13046_xti-vrp-proxy`: high-volatility
  fades; this card trades with the downside break and never fades it.
- `QM5_13096_xti-nr7-brk` and `QM5_13103_xti-idnr4-brk`: compression
  breakouts; this card requires a wide negative impulse, not a narrow/inside
  setup.
- `QM5_13111_xng-invlev-brk`: positive-impulse, direction-neutral natural-gas
  expansion; this card expresses the opposite source asymmetry on WTI as a
  short-only next-session downside continuation.

Repository dedup was clean before EA-ID allocation for slug `xti-levbrk`,
strategy ID `KRISTOUFEK-XTI-LEV-2014_S02`, and the full mechanic description.

## Target Symbols And Period

- Symbol: `XTIUSD.DWX`, magic slot 0.
- Host period: H4; the prior completed D1 bar supplies the impulse range and a
  pre-impulse completed D1 ATR supplies the normalization.
- Expected frequency: 6-14 completed trades/year; Q02 enforces at least five
  trades/year/symbol.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The source relationship forecasts volatility, not returns. The negative D1
impulse defines the volatility state; the next broker day's completed H4 close
must independently confirm downside continuation before entry.

## 4. Entry Rules

- Evaluate only on a new `XTIUSD.DWX` H4 bar.
- Load the prior completed D1 impulse bar, the current D1 session, the prior
  completed H4 confirmation bar, and ATR calculated with shift 2 so the
  impulse itself does not inflate its threshold.
- The confirmation H4 bar and current entry H4 bar must belong to the first
  broker D1 session after the impulse bar.
- Negative impulse regime: the impulse D1 candle is bearish; its open-to-close
  decline is at least `strategy_min_impulse_atr * ATR`; its full range is
  between `strategy_min_impulse_range_atr * ATR` and
  `strategy_max_impulse_range_atr * ATR`; and its close location is at or below
  `strategy_max_impulse_close_location`.
- Short confirmation: the prior completed H4 bar is bearish, closes below the
  impulse low minus `strategy_break_buffer_atr * ATR`, and closes in the lower
  tail of its own range at or below `strategy_max_confirm_close_location`.
- Enter short at market on the next H4 bar.
- Reject if this magic already has a position, the broker week already
  accepted an entry, spread exceeds `strategy_max_spread_points`, or any data
  or parameter is invalid.

## 5. Exit Rules

- Stop: impulse high plus `strategy_stop_buffer_atr * ATR`.
- Profit target: `strategy_rr_target`, default 1.75R, times actual
  entry-to-stop distance.
- Close after `strategy_max_hold_hours=48` calendar hours.
- Framework Friday close remains enabled at broker hour 21.
- No long signal, reversal exit, trailing stop, break-even move, partial
  close, or same-week re-entry.

## 6. Filters (No-Trade Module)

- Exact symbol/timeframe guard: `XTIUSD.DWX`, H4.
- Magic slot must be 0; one position per magic/symbol.
- Parameter-domain, next-session, H4/D1 history, pre-impulse ATR, impulse,
  range, close-location, confirmation, spread, open-position, and weekly gates
  fail closed.
- Standard V5 kill switch, news compliance, Friday close, and connection
  protections remain authoritative.

## 7. Trade Management Rules

- Short-only after negative D1 impulse plus separate downside confirmation.
- Fixed structural SL and fixed-R TP are placed at entry.
- Only time, broker SL/TP, and framework Friday exits apply.
- No pyramiding, grid, martingale, partial close, trailing, or live adaptation.

## Parameters To Test

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_impulse_atr
  default: 0.60
  sweep_range: [0.50, 0.60, 0.75]
- name: strategy_min_impulse_range_atr
  default: 0.75
  sweep_range: [0.60, 0.75, 1.00]
- name: strategy_max_impulse_range_atr
  default: 2.75
  sweep_range: [2.25, 2.75, 3.25]
- name: strategy_max_impulse_close_location
  default: 0.35
  sweep_range: [0.25, 0.35, 0.40]
- name: strategy_break_buffer_atr
  default: 0.00
  sweep_range: [0.00, 0.05, 0.10]
- name: strategy_max_confirm_close_location
  default: 0.35
  sweep_range: [0.25, 0.35, 0.40]
- name: strategy_stop_buffer_atr
  default: 0.10
  sweep_range: [0.05, 0.10, 0.20]
- name: strategy_rr_target
  default: 1.75
  sweep_range: [1.50, 1.75, 2.00]
- name: strategy_max_hold_hours
  default: 48
  sweep_range: [24, 48, 72]
- name: strategy_max_spread_points
  default: 1200
  sweep_range: [800, 1200, 1800]

The negative-only D1 regime, first-next-session confirmation, short-only side,
one accepted entry per broker week, and absence of calendar, mean-reversion,
compression, and slow-trend filters are locked. No post-hoc direction or
calendar sweep is authorized.

## Author Claims

"We find the standard leverage effect for both crude oils." (Kristoufek 2014,
Conclusion, p. 7.)

The source establishes a return/volatility relationship, not short breakout
profitability or next-session continuation. No performance claim is imported.

## Initial Risk Profile

- `expected_pf: 1.05` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 22.0` is a risk-budget prior, not a forecast.
- Risk class is high because crude-oil downside breaks can gap or reverse.
- Source silent on V5 sizing; backtests use `RISK_FIXED=1000`.

## Strategy Allowability Check

- [x] Mechanical native-price volatility regime and downside continuation.
- [x] Peer-reviewed primary citation, DOI, full paper, and exact locations.
- [x] Mixed prior WTI evidence and lack of long-range dependence are recorded.
- [x] No DCCA/DMCA/GARCH/Hurst runtime, ML, banned indicator, external feed,
  grid, martingale, pyramiding, or adaptive fitting.
- [x] Expected frequency exceeds the Q02 five-trades/year floor.
- [x] Friday close remains enabled.
- [x] Non-duplicate boundaries are explicit and dedup check is clean.

## Framework Alignment

- no_trade: symbol/timeframe, slot, parameter, next-session, history, ATR,
  impulse-range, close-location, spread, open-position, and weekly guards;
  framework protections remain active.
- trade_entry: negative completed D1 impulse plus a later completed H4 close
  below its low; short entry with structural stop and 1.75R target.
- trade_management: 48-hour close only.
- trade_close: broker structural SL/TP, time exit, and framework Friday
  flatten.

## Risk

Q02 falsifies the card if realized density is below five completed trades/year,
economics/drawdown gates fail, or the report is missing/invalid. The
front-futures daily result to continuous-CFD D1/H4 translation is an explicit
basis risk. Correlation is not inferred; Q09 alone may measure orthogonality
after survival.

This build must not touch `T_Live`, AutoTrading, a deploy manifest, a live
setfile, the portfolio gate, portfolio admission, or portfolio KPI code.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial WTI leverage-effect downside build | Q02 | PENDING BUILD |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by mission directive | this card |

