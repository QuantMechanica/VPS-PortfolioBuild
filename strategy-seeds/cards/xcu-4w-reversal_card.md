---
ea_id: QM5_13081
slug: xcu-4w-reversal
type: strategy
strategy_id: YANG-CME-USGS-XCU-REVERSAL-2026
source_id: YANG-CME-USGS-XCU-REVERSAL-2026
source_citation: "Yang, Goncu, and Pantelous commodity futures momentum/reversal paper, plus CME Copper Futures and USGS Copper Statistics references."
source_citations:
  - type: academic_paper
    citation: "Yang, Goncu, and Pantelous. Momentum and Reversal in Commodity Futures."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253"
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
  - "[[sources/YANG-CME-USGS-XCU-REVERSAL-2026]]"
concepts:
  - "[[concepts/short-term-reversal]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/base-metal-sleeve]]"
indicators:
  - "[[indicators/n-day-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [short-term-reversal, mean-reversion, weekly-gate, atr-hard-stop, time-stop, symmetric-long-short, low-frequency, base-metal]
target_symbols: [XCUUSD.DWX]
primary_target_symbols: [XCUUSD.DWX]
markets: [commodities, base_metals, copper]
single_symbol_only: true
logical_symbol: QM5_13081_XCU_4W_REVERSAL_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Weekly D1 XCUUSD.DWX 20-bar overreaction reversal gate; estimate 8-18 trades/year after threshold, spread, and one-position filters."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, symbol_history_sufficiency, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS accepted academic commodity reversal source plus official CME/USGS copper references; R2 PASS deterministic weekly D1 20-bar XCU return-threshold reversal with ATR hard stop, max-hold exit, and spread cap; R3 PASS XCUUSD.DWX is present in the DWX registry symbol universe; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate because this is a solo copper short-horizon reversal sleeve, not QM5_13080 XCU Donchian trend, not XAU/XAG, XTI, XNG, Brent, index, commodity-RSI, or market-neutral spread logic."
---

# XCUUSD Four-Week Commodity Reversal

## Source

- Primary: Yang, Goncu, and Pantelous, "Momentum and Reversal in Commodity
  Futures", SSRN, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253.
- Supplements: CME Copper Futures product page and USGS Copper Statistics and
  Information.

## Concept

Commodity futures reversal research documents that fixed-horizon commodity
moves can overshoot before reverting. This card isolates that short-term
reversal premise on copper: when `XCUUSD.DWX` has moved far over the prior 20
D1 bars, fade the move on a weekly cadence with a fixed ATR loss cap and a
three-week maximum hold.

This adds a base-metal commodity sleeve that is different from the current
XAU/SP500/NDX/XNG book and different from the existing `QM5_13080`
XCU Donchian trend card. It is a weekly mean-reversion edge, not a trend
breakout, energy event, metal-ratio, index, or RSI commodity pullback rule.

## Markets And Timeframe

- Symbol: `XCUUSD.DWX`.
- Period: D1.
- Evaluate entries only on the first D1 bar of the trading week.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC, spread, ATR, broker calendar, and V5
  framework state only.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current D1 bar must be Monday in broker time.
- Compute the prior closed D1 close and the close
  `strategy_lookback_days` bars earlier.
- Long setup: lookback return is less than or equal to
  `-strategy_min_abs_return_pct`; BUY `XCUUSD.DWX`.
- Short setup: lookback return is greater than or equal to
  `strategy_min_abs_return_pct`; SELL `XCUUSD.DWX`.
- No entry if an open `XCUUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XCUUSD.DWX` on D1.
- Skip entries when ATR, return history, spread, or entry price is unavailable.
- Standard framework news, kill-switch, magic, risk, spread, and Friday-close
  guards remain active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_lookback_days
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_atr_period
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_min_abs_return_pct
  default: 4.0
  sweep_range: [3.0, 4.0, 5.5, 7.0]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0, 3.5]
- name: strategy_max_hold_days
  default: 21
  sweep_range: [14, 21, 28]
- name: strategy_max_spread_points
  default: 1200
  sweep_range: [800, 1200, 1800]

## Author Claims

No performance claim is imported into QM. The source is used only for
structural lineage around commodity momentum/reversal families; Q02 and later
phases must validate or reject this mechanical `XCUUSD.DWX` port.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 8-18 entries/year.
- risk_class: medium-high because copper can gap around macro, China growth,
  and supply shocks.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: accepted academic commodity futures reversal paper
  plus official CME and USGS copper references.
- [x] R2 mechanical: fixed weekly gate, D1 return threshold, ATR hard stop,
  spread cap, and max-hold exit.
- [x] R3 testable: `XCUUSD.DWX` exists in the DWX symbol universe.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  no external runtime feed, and one position per magic.
- [x] Non-duplicate: not `QM5_13080` XCU Donchian trend, not RSI2 pullback,
  not XAU/XAG, not XTI/XNG/Brent, not index, and not a spread basket.

## Framework Alignment

- no_trade: D1 and XCUUSD.DWX guard, parameter guard, spread cap.
- trade_entry: weekly 20-D1-bar return extreme fade.
- trade_management: max-hold stale-position exit.
- trade_close: hard ATR stop plus deterministic time exit and framework
  Friday-close handling.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-09 | initial structural XCU commodity-reversal build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
| Q01 Build Validation | TBD | TBD | TBD |
| Q02 Baseline Screening | TBD | TBD | enqueue after compile |

