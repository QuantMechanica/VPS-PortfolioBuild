---
ea_id: QM5_12839
slug: wti-exp-fade
type: strategy
strategy_id: CME-WTI-EXPIRY-BRK-2026_S03
source_id: CME-WTI-EXPIRY-BRK-2026
source_citation: "CME Group. Chapter 200 Light Sweet Crude Oil Futures. URL https://www.cmegroup.com/rulebook/NYMEX/2/200.pdf; CME Group. Understanding Futures Expiration & Contract Roll. URL https://www.cmegroup.com/education/courses/introduction-to-futures/understanding-futures-expiration-contract-roll"
source_citations:
  - type: exchange_rulebook
    citation: "CME Group. Chapter 200 Light Sweet Crude Oil Futures."
    location: "https://www.cmegroup.com/rulebook/NYMEX/2/200.pdf"
    quality_tier: A
    role: primary
  - type: exchange_contract_specs
    citation: "CME Group. Light Sweet Crude Oil Futures Contract Specs."
    location: "https://www.cmegroup.com/markets/energy/crude-oil/light-sweet-crude.contractSpecs.html"
    quality_tier: A
    role: supplement
  - type: exchange_education
    citation: "CME Group. Understanding Futures Expiration & Contract Roll."
    location: "https://www.cmegroup.com/education/courses/introduction-to-futures/understanding-futures-expiration-contract-roll"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/CME-WTI-EXPIRY-BRK-2026]]"
concepts:
  - "[[concepts/wti-futures-expiration]]"
  - "[[concepts/contract-roll-window]]"
  - "[[concepts/failed-breakout-fade]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, structural-flow, failed-breakout-fade, mean-reversion, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
timeframes: [D1]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly WTI expiry-window failed-breakout fade; estimate 4-8 trades/year after channel, close-back-inside, SMA, range, and spread filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "R1 PASS official CME/NYMEX source packet; R2 PASS deterministic monthly WTI expiry-window D1 failed-breakout fade with SMA mean exit, channel normalization, ATR stop, window exit, and max-hold exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# WTI CME Expiry Failed-Breakout Fade

## Source

- Source: [[sources/CME-WTI-EXPIRY-BRK-2026]]
- Primary citation: CME Group, "Chapter 200 Light Sweet Crude Oil Futures",
  URL https://www.cmegroup.com/rulebook/NYMEX/2/200.pdf.
- Supplements: CME Light Sweet Crude Oil futures contract specifications and
  CME futures expiration/contract-roll education pages.

## Concept

WTI crude futures have a recurring monthly front-contract termination and roll
cycle. Participants who do not want delivery must offset or roll positions
before expiration, creating a predictable position-management window. This card
tests the opposite behavior to `QM5_12600_cme-wti-exp-brk`: instead of following
expiry-window breakouts, it fades failed channel breaches where the D1 bar
trades beyond a prior channel but closes back inside it.

This is deliberately different from:

- `QM5_12600_cme-wti-exp-brk`: this card requires breakout failure and re-entry;
  it does not buy confirmed upside breakouts or sell confirmed downside
  breakouts.
- `QM5_12743_wti-postroll-fade`: this card trades the expiry window itself,
  not the post-roll pressure-relief window.
- WTI WPSR, Cushing, refinery, hurricane, OPEC, SPR, driving-season,
  month-of-year, day-of-week, month-opening-range, 52-week-anchor, TSMOM,
  and commodity-reversal sleeves: timing and entry mechanics differ.
- XTI/FX, XTI/XNG, oil/gold, oil/silver, XAU/XAG, gas/metal, and XNG sleeves:
  this is a single-symbol WTI expiry failed-breakout fade.
- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator pullback, or generic
  short-horizon commodity mean reversion.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: about 4-8 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no CME feed,
  futures curve, open interest, volume, inventory feed, CSV, API, analyst
  forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Approximate the monthly CME WTI futures termination date as the third business
  day before the 25th calendar day; if the 25th is a weekend, use the prior
  business day as the anchor. Weekends are handled; exchange holidays are not
  imported.
- The prior closed D1 bar must be inside
  `strategy_expiry_pre_days` before through `strategy_expiry_post_days` after
  that approximated expiry day.
- Compute prior D1 OHLC, SMA(`strategy_mean_period`),
  ATR(`strategy_atr_period`), previous `strategy_entry_channel` high/low,
  previous `strategy_exit_channel` high/low, and the signal-bar close location.
- Long fade: prior low breaks below the previous channel low, prior close
  recovers above that channel low, prior close is at or below the SMA mean, the
  bar range is at least `strategy_min_range_atr * ATR`, and close location is
  at least `strategy_reentry_close_location`.
- Short fade: prior high breaks above the previous channel high, prior close
  falls back below that channel high, prior close is at or above the SMA mean,
  the same range filter passes, and close location is no higher than
  `1 - strategy_reentry_close_location`.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit long when prior close reaches or exceeds the SMA mean, rises through the
  previous `strategy_exit_channel` high, the expiry window ends, max hold
  expires, Friday close triggers, or the hard stop is hit.
- Exit short when prior close reaches or falls below the SMA mean, falls through
  the previous `strategy_exit_channel` low, the expiry window ends, max hold
  expires, Friday close triggers, or the hard stop is hit.

## Filters

- Only trade `XTIUSD.DWX` on D1.
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
- name: strategy_mean_period
  default: 50
  sweep_range: [34, 50, 84]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.75
  sweep_range: [0.60, 0.75, 1.00]
- name: strategy_reentry_close_location
  default: 0.55
  sweep_range: [0.55, 0.60, 0.70]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.25, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 6
  sweep_range: [4, 6, 9]
- name: strategy_expiry_pre_days
  default: 3
  sweep_range: [2, 3, 5]
- name: strategy_expiry_post_days
  default: 2
  sweep_range: [1, 2, 3]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported from CME. The sources are used only for
structural lineage: WTI is a listed futures market with a recurring termination
and delivery/roll process that can force position management before settlement.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 20
- expected_trade_frequency: approximately 4-8 trades/year.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official CME/NYMEX exchange rulebook and contract
  specification source packet.
- [x] R2 mechanical: fixed calendar approximation, D1 failed-breakout fade,
  SMA/channel/time exits, and ATR hard stop.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: monthly WTI expiry-window failed-breakout fade is not the
  existing WTI expiry breakout, post-roll fade, WTI event/calendar/trend/
  reversal family, XTI baskets, XNG logic, XAU/XAG logic, or RSI commodity
  pullback.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` setfile.
Live risk is intentionally not configured here; any future live allocation must
come from the portfolio process. The EA does not touch `T_Live`, AutoTrading,
deploy manifests, or the portfolio gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard,
  spread cap, and expiry-window calendar gate.
- trade_entry: monthly WTI expiry-window D1 failed-breakout fade with range and
  close-back-inside confirmation.
- trade_management: expiry-window end, SMA mean-reversion exit, channel
  normalization exit, and max-hold stale-position exit.
- trade_close: hard ATR stop plus deterministic close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-01 | initial WTI expiry-window failed-breakout fade build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12839_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `2ecee84f-2e19-4f3e-9e2f-3cd4c3fece7e` |
