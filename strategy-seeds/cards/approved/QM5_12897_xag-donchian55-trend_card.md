---
ea_id: QM5_12897
slug: xag-donchian55-trend
type: strategy
source_id: SZAKMARY-COMM-TREND-2010
source_citation: "Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010). Trend-following trading strategies in commodity futures: A re-examination. Journal of Banking and Finance, 34(2), 409-426. DOI https://doi.org/10.1016/j.jbankfin.2009.10.012"
source_citations:
  - type: academic_paper
    citation: "Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010). Trend-following trading strategies in commodity futures: A re-examination."
    location: "https://doi.org/10.1016/j.jbankfin.2009.10.012"
    quality_tier: A
    role: primary
sources:
  - "[[sources/SZAKMARY-COMM-TREND-2010]]"
concepts:
  - "[[concepts/donchian-channel]]"
  - "[[concepts/channel-breakout]]"
  - "[[concepts/trend-following-commodity]]"
  - "[[concepts/adx-regime-filter]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/adx]]"
  - "[[indicators/atr]]"
strategy_type_flags: [channel-breakout, trend-following, adx-regime-filter, atr-hard-stop, channel-contra-exit, symmetric-long-short, low-frequency]
target_symbols: [XAGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "D1 XAGUSD 55-period Donchian channel breakout with ADX regime filter; estimate 15-25 entries/year after filter."
expected_trades_per_year_per_symbol: 18
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-02
expected_pf: 1.15
expected_dd_pct: 20.0
g0_approval_reasoning: "R1 PASS academic commodity trend-following source; R2 PASS deterministic D1 Donchian55/ADX/ATR rules; R3 PASS XAGUSD.DWX present; R4 PASS no ML/grid/martingale."
---

# XAGUSD Donchian-55 Trend

## Source

- Source: [[sources/SZAKMARY-COMM-TREND-2010]]
- Primary citation: Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010).
  "Trend-following trading strategies in commodity futures: A re-examination."
  Journal of Banking and Finance, 34(2), 409-426. DOI
  https://doi.org/10.1016/j.jbankfin.2009.10.012.

## Concept

This card converts the commodity trend-following evidence in Szakmary, Shen and
Sharma into a single-symbol silver sleeve. The rule is intentionally simple:
trade `XAGUSD.DWX` D1 channel breakouts only when ADX confirms a trend regime,
then exit on the shorter contra-channel or the ATR hard stop.

The sleeve is deliberately different from the current live concentration in
XAU, SP500, NDX, and XNG. It is solo silver, directional trend following, and
does not use the `QM5_12567` cumulative-RSI commodity pullback logic or any
XAU/XAG, oil/silver, gas/silver, or other ratio-spread package.

## Markets And Timeframe

- Symbol: `XAGUSD.DWX`.
- Period: D1.
- Expected frequency: 15-25 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, ADX, ATR, broker calendar, and V5
  framework state only. No external runtime data, CSV, API, futures curve, or
  model is required.

## Entry Rules

- Evaluate only on a new D1 bar.
- Host chart must be `XAGUSD.DWX` on D1 with magic slot 0.
- No entry if an open `XAGUSD.DWX` position already exists for this EA magic.
- No entry if current spread is wider than `strategy_max_spread_points`.
- Compute the highest and lowest D1 close over
  `strategy_donchian_entry_period` completed bars excluding the signal bar.
- Compute ADX(`strategy_adx_period`) on the signal bar.
- Long entry: signal close is above the prior Donchian close-channel high and
  ADX is at least `strategy_adx_threshold`.
- Short entry: signal close is below the prior Donchian close-channel low and
  ADX is at least `strategy_adx_threshold`.
- Place a hard stop at ATR(`strategy_atr_period`) *
  `strategy_atr_stop_mult` from market entry.

## Exit Rules

- Close a long when the signal close falls below the prior
  `strategy_donchian_exit_period` close-channel low.
- Close a short when the signal close rises above the prior
  `strategy_donchian_exit_period` close-channel high.
- Close after `strategy_max_hold_bars` D1 bars as a stale-position guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XAGUSD.DWX` on D1.
- Magic slot offset must be 0.
- ADX regime filter blocks low-trend entries.
- Spread filter blocks only genuinely wide spreads; zero modeled spread in
  `.DWX` backtests is allowed.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding, gridding, martingale, partial close, or trailing stop.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_donchian_entry_period
  default: 55
  sweep_range: [40, 55, 65]
- name: strategy_donchian_exit_period
  default: 20
  sweep_range: [10, 20]
- name: strategy_adx_period
  default: 14
  sweep_range: [14]
- name: strategy_adx_threshold
  default: 25.0
  sweep_range: [20.0, 25.0, 30.0]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_stop_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5]
- name: strategy_max_hold_bars
  default: 90
  sweep_range: [60, 90, 120]
- name: strategy_max_spread_points
  default: 300
  sweep_range: [200, 300, 500]

## Author Claims

The source is used as structural lineage for channel-breakout trend following
in commodity futures. No performance number is imported into QM; Q02 and later
phases must validate or reject this deterministic `XAGUSD.DWX` rule.

## Initial Risk Profile

- expected_pf: 1.15.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 15-25 entries/year.
- risk_class: medium-high because silver has fat-tail trend reversals.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed commodity trend-following paper.
- [x] R2 mechanical: fixed Donchian entry/exit channels, ADX gate, ATR stop,
  spread gate, and max-hold exit.
- [x] R3 testable: `XAGUSD.DWX` exists in the DWX symbol universe.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: not `QM5_12567` RSI pullback, not XAU/XAG ratio, not
  oil/silver or gas/silver spread logic, and not XAU trend logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XAGUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, or the portfolio gate.

## Framework Alignment

- no_trade: XAG/D1 host guard, magic-slot guard, parameter guard, and valid
  data checks.
- trade_entry: D1 Donchian-55 trend breakout with ADX confirmation.
- trade_management: no trailing or scale-in in v1.
- trade_close: Donchian-20 contra-channel exit, max-hold exit, and framework
  hard-stop / Friday-close handling.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-02 | initial solo-silver Donchian trend card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
