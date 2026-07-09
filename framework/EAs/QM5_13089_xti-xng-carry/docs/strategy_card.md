---
ea_id: QM5_13089
slug: xti-xng-carry
type: strategy
strategy_id: KOIJEN-CARRY-2018_XTI_XNG_S03
source_id: KOIJEN-CARRY-2018
source_citation: "Koijen, R. S. J., Moskowitz, T. J., Pedersen, L. H. and Vrugt, E. B. (2018). Carry. Journal of Financial Economics, 127(2), 197-225. DOI https://doi.org/10.1016/j.jfineco.2017.11.002; NBER working paper https://www.nber.org/papers/w19325."
source_citations:
  - "Koijen, R. S. J., Moskowitz, T. J., Pedersen, L. H. and Vrugt, E. B. (2018). Carry. Journal of Financial Economics, 127(2), 197-225."
sources:
  - "[[sources/KOIJEN-CARRY-2018]]"
concepts:
  - "[[concepts/carry]]"
  - "[[concepts/energy-relative-carry]]"
indicators:
  - "[[indicators/broker-swap]]"
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [market-neutral-basket, carry-ranking, energy-relative-value, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
markets: [commodities, energy]
timeframes: [D1]
logical_symbol: QM5_13089_XTI_XNG_CARRY_D1
single_symbol_only: false
period: D1
expected_trade_frequency: "Weekly XTI/XNG carry-spread package; estimate 30-52 paired entries/year after weekday, spread, carry, adverse-drift, and framework filters."
expected_trades_per_year_per_symbol: 42
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
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "R1 PASS peer-reviewed carry source; R2 PASS deterministic cross-energy broker-swap carry ranking, 12M adverse-return guard, weekly D1 rebalance, ATR hard stops, time exit, and carry-rank flip exit; R3 PASS XTIUSD.DWX and XNGUSD.DWX available in the V5/DWX universe; R4 PASS no ML/grid/martingale/external runtime data."
---

# XTI/XNG D1 Carry Spread

## Source

- Source: [[sources/KOIJEN-CARRY-2018]]
- Primary citation: Koijen, Ralph S. J., Tobias J. Moskowitz, Lasse Heje
  Pedersen, and Evert B. Vrugt, "Carry", Journal of Financial Economics,
  127(2), 2018, pp. 197-225. DOI
  https://doi.org/10.1016/j.jfineco.2017.11.002.

## Concept

Koijen, Moskowitz, Pedersen, and Vrugt define carry as an ex-ante return
component observable before price movement and document its return-predictive
role across asset classes, including commodities. This card ports the idea to
a D1 Darwinex energy relative-value basket by ranking the broker swap carry
edge of WTI versus natural gas:

`carry_edge = SYMBOL_SWAP_LONG - SYMBOL_SWAP_SHORT`

When WTI has the better carry edge, the basket buys `XTIUSD.DWX` and sells
`XNGUSD.DWX`. When natural gas has the better carry edge, it sells WTI and buys
natural gas. If all `.DWX` tester swap fields are exactly zero, the configured
fallback opens long WTI / short natural gas so Q02 tests a deterministic
structural package instead of a zero-trade harness artifact. A 12-month return
guard is risk control only: it blocks long legs after severe negative drift and
short legs after severe positive drift.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, cumulative oscillator, or pullback.
- `QM5_12840_xti-xng-rspread`: no D1 return-spread z-score mean reversion.
- `QM5_12850_xti-xng-vcb`: no volatility-compression breakout.
- `QM5_12813_eia-energy-switch`: no fixed seasonal ownership window.
- `QM5_12893_xng-12m-carry` and `QM5_12913_xti-12m-carry`: this is a
  market-neutral two-leg cross-energy ranking, not a single-symbol carry bet.
- WTI/XNG event, inventory, expiry, rig-count, weather, and roll sleeves:
  no external event feed or date-window timing is used.
- XAU/XAG and other metal baskets: this adds energy relative carry exposure,
  not another metals sleeve.

## Markets And Timeframe

- Logical symbol: `QM5_13089_XTI_XNG_CARRY_D1`.
- Host symbol: `XTIUSD.DWX`.
- Basket legs: `XTIUSD.DWX` and `XNGUSD.DWX`.
- Period: `D1`.
- Expected package frequency: approximately 30-52 paired packages/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 broker swap fields, D1 closes, spread, and ATR
  only. No futures curve, inventory feed, EIA feed, CFTC data, CSV, API,
  analyst forecast, adaptive PnL fitting, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar of the `XTIUSD.DWX` host chart.
- Entry is allowed only on the configured broker weekday
  `strategy_rebalance_weekday` (default Monday).
- Compute `carry_edge` for WTI and natural gas from broker swap fields.
- If `XTI_edge - XNG_edge > strategy_min_pair_swap_edge`, open long
  `XTIUSD.DWX` and short `XNGUSD.DWX`.
- If `XNG_edge - XTI_edge > strategy_min_pair_swap_edge`, open short
  `XTIUSD.DWX` and long `XNGUSD.DWX`.
- If all swap fields are exactly zero and tied, use
  `strategy_zero_swap_fallback_direction`; default `1` opens long WTI / short
  natural gas, `-1` reverses the package, and `0` disables the fallback.
- Compute each leg's 12-month D1 log return.
- Block intended long legs if their 12-month return is below
  `-strategy_max_adverse_return_pct`.
- Block intended short legs if their 12-month return is above
  `strategy_max_adverse_return_pct`.
- No entry when either leg exceeds its spread cap.
- No entry if any basket leg is already open for this EA magic.

## Exit Rules

- Exit both legs when the carry ranking flips to the opposite package.
- Exit both legs when calendar hold exceeds `strategy_max_hold_days`.
- Exit both legs on framework Friday close.
- If only one leg is open, close the orphaned package immediately.
- Each leg carries a hard ATR stop at
  `strategy_atr_sl_mult * ATR(strategy_atr_period_d1)`.

## Filters

- Only run from the `XTIUSD.DWX` D1 host chart with `qm_magic_slot_offset=0`.
- Require positive prices, valid swap fields or documented zero-swap fallback,
  valid D1 history, valid ATR, valid lot sizing, and allowed spreads for both
  legs.
- Framework kill-switch, symbol guard, magic resolver, entry-only news
  blackout, and Friday-close controls remain active.

## Trade Management Rules

- Market-neutral two-leg package.
- Symmetric long/short energy basket.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One package per EA magic.

## Parameters To Test

- name: strategy_rebalance_weekday
  default: 1
  sweep_range: [1]
- name: strategy_return_lookback_d1
  default: 252
  sweep_range: [189, 252, 315]
- name: strategy_max_adverse_return_pct
  default: 25.0
  sweep_range: [15.0, 25.0, 40.0]
- name: strategy_min_pair_swap_edge
  default: 0.0
  sweep_range: [0.0]
- name: strategy_zero_swap_fallback_direction
  default: 1
  sweep_range: [-1, 0, 1]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.5
  sweep_range: [2.5, 3.5, 5.0]
- name: strategy_max_hold_days
  default: 7
  sweep_range: [3, 5, 7, 10]
- name: strategy_xti_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_xng_max_spread_pts
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported into QM. The source is used for structural
lineage around carry as an ex-ante return component and broad cross-asset
return predictor; Q02+ must validate the deterministic Darwinex XTI/XNG basket
port.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 30-52 paired packages/year.
- risk_class: high for energy spread volatility and gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed Journal of Financial Economics carry
  paper with DOI and NBER working-paper lineage.
- [x] R2 mechanical: broker-swap carry ranking, 12M adverse-return guard,
  weekly D1 rebalance, ATR hard stops, time exit, and rank-flip exit.
- [x] R3 testable: `XTIUSD.DWX` and `XNGUSD.DWX` exist in the V5/DWX symbol
  universe and require only MT5 OHLC/swap/spread data.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  feed, or multiple packages per magic.
- [x] Non-duplicate: cross-energy carry ranking, not commodity RSI, XTI/XNG
  return-spread reversion, volatility breakout, seasonal switch, single-symbol
  carry, event/inventory/expiry/roll timing, or metal exposure.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "XTIUSD.DWX D1 host only, slot 0, valid lookback/ATR/spread/swap settings, valid zero-swap fallback, framework kill-switch, symbol guard, news, and Friday close."
  trade_entry:
    used: true
    notes: "Weekly D1 XTI-vs-XNG broker-swap carry ranking with documented zero-swap tester fallback and 12M adverse-return guard."
  trade_management:
    used: true
    notes: "Orphan leg cleanup, max-hold stale-package guard, and carry-rank flip exit."
  trade_close:
    used: true
    notes: "Per-leg ATR hard stop plus deterministic package close rules."
hard_rules_at_risk:
  - friday_close
  - magic_schema
  - risk_mode_dual
```

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-09 | initial XTI/XNG market-neutral carry basket build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
| Q01 Build Validation | 2026-07-09 | PASS | `artifacts/qm5_13089_build_result.json` |
| Q02 Baseline Screening | 2026-07-09 | QUEUED | `D:\\QM\\strategy_farm\\state\\farm_state.sqlite` work item `7461ca7a-c1fb-4007-b124-0ecaafa51993` |
