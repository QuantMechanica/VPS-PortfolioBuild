---
ea_id: QM5_13107
slug: wti-juldec-short
type: strategy
strategy_id: EWALD-WTI-TRDTIME-2022_S01
source_id: EWALD-WTI-TRDTIME-2022
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Ewald, C.-O., Haugom, E., Lien, G., Stordal, S., and Wu, Y. Trading time seasonality in commodity futures. Energy Economics 115 (2022), 106324."
source_citations:
  - type: paper
    citation: "Ewald, Christian-Oliver; Haugom, Erik; Lien, Gudbrand; Stordal, Stale; and Wu, Yuexiang (2022). Trading time seasonality in commodity futures: An opportunity for arbitrage in the natural gas and crude oil markets? Energy Economics 115, 106324."
    location: "Full paper; especially Sections 3-5.2, pp. 2-13; DOI https://doi.org/10.1016/j.eneco.2022.106324; open version https://eprints.gla.ac.uk/281581/1/281581.pdf"
    quality_tier: A
    role: primary
source_links:
  - "https://doi.org/10.1016/j.eneco.2022.106324"
  - "https://eprints.gla.ac.uk/281581/1/281581.pdf"
sources:
  - "[[sources/EWALD-WTI-TRDTIME-2022]]"
concepts:
  - "[[concepts/trading-time-seasonality]]"
  - "[[concepts/energy-risk-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, energy-risk-premium, short-only, weekly-entry, atr-hard-stop, time-stop, friday-close-flatten, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13107_XTI_JULDEC_SHORT_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "First tradable D1 bar of each broker week from July through November; estimate 20-23 completed short trades/year before Q02 validation."
expected_trades_per_year_per_symbol: 21
expected_pf: 1.05
expected_dd_pct: 20.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Adds calendar-defined WTI risk-premium exposure to the XAU/SP500/NDX/XNG book; Q09 alone may determine realized return-stream correlation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine, cfd_futures_basis]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-10: R1 PASS peer-reviewed Energy Economics paper with DOI and full open text; R2 PASS fixed weekly July-November WTI short tranches, ATR stop, Friday flatten, and stale exit; R3 PASS XTIUSD.DWX registered; R4 PASS native calendar/OHLC only, no ML, banned indicato"
---

# WTI July-to-December Trading-Time Seasonal Short

## Hypothesis

Ewald et al. identify a trading-time seasonal pattern in fixed-maturity WTI
futures: prices are highest when contracts are traded in July and lowest when
traded in December. They distinguish this backward-curve effect from ordinary
spot-price or maturity-month seasonality and test a short-July, cover-December
strategy. The proposed driver is a seasonal energy risk premium potentially
related to preferences, hedging pressure, and sentiment, not a chart oscillator.

`XTIUSD.DWX` cannot reproduce a panel of matched-maturity futures. This card
tests only the directional carrier of the published effect. It divides the
July-to-December short exposure into non-overlapping weekly D1 tranches: enter
on the first tradable D1 bar of each week from July through November and let
the framework flatten on Friday. That makes the CFD translation testable,
retains the source-defined direction and window, and clears the five-trades/year
economic floor without overlapping positions.

## Source Citation

The primary source is the peer-reviewed 2022 *Energy Economics* paper, article
106324, DOI `10.1016/j.eneco.2022.106324`. Section 5.1 states that for WTI
"we short first in July" and take the offsetting position in December. The
paper uses daily futures observations, monthly aggregation, two WTI samples,
nonparametric seasonality tests, and CAPM regressions.

The source reports positive significant WTI alphas, but those results are not
imported into QM. The paper also records large annual variation, an unusually
profitable 2008, five months of unhedged directional exposure, and uncertainty
about the exact causal mechanism. The weekly CFD translation has different
execution, roll, basis, and weekend properties; Q02+ is the only evidence.

## Concept

Only `XTIUSD.DWX` closed D1 bars, broker calendar, ATR, spread, and framework
position state are used. There is no futures curve, fixed-maturity contract
matrix, inventory, WPSR, OPEC, COT, options, volume, open interest, external
feed, API, CSV, ML model, adaptive fitting, grid, martingale, pyramiding, or
discretionary switch.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI or short-horizon pullback signal.
- `QM5_12962_wti-jul-prem` and `QM5_12777_wti-dec-fade`: this is a continuous
  source-defined July-to-December short-risk window, not a one-month premium or
  fade trade.
- `QM5_12734_wti-febsep-prem`: this card is short July-November every week,
  rather than a first-day long trade in a broad February-September window.
- WTI trend, Donchian, NR7/IDNR4, event, inventory, OPEC, roll, expiry, carry,
  ratio, commodity-FX, and XTI/XNG systems: no price-direction confirmation,
  event feed, pair leg, or curve proxy is used.

## Target Symbols And Period

- Symbol: `XTIUSD.DWX`, magic slot 0.
- Period: D1.
- Expected frequency: 20-23 trades/year; Q02 enforces the binding minimum of
  five completed trades/year/symbol.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

### Entry

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- The current bar must be the first tradable D1 bar of a new broker-calendar
  week. A Monday holiday therefore moves the attempt to Tuesday rather than
  deleting the week.
- The current broker month must be July, August, September, October, or
  November (`strategy_start_month=7`, `strategy_end_month=11`).
- Enter one short `XTIUSD.DWX` position at market.
- Reject the entry if a position for this magic is open, the current week was
  already attempted successfully, spread exceeds
  `strategy_max_spread_points`, ATR is invalid, or parameters are invalid.

### Stop And Exit

- Initial broker-side hard stop: ATR(`strategy_atr_period`) times
  `strategy_atr_sl_mult` above entry.
- Framework Friday close is enabled at broker hour 21 and is the ordinary
  tranche exit.
- Close a stale position after `strategy_max_hold_days=7` calendar days.
- Close immediately on the first D1 management pass outside July-November or
  if an unexpected long position exists for the magic.
- No profit target, trailing stop, break-even move, partial close, reversal,
  grid, martingale, pyramiding, or same-week re-entry.

## Filters

- Exact symbol/timeframe guard: `XTIUSD.DWX`, D1.
- Magic slot must be 0; one open position per magic/symbol.
- Parameter-domain, ATR, and spread guards fail closed.
- Standard V5 kill switch, news compliance, connection protections, and
  Friday close remain authoritative.

## Parameters To Test

- name: strategy_start_month
  default: 7
  sweep_range: [7]
- name: strategy_end_month
  default: 11
  sweep_range: [11]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 7
  sweep_range: [5, 7]
- name: strategy_max_spread_points
  default: 1500
  sweep_range: [1000, 1500, 2000]

The July-November window, weekly tranche construction, short-only direction,
and Friday flatten are locked. Later phases may only use the documented ATR,
hold, and spread-cap axes; no post-hoc month or direction sweep is authorized.

## Author Claims

The source finds statistically significant trading-time seasonality in both
WTI samples and reports positive significant CAPM alphas for the WTI strategy.
It does not validate `XTIUSD.DWX`, weekly tranches, Darwinex spreads, or the V5
risk model. No numerical source result is used as a gate or forecast.

## Initial Risk Profile

- `expected_pf: 1.05` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 20.0` is a risk-budget prior, not a forecast.
- Risk class is high: the sleeve is seasonally short WTI, and the paper itself
  recognizes months of unhedged directional exposure.
- Source is silent on V5 sizing; use `RISK_FIXED=1000` for backtests.

## Strategy Allowability Check

- [x] Mechanical calendar-only structural energy rule.
- [x] Peer-reviewed primary source with exact DOI and full-paper location.
- [x] No ML, banned indicator, external runtime feed, grid, martingale,
  pyramiding, or discretionary input.
- [x] Expected frequency is above the Q02 five-trades/year floor.
- [x] Friday close remains enabled.
- [x] Non-duplicate against WTI month premiums/fades, broad season maps,
  trend/reversal, breakout, event, inventory, roll, ratio, carry, and RSI logic.

## Framework Alignment

- no_trade: symbol/timeframe, magic-slot, parameter, open-position, calendar,
  ATR, and spread guards; framework kill/news/Friday protections remain active.
- trade_entry: first tradable D1 bar of each July-November broker week; one
  short WTI tranche with an ATR hard stop.
- trade_management: outside-window, wrong-side, and seven-day stale closes.
- trade_close: broker-side ATR stop, management exits, and framework Friday
  flatten.

## Risk

Q02 falsifies the card if realized density is below five completed
trades/year, the strategy fails economics/drawdown criteria, or the report is
missing or invalid. The futures-to-CFD basis translation is an explicit risk,
not a hidden assumption. Portfolio correlation is not inferred here and may
only be measured at Q09 from a surviving return stream.

This build must not touch `T_Live`, AutoTrading, a deploy manifest, a live
setfile, the portfolio gate, portfolio admission, or portfolio KPI code.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial WTI trading-time seasonal build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by mission directive | this card |
| Q01 Build Validation | 2026-07-10 | PASS | `artifacts/qm5_13107_build_result.json` |
| Q02 Baseline Screening | 2026-07-10 | QUEUED | work item `0251f2ca-5a43-4ebf-9b25-f4f4ab910996` |
