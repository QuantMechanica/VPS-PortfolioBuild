---
ea_id: QM5_13048
slug: wti-roll-squeeze
type: strategy
strategy_id: CFTC-ETF-ROLL-WTI-SQUEEZE-2026
source_id: CFTC-ETF-ROLL-WTI-2014
source_citation: "Mou, Y. Predatory or Sunshine Trading? Evidence from Crude Oil ETF Rolls. CFTC Office of the Chief Economist. URL https://www.cftc.gov/sites/default/files/idc/groups/public/@economicanalysis/documents/file/oce_predatorysunshine0314.pdf"
source_citations:
  - type: official_government_research_paper
    citation: "Mou, Y. Predatory or Sunshine Trading? Evidence from Crude Oil ETF Rolls. CFTC Office of the Chief Economist."
    location: "https://www.cftc.gov/sites/default/files/idc/groups/public/@economicanalysis/documents/file/oce_predatorysunshine0314.pdf"
    quality_tier: A
    role: primary
sources:
  - "[[sources/CFTC-ETF-ROLL-WTI-2014]]"
concepts:
  - "[[concepts/commodity-etf-roll-pressure]]"
  - "[[concepts/roll-window-volatility-compression]]"
  - "[[concepts/wti-structural-flow-breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [calendar-flow, roll-window, compression-breakout, atr-hard-stop, atr-profit-target, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13048_XTI_ROLL_SQUEEZE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Early-month WTI ETF-roll compression breakout; estimate 4-9 entries/year after roll-window, compression, breakout, spread, and one-entry-per-month filters."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-08
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [roll_window_sample_size, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed structural commodity sleeve 2026-07-08: R1 PASS official CFTC research paper on predictable crude-oil ETF rolls; R2 PASS deterministic broker-calendar roll window, pre-signal D1 compression, closed-bar channel breakout, ATR stop/target, SMA/window/time exits; R3 PASS XTIUSD.DWX exists in the DWX symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate versus QM5_12736 and QM5_12759 because this waits for volatility compression and a closed-bar breakout inside the roll window rather than shorting downside pressure or buying post-pressure relief."
---

# WTI ETF Roll-Window Squeeze Breakout

## Source

- Source packet: `strategy-seeds/sources/CFTC-ETF-ROLL-WTI-2014/source.md`.
- Primary citation: Mou, Y., "Predatory or Sunshine Trading? Evidence from
  Crude Oil ETF Rolls", CFTC Office of the Chief Economist, URL
  https://www.cftc.gov/sites/default/files/idc/groups/public/@economicanalysis/documents/file/oce_predatorysunshine0314.pdf.

## Hypothesis

The CFTC source studies predictable crude-oil ETF roll trading and associated
front-month futures market effects. This card does not read ETF holdings,
futures curves, CFTC files, COT data, APIs, CSV files, or analyst calendars at
runtime. It uses the fixed early-month roll-pressure window as a structural
flow clock and asks whether low D1 range compression immediately before that
window resolves into a tradable WTI breakout.

The portfolio role is a direct WTI sleeve with a different driver from index,
gold, silver, natural gas, metals ratio, generic commodity RSI, WPSR, OPEC,
IEA, STEO, COT, production, refinery, hurricane, weekday, month, carry, and
post-roll relief logic.

## Concept

On each new `XTIUSD.DWX` D1 bar, the EA inspects the prior completed D1 bar.
If that prior bar is inside the early-month ETF roll window, and the bars
before it were compressed, a close outside the pre-signal channel opens a
single breakout position in the direction of the close. The signal is
symmetric because the CFTC source supplies the event clock, while the Darwinex
price series determines whether the roll-window resolution is down or up.

This is deliberately different from:

- `QM5_12736_wti-roll-fade`: that EA shorts early-month downside pressure after
  a negative return and SMA confirmation. This card requires pre-signal
  compression and a channel breakout; it can trade either direction.
- `QM5_12759_wti-roll-relief`: that EA buys post-window relief after observed
  early pressure. This card trades the roll-window breakout itself.
- `QM5_12600_cme-wti-exp-brk` and `QM5_12839_wti-exp-fade`: CME futures-expiry
  window cards, not early-month ETF-roll compression.
- WTI WPSR, DPR, PSM, STEO, OMR, MOMR, COT, rig, production, imports/exports,
  refinery, Cushing, SPR, hurricane, weekday, weekend, month, roll-fade,
  post-roll, carry, 52-week, TSMOM, Williams, Psaradellis, XTI/XNG, oil/metal,
  oil-FX, XNG, XAU/XAG, and generic RSI sleeves: different source clock and
  signal definition.

## rules

Use the early-month CFTC ETF-roll window as a fixed broker-calendar clock. Only
trade after pre-signal D1 compression resolves through a completed-bar channel
break, then manage with ATR stop/target, SMA failure, exit-window,
month-change, max-hold, standard news handling, and Friday close.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected frequency: approximately 4-9 trades/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker calendar, and
  V5 framework state only.

## 4. entry rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Host chart must be `XTIUSD.DWX` on D1 and magic slot 0.
- The prior completed D1 bar must be inside trading day
  `strategy_roll_start_trading_day` through
  `strategy_roll_end_trading_day` of the broker-calendar month.
- Build a pre-signal channel from the `strategy_compression_lookback` D1 bars
  before the signal bar.
- Require that channel width to be no more than
  `strategy_max_compression_atr * ATR * sqrt(strategy_compression_lookback)`.
- Require the signal bar range and body filters to reject tiny bars.
- Long entry: prior completed D1 close is above the pre-signal channel high by
  at least `strategy_min_break_atr * ATR`, and the close is in the upper
  `strategy_long_min_close_location` fraction of the signal bar.
- Short entry: prior completed D1 close is below the pre-signal channel low by
  at least `strategy_min_break_atr * ATR`, and the close is in the lower
  `strategy_short_max_close_location` fraction of the signal bar.
- No more than one entry per broker-calendar month.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## 5. exit rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: fixed TP at ATR(`strategy_atr_period`) *
  `strategy_atr_tp_mult`.
- Close when current trading day-of-month is greater than
  `strategy_exit_last_trading_day`.
- Close if the broker-calendar month changes after entry.
- Close a long if the prior completed D1 close falls below
  SMA(`strategy_exit_sma_period`).
- Close a short if the prior completed D1 close rises above
  SMA(`strategy_exit_sma_period`).
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## 6. filters (no-trade module)

- Only `XTIUSD.DWX` D1 is valid.
- Magic slot offset must be 0.
- Invalid parameters fail closed.
- Skip entries when D1 history, ATR, SMA, channel, signal OHLC, spread, entry
  price, or stop/target price is unavailable.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## 7. trade management rules

- Symmetric long/short single-symbol breakout.
- One open position per magic/symbol.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- Backtest setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Parameters To Test

- name: strategy_roll_start_trading_day
  default: 5
  sweep_range: [4, 5, 6]
- name: strategy_roll_end_trading_day
  default: 9
  sweep_range: [8, 9, 10]
- name: strategy_exit_last_trading_day
  default: 12
  sweep_range: [10, 12, 14]
- name: strategy_compression_lookback
  default: 8
  sweep_range: [6, 8, 12]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_max_compression_atr
  default: 1.05
  sweep_range: [0.80, 1.05, 1.35]
- name: strategy_min_signal_range_atr
  default: 0.45
  sweep_range: [0.30, 0.45, 0.70]
- name: strategy_min_body_ratio
  default: 0.25
  sweep_range: [0.15, 0.25, 0.40]
- name: strategy_min_break_atr
  default: 0.05
  sweep_range: [0.00, 0.05, 0.15]
- name: strategy_long_min_close_location
  default: 0.62
  sweep_range: [0.55, 0.62, 0.72]
- name: strategy_short_max_close_location
  default: 0.38
  sweep_range: [0.28, 0.38, 0.45]
- name: strategy_exit_sma_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.25, 2.75, 3.50]
- name: strategy_atr_tp_mult
  default: 3.25
  sweep_range: [2.50, 3.25, 4.50]
- name: strategy_max_hold_days
  default: 6
  sweep_range: [4, 6, 9]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The CFTC source is used only as structural lineage for predictable crude-oil
ETF roll activity and the early-month roll clock. This card imports no CFTC
performance claim. Q02 and later phases must validate or reject the mechanical
`XTIUSD.DWX` realization on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 4-9 entries/year.
- risk_class: medium-high because WTI roll-window moves can gap and fail.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official CFTC Office of the Chief Economist paper.
- [x] R2 mechanical: fixed roll-window calendar, pre-signal compression,
  closed-bar channel breakout, ATR stop/target, SMA/window/time exits.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: roll-window compression breakout, not roll pressure short,
  post-roll relief long, CME expiry, WPSR/EIA/OPEC/IEA/COT/refinery/hurricane,
  WTI calendar premia, WTI trend/carry, XTI/XNG, oil/metal, XNG, XAU/XAG, or
  commodity RSI logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard,
  spread cap, roll-window gate, and valid data checks.
- trade_entry: early-month CFTC ETF-roll-window compression breakout.
- trade_management: exit-window, month-change, SMA failure, and max-hold exits.
- trade_close: hard ATR stop, ATR target, deterministic time/window exits, and
  framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-08 | initial WTI ETF-roll compression breakout build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-08 | APPROVED | this card |
| Q01 Build Validation | 2026-07-08 | PENDING | `artifacts/qm5_13048_build_result.json` |
| Q02 Baseline Screening | 2026-07-08 | PENDING | `artifacts/qm5_13048_q02_enqueue_20260708.json` |
