---
ea_id: QM5_13109
slug: xng-febjun-long
type: strategy
strategy_id: EWALD-XNG-TRDTIME-2022_S02
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
    location: "Full paper; especially Sections 3-5.1 and Table 3; DOI https://doi.org/10.1016/j.eneco.2022.106324; open version https://eprints.gla.ac.uk/281581/1/281581.pdf"
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
strategy_type_flags: [calendar-seasonality, energy-risk-premium, long-only, weekly-entry, atr-hard-stop, time-stop, friday-close-flatten, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_13109_XNG_FEBJUN_LONG_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "First tradable D1 bar of each broker week from February through May; estimate 16-18 completed long trades/year before Q02 validation."
expected_trades_per_year_per_symbol: 17
expected_pf: 1.05
expected_dd_pct: 22.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Source-defined XNG trading-month risk premium, distinct from the book's RSI pullback and existing summer/dual-peak calendar maps; correlation is measured only after survival."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine, cfd_futures_basis]
g0_approval_reasoning: "Mission-directed G0 approval on 2026-07-10: peer-reviewed primary source; fixed calendar rule; registered XNGUSD.DWX data; deterministic native OHLC/ATR implementation without ML or banned logic."
---

# Natural-Gas February-to-June Trading-Time Seasonal Long

## Hypothesis

Ewald et al. identify a trading-time seasonal pattern in fixed-maturity
natural-gas futures: prices are lowest when contracts are traded in February
and highest when traded in June. They distinguish this effect from ordinary
spot-price or maturity-month seasonality and test a buy-February, sell-June
strategy. The proposed driver is a seasonal energy risk premium potentially
related to preferences, hedging pressure, sentiment, and natural factors, not
a chart oscillator.

`XNGUSD.DWX` cannot reproduce a panel of matched-maturity futures. This card
tests only the directional carrier of the published effect. It divides the
February-to-June long exposure into non-overlapping weekly D1 tranches: enter
on the first tradable D1 bar of each week from February through May and let the
framework flatten on Friday. This preserves the source-defined direction and
window while clearing the five-trades/year economic floor.

## Source Citation

The primary source is the peer-reviewed 2022 *Energy Economics* paper, article
106324, DOI `10.1016/j.eneco.2022.106324`. Section 5.1 states: "For natural gas
groups 1 and 2, we buy in February and then sell in June." The paper uses daily
futures observations, monthly aggregation, two natural-gas samples,
nonparametric seasonality tests, and CAPM regressions.

The source reports positive natural-gas alpha in its broad sample, but the
effect weakens in the later sample and 2008 contributes unusually large gains.
Those results are not imported into QM. Weekly CFD tranches have different
execution, roll, basis, and weekend properties; Q02+ is the only evidence.

## Concept

Only `XNGUSD.DWX` closed D1 bars, broker calendar, ATR, spread, and framework
position state are used. There is no futures curve, fixed-maturity contract
matrix, inventory, EIA data, weather, options, volume, open interest, external
feed, API, CSV, ML model, adaptive fitting, grid, martingale, pyramiding, or
discretionary switch.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI or short-horizon pullback signal.
- `QM5_12704_xngusd-summer-power-long`: February-May weekly tranches rather
  than a June-August monthly summer-demand window with SMA confirmation.
- `QM5_12706_xngusd-seasonal-dual-peak`: one source-defined spring window and
  no SMA, rather than dual November-March/June-August monthly regimes.
- `QM5_12575_eia-xng-season`: long-only and no monthly direction map or SMA.
- XNG breakout, trend, event, inventory, weather, storage, roll, spread, and
  RSI systems: no price-direction confirmation or external catalyst is used.

## Target Symbols And Period

- Symbol: `XNGUSD.DWX`, magic slot 0.
- Period: D1.
- Expected frequency: 16-18 trades/year; Q02 enforces the binding minimum of
  five completed trades/year/symbol.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## 4. Entry Rules

- Evaluate only on a new `XNGUSD.DWX` D1 bar.
- The current bar must be the first tradable D1 bar of a new broker-calendar
  week. A Monday holiday moves the attempt to Tuesday.
- The current broker month must be February, March, April, or May
  (`strategy_start_month=2`, `strategy_end_month=5`).
- Enter one long `XNGUSD.DWX` position at market.
- Reject the entry if a position for this magic is open, the current week was
  already entered, spread exceeds `strategy_max_spread_points`, ATR is
  invalid, or parameters are invalid.

## 5. Exit Rules

- Initial broker-side hard stop: ATR(`strategy_atr_period`) times
  `strategy_atr_sl_mult` below entry.
- Framework Friday close is enabled at broker hour 21 and is the ordinary
  tranche exit.
- Close a stale position after `strategy_max_hold_days=7` calendar days.
- Close immediately on the first D1 management pass outside February-May or
  if an unexpected short position exists for the magic.
- No profit target, trailing stop, break-even move, partial close, reversal,
  grid, martingale, pyramiding, or same-week re-entry.

## 6. Filters (No-Trade Module)

- Exact symbol/timeframe guard: `XNGUSD.DWX`, D1.
- Magic slot must be 0; one open position per magic/symbol.
- The month endpoints are code-locked to 2 and 5.
- Parameter-domain, ATR, and spread guards fail closed.
- Standard V5 kill switch, news compliance, connection protections, and
  Friday close remain authoritative.

## 7. Trade Management Rules

- On each new D1 bar, close a position that is outside February-May, older
  than seven calendar days, or unexpectedly short.
- The framework Friday-close handler remains the normal weekly exit and runs
  before the strategy entry gate.
- The broker-side ATR stop remains live between D1 management passes.

## Parameters To Test

- name: strategy_start_month
  default: 2
  sweep_range: [2]
- name: strategy_end_month
  default: 5
  sweep_range: [5]
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
  default: 2500
  sweep_range: [1500, 2500, 3500]

The February-May window, weekly tranche construction, long-only direction,
and Friday flatten are locked. Later phases may only use the documented ATR,
hold, and spread-cap axes; no post-hoc month or direction sweep is authorized.

## Author Claims

The source finds statistically significant trading-time seasonality in both
natural-gas samples. Its reported natural-gas strategy evidence is fragile in
the later sample and does not validate `XNGUSD.DWX`, weekly tranches, Darwinex
spreads, or the V5 risk model. No numerical source result is used as a gate or
forecast.

## Initial Risk Profile

- `expected_pf: 1.05` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 22.0` is a risk-budget prior, not a forecast.
- Risk class is high because this is unhedged directional natural-gas exposure
  and the source effect weakens in the more mature sample.
- Source is silent on V5 sizing; use `RISK_FIXED=1000` for backtests.

## Strategy Allowability Check

- [x] Mechanical calendar-only structural energy rule.
- [x] Peer-reviewed primary source with exact DOI and full-paper location.
- [x] No ML, banned indicator, external runtime feed, grid, martingale,
  pyramiding, or discretionary input.
- [x] Expected frequency is above the Q02 five-trades/year floor.
- [x] Friday close remains enabled.
- [x] Non-duplicate against XNG RSI, summer-power, dual-peak, long/short month
  maps, trend, breakout, event, weather, storage, roll, and spread logic.

## Framework Alignment

- no_trade: symbol/timeframe, magic-slot, parameter, open-position, calendar,
  ATR, and spread guards; framework kill/news/Friday protections remain active.
- trade_entry: first tradable D1 bar of each February-May broker week; one long
  natural-gas tranche with an ATR hard stop.
- trade_management: outside-window, wrong-side, and seven-day stale closes.
- trade_close: broker-side ATR stop, management exits, and framework Friday
  flatten.

## Risk

Q02 falsifies the card if realized density is below five completed trades/year,
the strategy fails economics/drawdown criteria, or the report is missing or
invalid. The futures-to-CFD basis translation is an explicit risk. Portfolio
correlation is not inferred here and may only be measured at Q09 from a
surviving return stream.

This build must not touch `T_Live`, AutoTrading, a deploy manifest, a live
setfile, the portfolio gate, portfolio admission, or portfolio KPI code.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial XNG trading-time seasonal build | Q02 | ENQUEUE PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by mission directive | this card |
| Q01 Build Validation | 2026-07-10 | PENDING | `artifacts/qm5_13109_build_result.json` |
| Q02 Baseline Screening | 2026-07-10 | PENDING | enqueue evidence pending |
