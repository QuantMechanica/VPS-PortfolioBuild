---
card_schema_version: 2
ea_id: QM5_20162
slug: xng-winter-dualtrend
type: strategy
strategy_id: EIA-MOP-XNG-WINTER-DUALTREND-2026_S01
variant_id: EIA-MOP-XNG-WINTER-DUALTREND-2026_S01
source_id: EIA-MOP-XNG-WINTER-DUALTREND-2026
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20162_xng-winter-dualtrend_card.md
execution_contract_status: DRAFT
created: 2026-07-26
created_by: Research+Development
last_updated: 2026-08-03
source_citation: "U.S. EIA (2015), Natural gas use features two seasonal peaks per year; Moskowitz, Ooi and Pedersen (2012), Time Series Momentum, JFE 104(2)."
source_citations:
  - type: official_government_source
    citation: "U.S. Energy Information Administration (2015), Natural gas use features two seasonal peaks per year."
    location: "Complete governed extraction at strategy-seeds/sources/706222b7-2d60-5fdb-8dab-d722d3c96f92/source.md; https://www.eia.gov/todayinenergy/detail.php?id=22892"
    quality_tier: A
    role: winter_seasonal_state
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "Complete 23-page governed review at strategy-seeds/sources/MOP-TSMOM-2012/source.md; DOI 10.1016/j.jfineco.2011.11.003"
    quality_tier: A
    role: trend_state
sources:
  - "[[sources/EIA-MOP-XNG-WINTER-DUALTREND-2026]]"
strategy_mechanic: november-march-xng-long-only-rising-21-84-d1-sma-stack-with-positive-five-day-slopes
strategy_type_flags: [natural-gas, winter-seasonality, dual-trend, long-only, atr-hard-stop, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_20162_XNG_WINTER_DUALTREND_D1
symbol: XNGUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Friday-segmented November-March trend packages; approximately 8-18 completed trades/year when the dual-trend state is valid."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Adds winter heating-demand trend exposure distinct from the incumbent XNG RSI pullback. The Nov-Mar window plus rising 21/84-D1 trend stack are jointly load-bearing; Q09 alone may establish realized orthogonality."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, natural_gas_gaps, friday_close, magic_schema, risk_mode_dual, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER commodity/energy sleeve mission: R1 PASS official EIA seasonality plus peer-reviewed JFE trend lineage; R2 PASS fixed Nov-Mar window, rising 21/84-D1 trend stack, ATR stop and deterministic exits; R3 PASS registered XNGUSD.DWX D1 carrier; R4 PASS native MT5 data only with no ML, banned indicator, grid or martingale. Non-duplicate versus QM5_12567 RSI pullback, QM5_12702 monthly close/SMA winter allocation, and pure monthly return-sign TSMOM."
---

# QM5_20162 XNG Winter Dual-Trend

## Hypothesis

Winter heating demand creates a recurring natural-gas regime, but calendar
exposure alone is too blunt. This card enters long only when the November-March
window overlaps a positive and accelerating completed-bar price trend.

## Source and evidence boundary

The governed packet at
`strategy-seeds/sources/EIA-MOP-XNG-WINTER-DUALTREND-2026/source.md` records the
official EIA seasonality lineage and peer-reviewed time-series-momentum lineage.
The exact moving-average and risk parameters are QM hypotheses, not source
claims. No return, correlation, or profitability claim is imported.

## Rules

The entry, exit, filter, sizing, and lifecycle rules below are the complete
frozen Q02 baseline. The EA uses completed D1 prices only. It does not use an
oscillator, external calendar, inventory series, weather feed, trained model,
grid, martingale, scale-in, or parameter sweep.

## 4. Entry Rules

- Exact carrier `XNGUSD.DWX`, D1, EA ID `20162`, magic slot 0.
- Evaluate once per genuine new D1 bar. Persist the current D1 bar timestamp
  before position, season, history, signal, spread, quote, stop, news, or order
  checks; a blocked, rejected, stopped, or restarted bar cannot retry.
- Require November through March broker-calendar months.
- Require completed close above SMA(21), SMA(21) above SMA(84), SMA(21) above
  its value five completed bars earlier, and SMA(84) above its value five
  completed bars earlier.
- Require a non-negative spread no greater than 1000 points, valid executable
  quote, completed ATR(20), normalized stop, and registered magic.
- BUY with a frozen `3.5 * ATR(20)` hard stop and no take profit.
- One position per magic. Friday close remains enabled at 21:00 broker time,
  so a still-valid trend may form a new package on a later D1 bar.

## 5. Exit Rules

- Close outside November-March.
- Close if completed close is at or below SMA(21), SMA(21) is at or below
  SMA(84), or either five-day SMA slope is non-positive.
- Close after 35 calendar days as a stale safety override.
- Close an owned wrong-side position or any position whose completed trend
  state cannot be validated; lifecycle exits remain retryable on later ticks.
- Framework Friday close and kill switch remain authoritative.

## 6. Filters (No-Trade Module)

- Fail closed outside exact `XNGUSD.DWX` D1, EA ID `20162`, slot 0, and the
  locked baseline inputs.
- Both news axes and the legacy news mode are OFF for Q02. The signal has no
  external-calendar dependency.
- Reject non-winter entries, missing completed history, invalid SMA/ATR/quote
  values, negative or excessive spread, a consumed D1 attempt, a same-bar
  entry deal, or an owned position.
- No EIA release, storage, volume, open-interest, weather, CSV, API, or other
  external runtime input is permitted.

## 7. Trade Management Rules

- Maintain at most one long `XNGUSD.DWX` position under magic `201620000`.
- Re-evaluate season, completed 21/84-D1 trend state, and the 35-day stale
  guard every tick; close through the framework when any state is invalid.
- Preserve the server-side hard stop. Do not trail, move to break-even,
  partially close, average, hedge, pyramid, scale in, grid, or martingale.
- The terminal-persistent D1 attempt marker plus owned deal history prevents
  restart-driven same-bar re-entry.

## Parameters to test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_fast_period` | 21 | [21] |
| `strategy_slow_period` | 84 | [84] |
| `strategy_slope_bars` | 5 | [5] |
| `strategy_atr_period` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.5 | [3.5] |
| `strategy_max_hold_days` | 35 | [35] |
| `strategy_max_spread_points` | 1000 | [1000] |

All baseline parameters are locked. Changing the season, trend stack, direction,
or exit logic is a new card, not a rescue sweep.

## Non-duplicate decision

- `QM5_12567` buys short-horizon cumulative-RSI pullbacks; this uses no
  oscillator or oversold condition.
- `QM5_12702` checks only a monthly winter close above one SMA; this requires
  a daily positive 21/84 stack with both five-day slopes rising.
- `QM5_20063` uses a monthly 63-D1 return sign in either direction and no
  seasonal window; this is long-only and winter-gated.
- Existing XNG freeze, storage, expiry, LNG, weekday and breakout cards use
  different event clocks or triggers.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Retire below five completed trades/year at Q02. Fail on
wrong-season entry, invalid trend-state entry, repeated same-bar entry,
nondeterminism, risk mismatch, or governed PF/DD failure. Q09 correlation is
authoritative; structural difference does not guarantee decorrelation.

## Framework alignment

- no_trade: exact carrier, timeframe, slot and locked-input validation.
- trade_entry: winter-only rising dual-SMA long entry with spread/ATR guards.
- trade_management: season, trend-state and max-hold exits.
- trade_close: framework strategy close or broker ATR stop.

## Safety boundary

This authorizes card, build, strict compile, one RISK_FIXED setfile and Q02
enqueue only. It does not authorize a live setfile, T_Live access,
AutoTrading, deploy manifest, portfolio gate or portfolio manifest change.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-03 | finish the committed but unbuilt winter dual-trend scaffold under the renewed OWNER commodity/energy mission | Q01 | PASS |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-07-26 / reaffirmed 2026-08-03 | APPROVED; R1-R4 PASS | this card, governed source packet, and `decisions/2026-08-03_qm5_20162_xng_winter_dualtrend_build_resume.md` |
| Q01 Build Validation | 2026-08-03 | PASS; strict compile and build check, 0 errors, 0 warnings, 0 failures | `D:/QM/reports/framework/21/build_check_20260803_102721.json` |
| Q02 Baseline Screening | — | NOT_ENQUEUED | paced enqueue pending |
