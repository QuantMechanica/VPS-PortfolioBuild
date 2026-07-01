---
ea_id: QM5_12857
slug: xbr-xng-vcb
type: strategy
strategy_id: BOLLINGER-BB-SQUEEZE-2001_XBR_XNG_VCB
source_id: BOLLINGER-BB-SQUEEZE-2001
source_citation: "Bollinger, John. Bollinger on Bollinger Bands. McGraw-Hill, 2001. Local source packet strategy-seeds/sources/BOLLINGER-BB-SQUEEZE-2001/."
source_citations:
  - type: book
    citation: "Bollinger, John. Bollinger on Bollinger Bands. McGraw-Hill, 2001."
    location: "BandWidth and volatility-contraction breakout lineage."
    quality_tier: A
    role: primary
sources:
  - "[[sources/BOLLINGER-BB-SQUEEZE-2001]]"
concepts:
  - "[[concepts/volatility-contraction-breakout]]"
  - "[[concepts/energy-relative-value]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/atr]]"
strategy_type_flags: [market-neutral-basket, volatility-contraction-breakout, ratio-breakout, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XBRUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XBRUSD.DWX, XNGUSD.DWX]
markets: [XBRUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_12857_XBR_XNG_VCB_D1
single_symbol_only: false
period: D1
expected_trade_frequency: "D1 XBR/XNG log-ratio Bollinger BandWidth compression breakout; estimate 6-14 paired packages/year after squeeze, spread, slope, max-hold, and ATR filters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
expected_pf: 1.10
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, basket_leg_atomicity]
g0_approval_reasoning: "R1 PASS reputable Bollinger BandWidth/squeeze source packet; R2 PASS deterministic D1 XBR/XNG log-ratio BandWidth percentile, Bollinger-envelope breakout, slope gate, ATR stops, mean-band exit, and max-hold exit; R3 PASS XNGUSD.DWX in DWX matrix and XBRUSD.DWX routed by prior Brent builds, with Q02 validating current XBR history sufficiency; R4 PASS no ML/grid/martingale/external runtime data."
---

# XBR/XNG Ratio Volatility-Contraction Breakout

## Source

- Source: [[sources/BOLLINGER-BB-SQUEEZE-2001]]
- Primary citation: Bollinger, John. *Bollinger on Bollinger Bands*.
  McGraw-Hill, 2001.

## Concept

This card applies Bollinger BandWidth compression to the daily log ratio between
Brent CFD proxy `XBRUSD.DWX` and natural-gas CFD proxy `XNGUSD.DWX`. When the
ratio has compressed relative to its own recent BandWidth history, a completed
D1 close outside the Bollinger envelope opens a market-neutral energy basket:
long the ratio by buying Brent and selling gas, or short the ratio by selling
Brent and buying gas.

The goal is an energy-relative volatility-expansion sleeve that is not another
outright XNG pullback, index, or metal exposure.

This is deliberately different from:

- `QM5_12578_eia-oilgas-ratio`: fades an XTI/XNG price-level log-ratio
  z-score; this card follows a post-compression envelope breakout on XBR/XNG.
- `QM5_12608_eia-oilgas-breakout`: trades a raw XTI/XNG log-ratio channel
  break; this card requires low Bollinger BandWidth rank first and exits on
  Bollinger middle-band failure.
- `QM5_12733_xti-xng-xmom`: monthly XTI/XNG relative momentum; this card uses
  D1 BandWidth compression and envelope breakout on Brent/gas.
- `QM5_12813_eia-energy-switch`: fixed seasonal windows; this card has no
  calendar season direction.
- `QM5_12840_xti-xng-rspread`: XTI/XNG return-spread mean reversion; this card
  trades XBR/XNG price-ratio volatility expansion.
- `QM5_12811_xti-vcb` and `QM5_12849_brent-tsmom12m`: single-symbol crude
  sleeves; this card is a two-leg XBR/XNG basket and the signal variable is the
  log ratio.
- `QM5_12843_wti-brent-spread` and `QM5_12848_wti-brent-brk`: crude benchmark
  spread sleeves; this card pairs Brent against natural gas instead of WTI.
- `QM5_12567_cum-rsi2-commodity`: no RSI or short-horizon oscillator pullback.
- XAU/XAG, oil/gold, oil/silver, gas/gold, and gas/silver baskets: this is an
  energy-only relative-value sleeve.

## Markets And Timeframe

- Logical symbol: `QM5_12857_XBR_XNG_VCB_D1`.
- Host symbol: `XBRUSD.DWX`.
- Basket legs: `XBRUSD.DWX` and `XNGUSD.DWX`.
- Period: `D1`.
- Expected package frequency: about 6-14 paired packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, ATR, broker calendar, and V5
  framework state only. No futures curve, EIA feed, volume, open interest, CSV,
  API, analyst forecast, alternative data, or ML model.

`XBRUSD.DWX` is queued only through the paced Q02 path. Prior Brent builds use
the symbol route, but current XBR/gas synchronized history sufficiency must be
validated by the farm.

## Entry Rules

- Evaluate only on a new D1 bar of the `XBRUSD.DWX` host chart.
- Copy completed D1 closes for `XBRUSD.DWX` and `XNGUSD.DWX`.
- Compute `ratio_spread = ln(XBRUSD close) - beta * ln(XNGUSD close)`.
- Compute Bollinger middle and standard deviation from the prior
  `strategy_bb_period` completed ratio-spread observations, excluding the
  current signal observation.
- Compute BandWidth as `(upper - lower) / abs(middle)`.
- Rank the current BandWidth against the prior
  `strategy_bandwidth_lookback_d1` BandWidth observations.
- Require BandWidth rank at or below `strategy_bandwidth_rank_max`.
- If `strategy_require_slope` is true, require the ratio middle-band slope to
  agree with the breakout direction.
- Long ratio package: if the current ratio spread closes above
  `upper + strategy_break_buffer_sd * sd`, buy `XBRUSD.DWX` and sell
  `XNGUSD.DWX`.
- Short ratio package: if the current ratio spread closes below
  `lower - strategy_break_buffer_sd * sd`, sell `XBRUSD.DWX` and buy
  `XNGUSD.DWX`.
- No entry when either leg exceeds its spread cap.
- No entry if any basket leg is already open for this EA magic.

## Exit Rules

- Exit both legs when the current ratio spread crosses back through the
  Bollinger middle band against the package direction.
- Exit both legs when calendar hold exceeds `strategy_max_hold_days`.
- Exit both legs on framework Friday close.
- If only one leg is open, close the orphaned package immediately.
- Each leg carries a hard ATR stop at
  `strategy_atr_sl_mult * ATR(strategy_atr_period_d1)`.

## Filters

- Only run from `XBRUSD.DWX` D1 with `qm_magic_slot_offset=0`.
- Require positive prices, valid ratio-spread standard deviation, valid
  BandWidth rank, valid ATR, valid lot sizing, and allowed spreads for both
  legs.
- Framework kill-switch, symbol guard, magic resolver, news, and Friday-close
  controls remain active.

## Trade Management Rules

- Market-neutral two-leg package.
- Symmetric long/short ratio.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One package per EA magic.

## Parameters To Test

- name: strategy_bb_period
  default: 20
  sweep_range: [18, 20, 24, 30]
- name: strategy_bb_deviation
  default: 2.0
  sweep_range: [1.8, 2.0, 2.2]
- name: strategy_bandwidth_lookback_d1
  default: 126
  sweep_range: [84, 126, 189]
- name: strategy_bandwidth_rank_max
  default: 0.20
  sweep_range: [0.15, 0.20, 0.25]
- name: strategy_break_buffer_sd
  default: 0.10
  sweep_range: [0.05, 0.10, 0.20]
- name: strategy_slope_shift
  default: 10
  sweep_range: [5, 10, 20]
- name: strategy_require_slope
  default: true
  sweep_range: [true]
- name: strategy_beta
  default: 1.0
  sweep_range: [0.75, 1.0, 1.25]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 20
  sweep_range: [15, 20, 30]

## Author Claims

The source is used only for structural lineage around BandWidth compression and
volatility expansion. No source performance number is imported into QM. Q02 and
later phases must validate or reject the `XBRUSD.DWX` / `XNGUSD.DWX` basket on
Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 6-14 paired packages/year.
- risk_class: medium-high for energy-ratio gap and leg-basis risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: published Bollinger BandWidth/squeeze source packet.
- [x] R2 mechanical: fixed D1 ratio BandWidth rank, fixed Bollinger breakout,
  fixed slope gate, spread caps, max-hold exit, and ATR hard stops.
- [x] R3 testable: `XNGUSD.DWX` exists in the DWX symbol matrix and
  `XBRUSD.DWX` is already routed by prior Brent builds; Q02 must validate
  synchronized XBR/gas history sufficiency.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and no pyramiding.
- [x] Non-duplicate: this is XBR/XNG post-compression ratio breakout, not
  XTI/XNG price-ratio z-score reversion, raw channel breakout, return-spread
  reversion, relative momentum, fixed seasonal switch, single-symbol crude
  trend/calendar/squeeze, WTI/Brent spread, XNG RSI, or a metal/index sleeve.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: host/timeframe guard, magic-slot guard, parameter guard, spread
  caps, ratio data sufficiency, and valid lot/ATR checks.
- trade_entry: D1 XBR/XNG log-ratio Bollinger BandWidth compression breakout.
- trade_management: middle-band failure exit, max-hold stale-package exit,
  orphan leg cleanup, and Friday close.
- trade_close: hard ATR stop plus deterministic package close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-01 | initial XBR/XNG ratio volatility-contraction breakout build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12857_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `189ba50a-caf0-4402-acde-623a4d2d7ff3` |
