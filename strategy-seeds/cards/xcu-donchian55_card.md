---
ea_id: QM5_13080
slug: xcu-donchian55
type: strategy
strategy_id: SZAKMARY-CME-USGS-XCU-TREND-2026
source_id: SZAKMARY-CME-USGS-XCU-TREND-2026
source_citation: "Szakmary, Shen and Sharma (2010) commodity futures trend-following paper, plus CME Copper Futures and USGS Copper Statistics references."
source_citations:
  - type: academic_paper
    citation: "Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010). Trend-following trading strategies in commodity futures: A re-examination. Journal of Banking and Finance, 34(2), 409-426."
    location: "https://doi.org/10.1016/j.jbankfin.2009.10.012"
    quality_tier: A
    role: primary
  - type: exchange_reference
    citation: "CME Group. Copper Futures product page."
    location: "https://www.cmegroup.com/markets/metals/base/copper.html"
    quality_tier: A
    role: copper_market_reference
  - type: government_reference
    citation: "U.S. Geological Survey. Copper Statistics and Information."
    location: "https://www.usgs.gov/centers/national-minerals-information-center/copper-statistics-and-information"
    quality_tier: A
    role: industrial_base_metal_context
sources:
  - "[[sources/SZAKMARY-CME-USGS-XCU-TREND-2026]]"
concepts:
  - "[[concepts/donchian-channel]]"
  - "[[concepts/channel-breakout]]"
  - "[[concepts/trend-following-commodity]]"
  - "[[concepts/base-metal-sleeve]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/adx]]"
  - "[[indicators/atr]]"
strategy_type_flags: [channel-breakout, trend-following, base-metal, atr-hard-stop, channel-contra-exit, symmetric-long-short, low-frequency]
target_symbols: [XCUUSD.DWX]
primary_target_symbols: [XCUUSD.DWX]
markets: [commodities, base_metals, copper]
single_symbol_only: true
logical_symbol: QM5_13080_XCU_DONCHIAN55_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XCUUSD 55-period Donchian close-channel breakout with ADX regime filter; estimate 10-20 entries/year after filter before Q02 validation."
expected_trades_per_year_per_symbol: 14
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.10
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, symbol_history_sufficiency, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS peer-reviewed commodity trend-following source plus official CME/USGS copper references; R2 PASS deterministic D1 XCU Donchian-55 breakout with ADX gate, ATR hard stop, contra-channel exit, max-hold exit, and spread cap; R3 PASS XCUUSD.DWX is present in the DWX registry symbol universe; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate because no existing V5 card or EA targets XCUUSD.DWX; this is a solo base-metal trend sleeve, not XAU/XAG, XTI, XNG, Brent, index, commodity-RSI, or market-neutral spread logic."
---

# XCUUSD Donchian-55 Trend

## Source

- Primary: Szakmary, Shen and Sharma (2010), "Trend-following trading
  strategies in commodity futures: A re-examination", Journal of Banking and
  Finance, DOI https://doi.org/10.1016/j.jbankfin.2009.10.012.
- Supplements: CME Copper Futures product page and USGS Copper Statistics and
  Information.

## Concept

This card converts peer-reviewed commodity trend-following evidence into a
single-symbol copper sleeve. Copper is a base-metal/industrial commodity, so it
adds exposure that is distinct from the current XAU, SP500, NDX, and XNG book
while staying inside the Darwinex MT5 symbol universe.

The rule is deliberately simple: trade `XCUUSD.DWX` D1 close-channel breakouts
only when ADX confirms a trend regime, then exit on a shorter contra-channel,
ATR hard stop, stale-position time stop, or framework Friday close.

## Markets And Timeframe

- Symbol: `XCUUSD.DWX`.
- Period: D1.
- Expected frequency: roughly 10-20 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, ADX, ATR, broker calendar, and V5
  framework state only.

## Entry Rules

- Evaluate only on a new D1 bar.
- Host chart must be `XCUUSD.DWX` on D1 with magic slot 0.
- No entry if an open `XCUUSD.DWX` position already exists for this EA magic.
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

- Only trade `XCUUSD.DWX` on D1.
- Magic slot offset must be 0.
- ADX regime filter blocks low-trend entries.
- Spread filter blocks wide entry spreads; zero modeled spread in `.DWX`
  backtests is allowed.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
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
  default: 22.0
  sweep_range: [18.0, 22.0, 26.0]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_stop_mult
  default: 2.25
  sweep_range: [1.75, 2.25, 2.75]
- name: strategy_max_hold_bars
  default: 90
  sweep_range: [60, 90, 120]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [600, 1000, 1600]

## Author Claims

The source is used as structural lineage for commodity futures trend following.
No performance number is imported into QM; Q02 and later phases must validate
or reject this deterministic `XCUUSD.DWX` rule on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 10-20 entries/year.
- risk_class: medium-high because base metals can gap around macro and China
  growth shocks.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed commodity trend-following paper plus
  official CME and USGS copper references.
- [x] R2 mechanical: fixed Donchian entry/exit channels, ADX gate, ATR stop,
  spread gate, and max-hold exit.
- [x] R3 testable: `XCUUSD.DWX` exists in the DWX symbol universe.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: repository search found no existing V5 card or EA for
  `XCUUSD.DWX`; not XAU/XAG, XTI, XNG, Brent, index, commodity-RSI, or spread
  logic.

## Framework Alignment

- no_trade: XCU/D1 host guard, magic-slot guard, parameter guard, and valid
  data checks.
- trade_entry: D1 Donchian-55 trend breakout with ADX confirmation.
- trade_management: no trailing, partial close, or scale-in in v1.
- trade_close: Donchian-20 contra-channel exit, max-hold exit, ATR hard stop,
  and framework Friday-close handling.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-09 | initial solo-copper Donchian trend card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
| Q01 Build Validation | TBD | TBD | TBD |
| Q02 Baseline Screening | TBD | TBD | enqueue after compile |

