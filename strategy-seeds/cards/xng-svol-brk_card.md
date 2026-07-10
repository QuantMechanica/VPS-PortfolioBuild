---
ea_id: QM5_13110
slug: xng-svol-brk
type: strategy
strategy_id: SUENAGA-XNG-SEASVOL-2008_S01
source_id: SUENAGA-XNG-SEASVOL-2008
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Suenaga, H., Smith, A., and Williams, J. C. Volatility Dynamics of NYMEX Natural Gas Futures Prices. Journal of Futures Markets 28(5), 2008, 438-463. DOI 10.1002/fut.20317."
source_citations:
  - type: paper
    citation: "Suenaga, Hiroaki; Smith, Aaron; and Williams, Jeffrey C. (2008). Volatility Dynamics of NYMEX Natural Gas Futures Prices. Journal of Futures Markets 28(5), 438-463."
    location: "Full paper; especially pp. 438-442, 447-452, and 461-462; DOI https://doi.org/10.1002/fut.20317; author PDF https://files.asmith.ucdavis.edu/2008_JFutMkt_SSW_NGfutures.pdf"
    quality_tier: A
    role: primary
source_links:
  - "https://doi.org/10.1002/fut.20317"
  - "https://files.asmith.ucdavis.edu/2008_JFutMkt_SSW_NGfutures.pdf"
sources:
  - "[[sources/SUENAGA-XNG-SEASVOL-2008]]"
concepts:
  - "[[concepts/natural-gas-seasonal-volatility]]"
  - "[[concepts/storage-buffering-capacity]]"
  - "[[concepts/close-confirmed-range-expansion]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [n-period-max-continuation, vol-regime-gate, atr-hard-stop, time-stop, symmetric-long-short, friday-close-flatten]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_13110_XNG_SVOL_BRK_H4
period: H4
timeframes: [H4, D1]
expected_trade_frequency: "Once-weekly eligible H4 natural-gas range expansion during the source volatility windows; estimate 10-24 completed trades/year before Q02 validation."
expected_trades_per_year_per_symbol: 16
expected_pf: 1.05
expected_dd_pct: 24.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Adds source-seasonal, symmetric natural-gas volatility expansion to the XAU/SP500/NDX/XNG book. It is neither the incumbent RSI pullback nor a fixed directional month bet; only Q09 return evidence may establish orthogonality."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine, cfd_futures_basis]
g0_approval_reasoning: "Mission-directed G0 approval on 2026-07-10: R1 PASS peer-reviewed Journal of Futures Markets paper reviewed end-to-end; R2 PASS fixed source-month volatility gate plus once-weekly H4 close-confirmed prior-D1 range expansion, structural SL, fixed-R target, and time exit; R3 PASS registered XNGUSD.DWX H4/D1 data; R4 PASS native OHLC/ATR only with no POTS/GARCH/Kalman runtime, ML, grid, martingale, or external feed."
---

# XNG Source-Seasonal Volatility Breakout

## Hypothesis

Suenaga, Smith, and Williams find strong seasonal variation in NYMEX natural-
gas futures volatility and relate it to winter demand, storage capacity, and
the changing ability of inventory to buffer shocks. The paper identifies broad
volatility increases from early May through late September and from early
November through mid-January.

The paper does not supply a directional alpha rule. This card therefore does
not predict long or short from the calendar. It trades only after a completed
`XNGUSD.DWX` H4 bar closes beyond the previous completed D1 range during the
source windows, takes the break direction, and permits at most one accepted
entry per broker week. The range close is the direction discovery; the source
calendar is only the structural volatility regime.

## Source Citation

The primary source is the peer-reviewed *Journal of Futures Markets* paper,
DOI `10.1002/fut.20317`. The complete 26-page paper was reviewed, including
model, data, estimates, hedging application, conclusion, and bibliography. It
uses 40,618 daily settlement prices across 175 NYMEX contracts from 1991-2003
and explicitly models season and time-to-maturity effects.

The source states that "volatility rises for all 12 contracts" in early winter
(p. 447). It also documents the May-September increase. It assumes martingale
daily price changes for the hedge derivation, so no directional or performance
claim is imported into this card.

## Concept

Only `XNGUSD.DWX` H4/D1 OHLC, D1 ATR, spread, broker calendar, and V5 framework
state are read. There is no futures maturity panel, curve, storage series,
weather input, EIA feed, POTS/GARCH/Kalman calculation, volume, open interest,
API, CSV, ML model, adaptive fitting, grid, martingale, pyramiding, or
discretionary switch.

## Non-Duplicate Boundary

- `QM5_12567_cum-rsi2-commodity`: two-day cumulative-RSI pullback; this card
  uses no oscillator and follows a close-confirmed range expansion.
- `QM5_12586_eia-xng-winter-brk`: November-March D1 30-bar Donchian plus SMA;
  this card uses a one-day reference range, H4 confirmation, no trend filter,
  and both source volatility windows.
- `QM5_12588_eia-xng-sum-sqz`: June-August long-only D1 squeeze/20-bar channel;
  this card is symmetric, has no compression or SMA gate, and includes the
  paper's May-September and November-January windows.
- `QM5_12817_xng-volshock-fade`: fades multi-day shocks; this card follows a
  completed range break and never enters opposite it.
- `QM5_13101_xng-1w-mom-vol`: five-D1 continuation only in low volatility;
  this card uses source high-volatility months and prior-day range expansion.
- `QM5_13104_xng-mon-range`: compressed-Friday/Monday-only non-gap setup; this
  card can trigger on any eligible weekday, has no Friday compression gate,
  and uses the immediately prior completed D1 range.
- `QM5_13105_xng-idnr4-brk`: requires an inside/narrow-range pattern; this card
  has no inside-bar or NR4 precondition and is calendar-regime gated.

Repository dedup was clean before EA-ID allocation for slug `xng-svol-brk`,
strategy ID `SUENAGA-XNG-SEASVOL-2008_S01`, and the full mechanic description.

## Target Symbols And Period

- Symbol: `XNGUSD.DWX`, magic slot 0.
- Host period: H4; D1 supplies the prior completed range and ATR scale.
- Eligible months: May-September and November-January.
- Expected frequency: 10-24 trades/year; Q02 enforces at least five completed
  trades/year/symbol.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The source calendar forecasts a volatility regime only. The completed H4 range
break discovers direction; the prior D1 range fixes the structural risk unit.

## 4. Entry Rules

- Evaluate only on a new `XNGUSD.DWX` H4 bar.
- The prior completed H4 signal bar and current H4 entry bar must be within an
  eligible source month: May-September or November-January.
- Load the immediately prior completed D1 bar and D1 ATR(20).
- The prior D1 range must be between
  `strategy_min_reference_range_atr * ATR` and
  `strategy_max_reference_range_atr * ATR`; this is data-quality/risk control,
  not a compression signal.
- The completed H4 signal range must be at least
  `strategy_min_signal_range_atr * ATR(D1)`.
- Long: completed H4 close is above prior D1 high plus
  `strategy_break_buffer_atr * ATR`, signal bar is bullish, and close location
  is at least `strategy_min_close_location`.
- Short: completed H4 close is below prior D1 low minus the same buffer, signal
  bar is bearish, and close location is at most the complementary threshold.
- Enter at market on the next H4 bar in the break direction.
- Reject if a position for this magic is open, the week already accepted an
  entry, spread exceeds `strategy_max_spread_points`, or data are invalid.

## 5. Exit Rules

- Long stop: prior D1 low minus `strategy_stop_buffer_atr * ATR(D1)`.
- Short stop: prior D1 high plus the same ATR buffer.
- Profit target: `strategy_rr_target`, default 1.75R, times actual entry-to-stop
  distance.
- Close after `strategy_max_hold_hours=36` calendar hours.
- Close on the first management pass outside the eligible source months.
- Framework Friday close stays enabled at broker hour 21.
- No signal reversal, trailing stop, break-even move, partial close, or re-entry
  during the same accepted broker week.

## 6. Filters (No-Trade Module)

- Exact symbol/timeframe guard: `XNGUSD.DWX`, H4.
- Magic slot must be 0; one position per magic/symbol.
- Parameter-domain, calendar, D1/H4 history, ATR, reference-range, signal-range,
  close-location, spread, and weekly gates fail closed.
- Standard V5 kill switch, news compliance, Friday close, and connection
  protections remain authoritative.

## 7. Trade Management Rules

- Symmetric long/short; the completed breakout bar determines direction.
- Fixed structural SL and fixed-R TP are placed at entry.
- Only time, calendar-window, broker SL/TP, and framework Friday exits apply.
- No pyramiding, grid, martingale, partial close, trailing, or live adaptation.

## Parameters To Test

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_reference_range_atr
  default: 0.20
  sweep_range: [0.15, 0.20, 0.30]
- name: strategy_max_reference_range_atr
  default: 2.50
  sweep_range: [2.00, 2.50, 3.00]
- name: strategy_min_signal_range_atr
  default: 0.30
  sweep_range: [0.20, 0.30, 0.45]
- name: strategy_break_buffer_atr
  default: 0.05
  sweep_range: [0.00, 0.05, 0.10]
- name: strategy_min_close_location
  default: 0.65
  sweep_range: [0.60, 0.65, 0.75]
- name: strategy_stop_buffer_atr
  default: 0.10
  sweep_range: [0.05, 0.10, 0.20]
- name: strategy_rr_target
  default: 1.75
  sweep_range: [1.50, 1.75, 2.00]
- name: strategy_max_hold_hours
  default: 36
  sweep_range: [24, 36, 48]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

The two source windows, symmetric breakout direction, one accepted entry per
week, and absence of trend/compression/inside-bar filters are locked. No
post-hoc month or direction sweep is authorized.

## Author Claims

The source establishes seasonal volatility and hedging implications, not
breakout profitability. No source return, Sharpe, win rate, or directional
claim is imported. The continuous CFD also cannot reproduce contract-specific
maturity effects; Q02+ is the only strategy evidence.

## Initial Risk Profile

- `expected_pf: 1.05` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 24.0` is a risk-budget prior, not a forecast.
- Risk class is high because natural-gas range breaks can gap and reverse.
- Source silent on V5 sizing; backtests use `RISK_FIXED=1000`.

## Strategy Allowability Check

- [x] Mechanical native-price volatility expansion with fixed source calendar.
- [x] Peer-reviewed primary citation, DOI, full PDF, and exact page locations.
- [x] No POTS/GARCH/Kalman runtime, ML, banned indicator, external feed, grid,
  martingale, pyramiding, or adaptive fitting.
- [x] Expected frequency exceeds the Q02 five-trades/year floor.
- [x] Friday close remains enabled.
- [x] Non-duplicate boundaries are explicit and dedup check is clean.

## Framework Alignment

- no_trade: symbol/timeframe, slot, parameter, calendar, history, ATR,
  reference/signal range, close-location, spread, open-position, and weekly
  guards; framework protections remain active.
- trade_entry: completed H4 close beyond the previous D1 range in a source
  volatility window; structural stop and 1.75R target.
- trade_management: 36-hour and outside-window closes only.
- trade_close: broker structural SL/TP, management exits, and framework Friday
  flatten.

## Risk

Q02 falsifies the card if realized density is below five completed trades/year,
economics/drawdown gates fail, or the report is missing/invalid. The futures-
contract-panel to continuous-CFD basis translation is explicit. Correlation is
not inferred; Q09 alone may measure orthogonality after survival.

This build must not touch `T_Live`, AutoTrading, a deploy manifest, a live
setfile, the portfolio gate, portfolio admission, or portfolio KPI code.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial XNG source-seasonal volatility build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by mission directive | this card |
| Q01 Build Validation | 2026-07-10 | PASS | `artifacts/qm5_13110_build_result.json` |
| Q02 Baseline Screening | 2026-07-10 | QUEUED | work item `a4e141ed-3058-4964-944e-1c0520b527e2` |
