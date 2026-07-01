---
ea_id: QM5_12860
slug: wti-brent-rshock
type: strategy
strategy_id: CME-WTI-BRENT-SPREAD-2026_S03
source_id: CME-WTI-BRENT-SPREAD-2026
source_citation: "CME Group WTI-Brent Financial Futures; ICE Brent/WTI Futures Spread; U.S. EIA Today in Energy Brent-WTI spread analysis."
source_citations:
  - type: exchange_reference
    citation: "CME Group. WTI-Brent Financial Futures."
    location: "https://www.cmegroup.com/markets/energy/crude-oil/wti-brent-ice-calendar-swap-futures.html"
    quality_tier: A
    role: primary
  - type: exchange_reference
    citation: "ICE. Brent/WTI Futures Spread."
    location: "https://www.ice.com/products/1242/Brent-WTI-Futures-Spread/data"
    quality_tier: A
    role: corroborating
  - type: government_agency_analysis
    citation: "U.S. Energy Information Administration. Today in Energy Brent-WTI spread analysis."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=67424"
    quality_tier: A
    role: structural_context
sources:
  - "[[sources/CME-WTI-BRENT-SPREAD-2026]]"
concepts:
  - "[[concepts/crude-benchmark-spread]]"
  - "[[concepts/brent-wti-relative-value]]"
  - "[[concepts/relative-return-shock]]"
indicators:
  - "[[indicators/rolling-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [pair-return-shock-fade, market-neutral-basket, mean-reversion-exit, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX, XBRUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XBRUSD.DWX]
markets: [XTIUSD.DWX, XBRUSD.DWX]
logical_symbol: QM5_12860_WTI_BRENT_RSHOCK_D1
single_symbol_only: false
period: D1
timeframes: [D1]
expected_trade_frequency: "Low-frequency D1 Brent-minus-WTI return-shock fade; estimate 6-14 paired packages/year before Q02 validates history and fills."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
g0_approval_reasoning: "R1 PASS single approved source packet with CME/ICE exchange references plus EIA structural spread analysis; R2 PASS deterministic D1 return-spread z-score fade, normalization exit, time stop, and ATR stops; R3 PASS XTI history exists and XBR route is represented by prior Brent builds, with Q02 validating current XBR history sufficiency; R4 PASS no ML/grid/martingale/external runtime feed."
expected_pf: 1.08
expected_dd_pct: 22.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, basket_execution, friday_close, magic_schema, risk_mode_dual]
---

# WTI-Brent Return-Shock Fade

## Source

- Source: [[sources/CME-WTI-BRENT-SPREAD-2026]]
- Primary references: CME WTI-Brent Financial Futures, ICE Brent/WTI Futures
  Spread, and EIA Brent-WTI spread market-structure analysis.

## Concept

Brent and WTI are separate crude benchmarks with a traded spread and a persistent
structural basis. This card tests a market-neutral basket that fades short,
completed-bar relative-return shocks between the two benchmarks:

`return_spread = ln(XBR_t / XBR_t-N) - beta * ln(XTI_t / XTI_t-N)`

The signal is not the level of the Brent-WTI price spread. It is the z-score of
the latest short-horizon Brent-minus-WTI return spread against its own recent
history. When Brent has overrun WTI over the lookback window, the basket sells
Brent and buys WTI. When WTI has overrun Brent, it buys Brent and sells WTI.

This is deliberately different from:

- `QM5_12843_wti-brent-spread`: this card fades a short-horizon return shock;
  12843 fades a rolling z-score of the log price-spread level.
- `QM5_12848_wti-brent-brk`: this card is contrarian; 12848 follows a Donchian
  breakout in the log price-spread level.
- `QM5_12840_xti-xng-rspread`: that card trades oil versus natural gas; this
  card is a crude benchmark WTI/Brent basket.
- XTI/XNG, XBR/XNG, XAU/XAG, gas-metal, single-symbol WTI/Brent calendar,
  commodity trend, and `QM5_12567_cum-rsi2-commodity` sleeves: this uses no
  RSI, oscillator pullback, calendar month, weekday, inventory, or index logic.

## Markets And Timeframe

- Logical basket symbol: `QM5_12860_WTI_BRENT_RSHOCK_D1`.
- Host symbol: `XTIUSD.DWX`.
- Second leg: `XBRUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 6-14 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only.

`XBRUSD.DWX` is intentionally queued only for Q02 validation. The local registry
already has XBR routes through prior Brent setfiles, but current synchronized
XTI/XBR history sufficiency must be confirmed by the paced backtest fleet.

## Entry Rules

- Evaluate only on a new D1 host bar after both completed D1 close series are
  available.
- Compute the latest `strategy_return_lookback_d1` D1 log return for
  `XBRUSD.DWX` and `XTIUSD.DWX`.
- Compute `return_spread = return_XBR - beta * return_XTI`.
- Standardize the return spread using the last
  `strategy_z_lookback_d1` completed return-spread observations.
- If z-score is above `strategy_entry_z`, Brent has outperformed WTI sharply:
  sell `XBRUSD.DWX` and buy `XTIUSD.DWX`.
- If z-score is below negative `strategy_entry_z`, WTI has outperformed Brent
  sharply: buy `XBRUSD.DWX` and sell `XTIUSD.DWX`.
- No entry if either leg has an open position for this EA magic.
- No entry if either leg exceeds its spread cap.

## Exit Rules

- Close both legs when absolute return-shock z-score falls below
  `strategy_exit_z`.
- Close both legs after `strategy_max_hold_days` calendar days.
- Close both legs through the V5 Friday-close hook.
- If only one leg remains open, immediately flatten the orphaned leg.
- Per-leg hard stop: ATR(`strategy_atr_period_d1`) *
  `strategy_atr_sl_mult`.

## Filters

- Only trade from an `XTIUSD.DWX` D1 host chart.
- Magic slot offset must be 0 on the host.
- Skip entries when either D1 history series, ATR, spread, or symbol metadata is
  unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Two-leg basket only.
- Symmetric long/short crude benchmark spread package.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One package per EA magic.

## Parameters To Test

- name: strategy_return_lookback_d1
  default: 5
  sweep_range: [3, 5, 10]
- name: strategy_z_lookback_d1
  default: 120
  sweep_range: [80, 120, 180]
- name: strategy_beta
  default: 1.0
  sweep_range: [0.8, 1.0, 1.2]
- name: strategy_entry_z
  default: 2.0
  sweep_range: [1.8, 2.0, 2.3]
- name: strategy_exit_z
  default: 0.35
  sweep_range: [0.25, 0.35, 0.5]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_xti_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_xbr_max_spread_pts
  default: 1500
  sweep_range: [1000, 1500, 2500]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]

## Author Claims

The source packet establishes that Brent-WTI is an exchange-recognized crude
benchmark spread with independent agency analysis. No source performance number
is imported into QM. Q02 and later phases must validate the mechanical rule on
Darwinex `XTIUSD.DWX` and `XBRUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 22
- expected_trade_frequency: approximately 6-14 paired packages/year.
- risk_class: high because the Brent CFD history route and basket execution
  quality both need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: one approved source packet with CME/ICE exchange
  references and EIA structural spread analysis.
- [x] R2 mechanical: fixed D1 relative-return z-score entry, normalization
  exit, time stop, ATR hard stops.
- [x] R3 testable: `XTIUSD.DWX` history is in registry and `XBRUSD.DWX` has a
  farm route through prior XBR setfiles; Q02 validates current basket history.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one package per magic.
- [x] Non-duplicate: Brent/WTI return-shock fade is not the existing
  Brent/WTI spread-level z-score reversion, Brent/WTI spread breakout,
  XTI/XNG return-spread reversion, XNG, XAU/XAG, WTI/Brent calendar, or
  commodity RSI sleeve.

## Framework Alignment

- no_trade: D1 host guard, magic slot guard, parameter guard, spread caps.
- trade_entry: D1 completed-bar Brent-minus-WTI return-shock z-score fade.
- trade_management: orphan-leg cleanup, return-shock normalization exit,
  max-hold stale exit, Friday close.
- trade_close: hard ATR stop plus deterministic package exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-01 | initial structural Brent/WTI return-shock fade card | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12860_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `cecc9658-8bee-464b-a2a7-fe9a50a2c712` |
