> SUPERSEDED 2026-07-02: this Codex-derived strategy-seeds fork is not the card
> of record for QM5_12844. Use
> `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12844_commodity-trend-crude.md`.

---
ea_id: QM5_12844
slug: commodity-trend-crude
type: strategy
strategy_id: BALKE_DAVEY_SLATE_B1_XTI_20260701
source_id: BALKE-DAVEY-SLATE-20260630
source_citation: "Local research slate docs/research/YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30.md, B1 Commodity Trend / Breakout; supplemental structural lineage from Davey (2014) and the V5 Turtle/ADX/ATR-trail pattern."
source_citations:
  - type: research_slate
    citation: "Balke/Davey synthesis slate, 2026-06-30, B1 Commodity Trend / Breakout - Crude & Gold."
    location: "docs/research/YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30.md"
    quality_tier: B
    role: primary
  - type: book
    citation: "Davey, Kevin J. (2014). Building Winning Algorithmic Trading Systems. Wiley."
    location: "Mechanization discipline and trend-following validation workflow."
    quality_tier: A
    role: supplemental
sources:
  - "[[research/YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30]]"
concepts:
  - "[[concepts/commodity-trend-breakout]]"
  - "[[concepts/donchian-breakout]]"
  - "[[concepts/adx-regime-filter]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/adx]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-trend, donchian-breakout, adx-filter, atr-trailing-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
timeframes: [D1]
single_symbol_only: true
period: D1
expected_trade_frequency: "D1 XTIUSD 20-bar breakout with ADX gate, 10-bar opposite-channel exit, ATR hard stop/trail, and max-hold guard; estimate 10-30 trades/year."
expected_trades_per_year_per_symbol: 18
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
expected_pf: 1.10
expected_dd_pct: 22.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "R1 PASS local approved research slate identifies the exact Donchian+ADX+ATR-trail commodity breakout recipe and Davey/Wiley is supplemental; R2 PASS deterministic D1 channel breakout, ADX gate, ATR stop/trail, reverse-channel and time exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# Crude Commodity Trend Breakout

## Source

- Primary source: `docs/research/YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30.md`,
  B1 "Commodity Trend / Breakout - Crude & Gold".
- Supplemental source: Davey, Kevin J. (2014). *Building Winning Algorithmic
  Trading Systems*. Wiley.

## Concept

The research slate calls for a low-frequency commodity trend breakout:
20-bar buy-stop/sell-stop style channel triggers, ADX(11) above about 20,
symmetric long/short operation, and a 3.0x ATR(14) volatility trail. This
card specializes the idea to Darwinex WTI proxy `XTIUSD.DWX` on D1 so the
portfolio receives direct crude exposure rather than another index, gold,
silver, or natural-gas variant.

This is deliberately different from:

- `QM5_12563_donchian-turtle-trend-commodity`: this card is crude-only and
  adds an ADX(11) trend-state gate, ATR(14) 3.0x trailing stop, and max-hold
  guard instead of the multi-commodity Turtle 2N stop with volatility
  percentile filter.
- `QM5_12603_wti-tsmom12m` and `QM5_12616_tsmom-9m-commodity-xtiusd`: this
  card is a D1 channel breakout, not monthly return-sign time-series momentum.
- `QM5_12757_abraham-xti-pb`: this card enters the breakout close directly
  with ADX confirmation, not a later pullback to a breakout boundary with MACD
  alignment.
- `QM5_12842_williams-vol-bo-xti`: this card is symmetric closed-bar trend
  following, not a long-only prior-range buy-stop expansion rule.
- XAU/XAG, XTI/XNG, oil/gold, oil/silver, and XNG sleeves: this card carries
  outright WTI trend exposure only.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: about 10-30 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, framework ADX/ATR readers, broker state,
  framework news and Friday-close guards. No futures curve, inventory feed,
  CFTC data, volume, external API, CSV, or ML model.

## Entry Rules

- Evaluate only after a new D1 bar starts, using the just-closed D1 bar.
- Compute the 20-bar channel from the 20 D1 bars before the just-closed bar.
- Compute ADX(11) and ATR(14) on the just-closed D1 bar.
- Skip entries when ADX(11) is less than or equal to `strategy_adx_threshold`.
- Enter long at market if the just-closed D1 close is above the prior 20-bar
  channel high.
- Enter short at market if the just-closed D1 close is below the prior 20-bar
  channel low.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: hard broker-side SL at ATR(14) * `strategy_atr_sl_mult` from the
  entry price.
- Reverse-channel exit: close a long when the just-closed D1 close is below
  the prior 10-bar channel low; close a short when it is above the prior
  10-bar channel high.
- ATR trail: after favorable movement exceeds
  `strategy_trail_activation_atr * ATR(14)`, trail using
  `strategy_atr_trail_mult * ATR(14)`.
- Time exit: close any position after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- Skip entries when channel, ADX, ATR, entry price, or stop price is
  unavailable.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_entry_period
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_exit_period
  default: 10
  sweep_range: [8, 10, 15]
- name: strategy_adx_period
  default: 11
  sweep_range: [9, 11, 14]
- name: strategy_adx_threshold
  default: 20.0
  sweep_range: [18.0, 20.0, 23.0, 25.0]
- name: strategy_atr_period
  default: 14
  sweep_range: [14, 20]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 3.5]
- name: strategy_atr_trail_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 3.5]
- name: strategy_trail_activation_atr
  default: 1.0
  sweep_range: [0.0, 1.0, 1.5]
- name: strategy_max_hold_days
  default: 45
  sweep_range: [30, 45, 65]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The research slate is used only for structural lineage around a crude-first
Donchian+ADX+ATR-trail trend recipe. No performance number is imported into
QM; Q02 and later phases must validate or reject the `XTIUSD.DWX`
specialization on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 22.
- expected_trade_frequency: approximately 10-30 trades/year.
- risk_class: high because WTI gaps and trend reversals can be abrupt.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: approved local research slate plus Davey/Wiley
  validation discipline as supplemental source.
- [x] R2 mechanical: fixed channel, ADX, ATR, reverse-channel, and time-exit
  rules.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, or more
  than one position per magic.
- [x] Non-duplicate: this is crude-only D1 Donchian+ADX+ATR-trail trend, not
  the existing multi-commodity Turtle rule, WTI monthly TSMOM, WTI pullback,
  prior-range expansion, gas, metal, or index sleeve.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX`
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, or the portfolio gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard,
  spread cap, and position-duplication guard.
- trade_entry: closed-D1 20-bar breakout with ADX(11) regime gate.
- trade_management: max-hold exit and ATR trailing stop.
- trade_close: hard ATR stop plus 10-bar opposite-channel exit.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-01 | initial crude commodity-trend build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12844_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` |
