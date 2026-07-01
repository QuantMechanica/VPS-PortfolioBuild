---
ea_id: QM5_12859
slug: brent-52w-anchor
type: strategy
strategy_id: BIANCHI-COMM-52W-2016_BRENT_S03
source_id: BIANCHI-COMM-52W-2016
source_citation: "Bianchi, R. J., Drew, M. E. and Fan, J. H. Commodities momentum: A behavioural perspective. Journal of Banking and Finance, 2016. DOI https://doi.org/10.1016/j.jbankfin.2016.06.010; SSRN https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2571725."
source_citations:
  - "Bianchi, R. J., Drew, M. E. and Fan, J. H. Commodities momentum: A behavioural perspective. Journal of Banking and Finance, 2016."
sources:
  - "[[sources/BIANCHI-COMM-52W-2016]]"
concepts:
  - "[[concepts/commodity-momentum]]"
  - "[[concepts/52-week-high-anchor]]"
indicators:
  - "[[indicators/rolling-high-low]]"
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [n-period-max-continuation, anchor-momentum, atr-hard-stop, signal-reversal-exit, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XBRUSD.DWX]
primary_target_symbols: [XBRUSD.DWX]
markets: [XBRUSD.DWX]
timeframes: [D1]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly Brent 52-week high/low anchor package; estimate 4-10 entries/year when the anchor and 63-D1 confirmation agree."
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
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "R1 PASS peer-reviewed commodity-momentum source; R2 PASS deterministic monthly 252-D1 anchor plus 63-D1 confirmation entry and time exit; R3 PASS XBRUSD.DWX has active local Brent routes through prior Brent builds and Q02 validates current history sufficiency; R4 PASS no ML/grid/martingale/external data."
---

# Brent 52-Week Anchor Momentum

## Source

- Source: [[sources/BIANCHI-COMM-52W-2016]]
- Primary citation: Bianchi, R. J., Drew, M. E. and Fan, J. H.,
  "Commodities momentum: A behavioural perspective", Journal of Banking and
  Finance, 2016, DOI https://doi.org/10.1016/j.jbankfin.2016.06.010.

## Concept

Commodity momentum can be expressed through a 52-week high anchor instead of a
plain trailing-return sign. This card ports that structural premise to the
Brent CFD proxy `XBRUSD.DWX`: once per month, go long only when Brent is near
its own 252-D1 closing high and recent 63-D1 return confirms; go short only
when Brent is near its own 252-D1 closing low and recent 63-D1 return confirms.

This is deliberately different from:

- `QM5_12849_brent-tsmom12m`: this is a 52-week high/low anchor rule with
  63-D1 confirmation, not a raw 12-month return-sign rule.
- `QM5_12841_brent-thu-prem`, `QM5_12853_brent-may-prem`,
  `QM5_12854_brent-dec-fade`, `QM5_12855_brent-nov-fade`, and
  `QM5_12856_brent-mon-fade`: no fixed weekday or month-only calendar entry.
- `QM5_12843_wti-brent-spread` and `QM5_12848_wti-brent-brk`: not a WTI/Brent
  basket.
- `QM5_12780_wti-52w-anchor` and WTI event/calendar/seasonality sleeves:
  this trades the Brent benchmark proxy, not XTIUSD WTI.
- `QM5_12804_xng-tsmom12m-atr`, `QM5_12807_xng-52w-anchor`, and
  `QM5_12567_cum-rsi2-commodity`: not natural gas and no RSI or oscillator
  pullback logic.
- XAU/XAG baskets, gas-metal baskets, and index sleeves: this is pure energy
  exposure, not metal or equity-index exposure.

## Hypothesis

Brent continuation should be stronger when price is anchored near its own
52-week closing high or low and a shorter 63-D1 return confirms the same
direction.

## Rules

Use a monthly closed-D1 rule: long near a 252-D1 closing high with 63-D1
positive confirmation, short near a 252-D1 closing low with 63-D1 negative
confirmation, and flatten on monthly rebalance or max hold.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and a single `XBRUSD.DWX`
D1 backtest setfile. Live risk is intentionally not configured here; any future
live allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, or the portfolio gate.

## Markets And Timeframe

- Symbol: `XBRUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 4-10 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 closes, broker calendar, spread, and ATR only.
  No futures curve, inventory feed, EIA feed, CFTC data, CSV, API, analyst
  forecast, or ML model.

`XBRUSD.DWX` is queued only for Q02 validation. The local registry already has
Brent routes through prior `XBRUSD.DWX` builds, but current history sufficiency
remains a Q02 responsibility.

## Entry Rules

- Evaluate only on a new D1 bar.
- Entry is allowed only on the first D1 bar of a new broker-calendar month.
- Build a 252-bar anchor window from completed D1 closes.
- Let `close_recent` be the prior completed D1 close.
- Let `high_252` and `low_252` be the maximum and minimum close in that anchor
  window.
- Let `confirm_return = ln(close_recent / close_63_bars_ago)`.
- Long package: BUY `XBRUSD.DWX` if `close_recent / high_252 >=
  strategy_anchor_long_min` and `confirm_return >=
  strategy_confirm_min_return_pct / 100`.
- Short package: SELL `XBRUSD.DWX` if `close_recent / low_252 <=
  strategy_anchor_short_max` and `confirm_return <=
  -strategy_confirm_min_return_pct / 100`.
- No entry if an open `XBRUSD.DWX` position already exists for this EA magic.
- No entry if `XBRUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit any open package on the next monthly rebalance bar before considering a
  fresh package for that month.
- Exit any stale package after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XBRUSD.DWX` on D1.
- Skip entries when D1 history is shorter than the 252-D1 anchor plus warmup.
- Skip entries when ATR is unavailable.
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

- name: strategy_anchor_lookback_d1
  default: 252
  sweep_range: [189, 252, 315]
- name: strategy_confirm_lookback_d1
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_anchor_long_min
  default: 0.94
  sweep_range: [0.92, 0.94, 0.96]
- name: strategy_anchor_short_max
  default: 1.08
  sweep_range: [1.05, 1.08, 1.12]
- name: strategy_confirm_min_return_pct
  default: 2.0
  sweep_range: [1.0, 2.0, 3.0]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.25
  sweep_range: [2.5, 3.25, 4.0]
- name: strategy_max_hold_days
  default: 31
  sweep_range: [21, 31, 45]
- name: strategy_max_spread_points
  default: 1200
  sweep_range: [800, 1200, 1800]

## R1-R4 Bewertung

| Rule | Verdict | Rationale |
|---|---|---|
| R1 reputable source | PASS | Peer-reviewed commodity-momentum paper with public DOI and SSRN preprint pointer. |
| R2 mechanical | PASS | Monthly D1 anchor/confirmation, ATR stop, and time exit are fully specified. |
| R3 data available | PASS | `XBRUSD.DWX` has active local Brent routes through prior builds; Q02 validates current history sufficiency. |
| R4 ML forbidden | PASS | No ML, adaptive fitting, grid, martingale, external feed, or discretionary override. |

## Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "XBRUSD.DWX D1 only, valid lookbacks, spread cap, framework news, kill-switch, and Friday close."
  trade_entry:
    used: true
    notes: "Monthly 252-D1 anchor plus 63-D1 confirmation."
  trade_management:
    used: true
    notes: "Monthly rebalance and max-hold stale-position guard."
  trade_close:
    used: true
    notes: "ATR hard stop plus deterministic time exit."
hard_rules_at_risk:
  - symbol_history_sufficiency
  - friday_close
  - magic_schema
  - risk_mode_dual
target_modules:
  - Strategy_NoTradeFilter
  - Strategy_EntrySignal
  - Strategy_ManageOpenPosition
  - Strategy_ExitSignal
  - Strategy_NewsFilterHook
```

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-01 | initial Brent 52-week-anchor build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12859_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | pending work item recorded in build result |
