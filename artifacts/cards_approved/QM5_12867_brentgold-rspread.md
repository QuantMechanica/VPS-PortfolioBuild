---
ea_id: QM5_12867
slug: brentgold-rspread
type: strategy
strategy_id: CME-OIL-GOLD-RATIO-2024_BRENT_S04
source_id: CME-OIL-GOLD-RATIO-2024
source_citation: "CME Group. Through the Lens of Gold. 2024. URL https://www.cmegroup.com/articles/2024/through-the-lens-of-gold.html"
source_citations:
  - type: exchange_article
    citation: "CME Group. Through the Lens of Gold. 2024."
    location: "https://www.cmegroup.com/articles/2024/through-the-lens-of-gold.html"
    quality_tier: A
    role: primary
sources:
  - "[[sources/CME-OIL-GOLD-RATIO-2024]]"
concepts:
  - "[[concepts/oil-gold-ratio]]"
  - "[[concepts/relative-return-shock]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/rolling-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [market-neutral-basket, oil-gold-relative-value, return-spread-zscore, mean-reversion-exit, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XBRUSD.DWX, XAUUSD.DWX]
primary_target_symbols: [XBRUSD.DWX, XAUUSD.DWX]
markets: [XBRUSD.DWX, XAUUSD.DWX]
timeframes: [D1]
logical_symbol: QM5_12867_XBR_XAU_RSPREAD_D1
single_symbol_only: false
period: D1
expected_trade_frequency: "Low-frequency D1 XBR/XAU return-spread z-score reversion; estimate 6-14 paired packages/year before Q02 validates history and fills."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
expected_pf: 1.08
expected_dd_pct: 22.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, xbr_history_sufficiency, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "R1 PASS single CME exchange source packet; R2 PASS deterministic D1 Brent-minus-gold return-spread z-score entry, mean exit, max-hold exit, spread caps, and ATR hard stops; R3 PASS XAUUSD.DWX is in the DWX symbol matrix and XBRUSD.DWX has active local Brent routes through prior builds with Q02 validating current XBR history sufficiency; R4 PASS no ML/grid/martingale/external runtime feed."
---

# Brent/Gold Return-Spread Reversion

## Source

- Source: [[sources/CME-OIL-GOLD-RATIO-2024]]
- Primary citation: CME Group, "Through the Lens of Gold", 2024, URL
  https://www.cmegroup.com/articles/2024/through-the-lens-of-gold.html.

## Concept

CME frames crude oil through gold as a relative-value lens rather than an
outright oil forecast. This card ports that lens to the Brent CFD proxy and
keeps the expression paired: `XBRUSD.DWX` versus `XAUUSD.DWX` on completed D1
bars. The signal is a fixed-window relative-return divergence:

`return_spread = ln(XBR_t / XBR_t-N) - beta * ln(XAU_t / XAU_t-N)`

If Brent has overrun gold over the return window, the basket sells Brent and
buys gold. If gold has overrun Brent, the basket buys Brent and sells gold.
The thesis is short-horizon relative-return snapback inside a structural
oil/gold pair, not outright Brent trend and not outright gold exposure.

This is deliberately different from:

- `QM5_12863_oilgold-rspread`: WTI/gold return spread. This card uses Brent as
  the crude-oil leg.
- `QM5_12604_cme-oilgold-ratio`: absolute WTI/gold price-ratio level reversion.
- `QM5_12605_cme-oilgold-brk`: oil/gold ratio breakout.
- `QM5_12860_wti-brent-rshock`: two crude benchmarks rather than energy versus
  gold.
- `QM5_12862_xauxag-rspread`: intra-metals relative-return shock.
- Directional Brent/WTI/XNG/XAU, index, calendar, inventory, roll, and
  `QM5_12567_cum-rsi2-commodity` sleeves: every entry is a paired package and
  uses no RSI, oscillator pullback, ML, grid, martingale, or external feed.

## Markets And Timeframe

- Logical symbol: `QM5_12867_XBR_XAU_RSPREAD_D1`.
- Host symbol: `XBRUSD.DWX`.
- Second leg: `XAUUSD.DWX`.
- Period: D1.
- Expected package frequency: about 6-14 paired packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker calendar, and V5
  framework state only. No CME feed, futures curve, CFTC data, inventory data,
  CSV, API, analyst forecast, alternative data, or ML model.

## Entry Rules

- Evaluate only on a new D1 host bar after both completed D1 close series are
  available.
- Compute the latest `strategy_return_lookback_d1` D1 log return for
  `XBRUSD.DWX` and `XAUUSD.DWX`.
- Compute `return_spread = return_XBR - beta * return_XAU`.
- Standardize the return spread using the last `strategy_z_lookback_d1`
  completed return-spread observations.
- If z-score is above `strategy_entry_z`, Brent has outperformed gold sharply:
  sell `XBRUSD.DWX` and buy `XAUUSD.DWX`.
- If z-score is below negative `strategy_entry_z`, gold has outperformed Brent
  sharply: buy `XBRUSD.DWX` and sell `XAUUSD.DWX`.
- No entry if either leg has an open position for this EA magic.
- No entry if either leg exceeds its spread cap.

## Exit Rules

- Close both legs when absolute return-spread z-score falls below
  `strategy_exit_z`.
- Close both legs after `strategy_max_hold_days` calendar days.
- Close both legs through the V5 Friday-close hook.
- If only one leg remains open, immediately flatten the orphaned leg.
- Per-leg hard stop: ATR(`strategy_atr_period_d1`) *
  `strategy_atr_sl_mult`.

## Filters

- Only trade from an `XBRUSD.DWX` D1 host chart.
- Magic slot offset must be 0 on the host.
- Skip entries when either D1 history series, ATR, spread, or symbol metadata is
  unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Two-leg basket only.
- Symmetric long/short Brent/gold relative-value package.
- No pyramiding, gridding, martingale, partial close, or trailing stop.
- One package per EA magic.

## Parameters To Test

- name: strategy_return_lookback_d1
  default: 10
  sweep_range: [5, 10, 20]
- name: strategy_z_lookback_d1
  default: 120
  sweep_range: [80, 120, 180]
- name: strategy_beta
  default: 1.0
  sweep_range: [0.8, 1.0, 1.2]
- name: strategy_entry_z
  default: 2.0
  sweep_range: [1.7, 2.0, 2.3]
- name: strategy_exit_z
  default: 0.4
  sweep_range: [0.25, 0.4, 0.6]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 20
  sweep_range: [10, 20, 30]
- name: strategy_xbr_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_xau_max_spread_pts
  default: 500
  sweep_range: [300, 500, 800]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]

## Author Claims

The CME source establishes the oil/gold relative-value lens. This card imports
no source performance claim. Q02 and later phases must validate or reject the
mechanical rule on Darwinex `XBRUSD.DWX` and `XAUUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 22.
- expected_trade_frequency: approximately 6-14 paired packages/year.
- risk_class: high because Brent history sufficiency, gold hedge behavior, and
  basket execution quality all need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: single CME exchange article source packet.
- [x] R2 mechanical: fixed D1 return-spread z-score entry, normalization exit,
  time stop, spread caps, and ATR hard stops.
- [x] R3 testable: `XAUUSD.DWX` exists in the DWX symbol universe and
  `XBRUSD.DWX` has active local Brent routes through prior builds; Q02 validates
  current XBR history sufficiency.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one package per magic.
- [x] Non-duplicate: this is XBR/XAU return-spread reversion, not XTI/XAU
  return-spread, XTI/XAU price-ratio level reversion, oil/gold ratio breakout,
  XTI/XNG relative value, WTI/Brent return shock, XAU/XAG return-spread,
  commodity RSI, or directional Brent/gold exposure.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: host/timeframe guard, magic-slot guard, parameter guard, spread
  caps, return-spread data sufficiency, and valid lot/ATR checks.
- trade_entry: D1 standardized XBR/XAU return-spread reversion.
- trade_management: z-score mean exit, max-hold stale-package exit, orphan leg
  cleanup, and Friday close.
- trade_close: hard ATR stop plus deterministic package close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-02 | initial XBR/XAU return-spread basket build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
| Q01 Build Validation | 2026-07-02 | PASS | `artifacts/qm5_12867_build_result.json` |
| Q02 Baseline Screening | 2026-07-02 | QUEUED | work item `9842f766-769d-474a-b78e-bfd02ba07924` |
