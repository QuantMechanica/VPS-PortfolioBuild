---
ea_id: QM5_12830
slug: xng-exp-brk
type: strategy
strategy_id: CME-XNG-EXPIRY-BRK-2026
source_id: CME-XNG-EXPIRY-BRK-2026
source_citation: "CME Group. Chapter 220 Henry Hub Natural Gas Futures. URL https://www.cmegroup.com/rulebook/NYMEX/2/220.pdf; CME Group. Understanding Futures Expiration & Contract Roll. URL https://www.cmegroup.com/education/courses/introduction-to-futures/understanding-futures-expiration-contract-roll"
source_citations:
  - type: exchange_rulebook
    citation: "CME Group. Chapter 220 Henry Hub Natural Gas Futures."
    location: "https://www.cmegroup.com/rulebook/NYMEX/2/220.pdf"
    quality_tier: A
    role: primary
  - type: exchange_contract_specs
    citation: "CME Group. Henry Hub Natural Gas Futures Contract Specs."
    location: "https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.contractSpecs.html"
    quality_tier: A
    role: supplement
  - type: exchange_education
    citation: "CME Group. Understanding Futures Expiration & Contract Roll."
    location: "https://www.cmegroup.com/education/courses/introduction-to-futures/understanding-futures-expiration-contract-roll"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/CME-XNG-EXPIRY-BRK-2026]]"
concepts:
  - "[[concepts/henry-hub-natural-gas-futures]]"
  - "[[concepts/contract-expiration-window]]"
  - "[[concepts/channel-breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, channel-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [XNGUSD.DWX]
timeframes: [D1]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly Henry Hub natural-gas expiry-window D1 breakout; estimate 5-10 trades/year after channel, SMA, range, close-location, and spread filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
expected_pf: 1.11
expected_dd_pct: 19.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "R1 PASS official CME/NYMEX source packet; R2 PASS deterministic monthly expiry-window D1 channel breakout with SMA/range confirmation, ATR stop, window exit, and max-hold exit; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# XNG Henry Hub Expiry Breakout

## Source

- Source: [[sources/CME-XNG-EXPIRY-BRK-2026]]
- Primary citation: CME Group, "Chapter 220 Henry Hub Natural Gas Futures",
  URL https://www.cmegroup.com/rulebook/NYMEX/2/220.pdf.
- Supplements: CME Henry Hub Natural Gas contract specifications and CME
  futures expiration/contract-roll education pages.

## Concept

Henry Hub natural gas futures have a recurring monthly final-trading and
delivery process. The rulebook terminates trading in the expiring contract
before the delivery month, so participants who do not want delivery must offset
or roll positions inside a predictable window. This card does not read futures
open interest, volume, storage, weather, or curve data; it waits for
`XNGUSD.DWX` itself to confirm a D1 breakout during the approximated monthly
expiry window.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator pullback, or short-horizon
  mean reversion.
- Existing XNG seasonality, freeze, storage, LNG, weekend, month-opening-range,
  day-of-week, 52-week-anchor, and volatility-shock sleeves: this card is
  monthly Henry Hub contract-expiration flow, not weather/storage/seasonal
  demand or generic price momentum.
- `QM5_12600_cme-wti-exp-brk`: that is WTI crude-oil expiry; this isolates
  Henry Hub natural gas on `XNGUSD.DWX`.
- XTI/XNG, gas/gold, and gas/silver baskets: this is a single-symbol natural
  gas structural-flow sleeve.

## Markets And Timeframe

- Symbol: `XNGUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: about 5-10 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no CME feed,
  futures curve, open interest, volume, storage feed, weather data, CSV, API,
  analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Approximate the Henry Hub last trading day as the third business day before
  the first calendar day of the next delivery month. Weekends are handled;
  exchange holidays are not imported.
- The prior closed D1 bar must be inside
  `strategy_expiry_pre_days` before through `strategy_expiry_post_days` after
  that approximated expiry day.
- Compute the prior closed D1 close, SMA(`strategy_trend_period`),
  ATR(`strategy_atr_period`), prior `strategy_entry_channel` high/low, prior
  `strategy_exit_channel` high/low, and signal-bar close location.
- Entry Long: prior close breaks above the previous channel high, closes above
  SMA, has range at least `strategy_min_range_atr * ATR`, and closes in the top
  `strategy_min_close_location` fraction of the D1 range.
- Entry Short: prior close breaks below the previous channel low, closes below
  SMA, has the same range filter, and closes in the bottom range fraction.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if `XNGUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit Long if the prior close falls below the previous
  `strategy_exit_channel` low or below SMA.
- Exit Short if the prior close rises above the previous
  `strategy_exit_channel` high or above SMA.
- Exit any position after the expiry window ends.
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Magic slot must be 0.
- Skip entries when SMA, ATR, channel, or range values are unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_entry_channel
  default: 12
  sweep_range: [8, 12, 16, 20]
- name: strategy_exit_channel
  default: 6
  sweep_range: [4, 6, 10]
- name: strategy_trend_period
  default: 50
  sweep_range: [34, 50, 84]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.85
  sweep_range: [0.65, 0.85, 1.10]
- name: strategy_min_close_location
  default: 0.65
  sweep_range: [0.60, 0.65, 0.75]
- name: strategy_atr_sl_mult
  default: 3.25
  sweep_range: [2.50, 3.25, 4.25]
- name: strategy_max_hold_days
  default: 7
  sweep_range: [5, 7, 10]
- name: strategy_expiry_pre_days
  default: 4
  sweep_range: [3, 4, 6]
- name: strategy_expiry_post_days
  default: 2
  sweep_range: [1, 2, 3]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported from CME. The sources are used only for
structural lineage: Henry Hub Natural Gas futures have a recurring last-trading
and delivery process that can force position management before delivery.

## Initial Risk Profile

- expected_pf: 1.11
- expected_dd_pct: 19
- expected_trade_frequency: approximately 5-10 trades/year.
- risk_class: medium-high for natural-gas volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official CME/NYMEX exchange rulebook and contract
  specification source packet.
- [x] R2 mechanical: fixed calendar approximation, D1 channel/SMA breakout,
  ATR stop, window exit, and max-hold exit.
- [x] R3 testable: `XNGUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: monthly Henry Hub expiry-window breakout is not existing
  XNG RSI, storage, seasonality, weather, LNG, weekend, DOW, month-ORB,
  52-week, XTI/XNG, gas/metal, or WTI expiry logic.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, magic-slot guard, parameter guard,
  spread cap, and expiry-window calendar gate.
- trade_entry: monthly Henry Hub expiry-window D1 channel breakout with SMA,
  range, and close-location confirmation.
- trade_management: expiry-window end, failed-breakout exit, SMA failure exit,
  and max-hold stale-position exit.
- trade_close: hard ATR stop plus deterministic close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial Henry Hub natural-gas expiry-window breakout card | G0 | APPROVED |
| v1-q02 | 2026-06-30 | strict compile PASS and paced-fleet Q02 work item 964c6bbe-a5f1-4912-a4f1-f8b7ec3d0201 enqueued | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-30 | APPROVED | this card |
| Q02 Baseline Screening | 2026-06-30 | QUEUED | work_items/964c6bbe-a5f1-4912-a4f1-f8b7ec3d0201 |
