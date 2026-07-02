---
ea_id: QM5_12913
slug: xti-12m-carry
type: strategy
strategy_id: KOIJEN_CARRY_2018_XTI_S02
source_id: KOIJEN-CARRY-2018
source_citation: "Koijen, R. S. J., Moskowitz, T. J., Pedersen, L. H. and Vrugt, E. B. (2018). Carry. Journal of Financial Economics, 127(2), 197-225. DOI https://doi.org/10.1016/j.jfineco.2017.11.002; NBER working paper https://www.nber.org/papers/w19325."
source_citations:
  - "Koijen, R. S. J., Moskowitz, T. J., Pedersen, L. H. and Vrugt, E. B. (2018). Carry. Journal of Financial Economics, 127(2), 197-225."
sources:
  - "[[sources/KOIJEN-CARRY-2018]]"
concepts:
  - "[[concepts/carry]]"
  - "[[concepts/WTI-cfd-carry]]"
indicators:
  - "[[indicators/broker-swap]]"
  - "[[indicators/structural-zero-swap-fallback]]"
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [carry-direction, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy]
timeframes: [D1]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly WTI carry package; estimate 35-52 entries/year after spread, swap, trend, and framework filters."
expected_trades_per_year_per_symbol: 42
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
expected_pf: 1.10
expected_dd_pct: 20.0
risk_class: high
ml_required: false
g0_approval_reasoning: "R1 PASS peer-reviewed carry source; R2 PASS deterministic broker-swap carry side, 12M adverse-trend guard, weekly D1 rebalance, ATR stop, and time exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# XTI 12M Carry

## Source

- Source: [[sources/KOIJEN-CARRY-2018]]
- Primary citation: Koijen, Ralph S. J., Tobias J. Moskowitz, Lasse Heje
  Pedersen, and Evert B. Vrugt, "Carry", Journal of Financial Economics,
  127(2), 2018, pp. 197-225. DOI
  https://doi.org/10.1016/j.jfineco.2017.11.002.

## Concept

Koijen, Moskowitz, Pedersen, and Vrugt define carry as an ex-ante return
component observable before price movement and show that carry predicts returns
across asset classes, including commodities. This card ports the concept to the
Darwinex WTI CFD by using the broker's long-vs-short swap values as the
observable carry side when available. Because `.DWX` tester symbols can expose
both swap fields as zero, the backtest-safe tie case uses a fixed structural
short-carry fallback (`strategy_zero_swap_fallback_direction = -1`) so Q02
tests a deterministic WTI carry sleeve instead of a zero-trade harness artifact.
A 12-month price-return guard is used only to avoid holding carry against an
extreme adverse drift.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, cumulative oscillator, or short-term
  pullback trigger.
- `QM5_12603_wti-tsmom12m` and `QM5_12616_tsmom-9m-commodity-xtiusd`:
  direction comes from broker swap carry, not the sign of the 9- or 12-month
  price return.
- `QM5_12780_wti-52w-anchor`: no 52-week high/low anchor trigger.
- WTI WPSR, hurricane, OPEC, expiry, refinery, roll, weekday, and month
  seasonality sleeves: no inventory-event, weather, calendar-event, or
  date-window timing is used.
- XTI/XNG, WTI/Brent, oil/gold, and oil/silver relative-value sleeves: this is
  a single-symbol WTI carry package, not a basket or spread.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 35-52 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 broker swap fields, D1 closes, spread, and ATR
  only. No futures curve, inventory feed, EIA feed, CFTC data, CSV, API, analyst
  forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Entry is allowed only on the configured broker weekday
  `strategy_rebalance_weekday` (default Monday).
- Compute broker carry direction:
  - Long side if `SYMBOL_SWAP_LONG - SYMBOL_SWAP_SHORT >
    strategy_min_swap_advantage`.
  - Short side if `SYMBOL_SWAP_SHORT - SYMBOL_SWAP_LONG >
    strategy_min_swap_advantage`.
  - If both swap fields are exactly zero and tied, use
    `strategy_zero_swap_fallback_direction` (default `-1`, structural short
    carry) so `.DWX` backtests remain trade-generating.
  - Otherwise no trade.
- Compute `return_12m = ln(close[1] / close[1 + strategy_return_lookback_d1])`.
- Block long carry if `return_12m` is below
  `-strategy_max_adverse_return_pct`.
- Block short carry if `return_12m` is above
  `strategy_max_adverse_return_pct`.
- Enter the carry side at market if no open `XTIUSD.DWX` position already
  exists for this EA magic.
- Skip entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close if the package has been held for at least `strategy_max_hold_days`
  calendar days.
- Close if the broker swap comparison flips to the opposite carry side.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- Skip entries when 12-month D1 history, swap, spread, or ATR values are
  unavailable.
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

- name: strategy_rebalance_weekday
  default: 1
  sweep_range: [1]
- name: strategy_return_lookback_d1
  default: 252
  sweep_range: [189, 252, 315]
- name: strategy_max_adverse_return_pct
  default: 25.0
  sweep_range: [15.0, 25.0, 40.0]
- name: strategy_min_swap_advantage
  default: 0.0
  sweep_range: [0.0]
- name: strategy_zero_swap_fallback_direction
  default: -1
  sweep_range: [-1, 0, 1]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.5
  sweep_range: [2.5, 3.5, 5.0]
- name: strategy_max_hold_days
  default: 5
  sweep_range: [3, 5, 7]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported into QM. The source is used for structural
lineage around carry as an ex-ante return component and broad cross-asset return
predictor; Q02+ must validate the deterministic Darwinex `XTIUSD.DWX` port.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 20
- expected_trade_frequency: approximately 35-52 entries/year.
- risk_class: high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed Journal of Financial Economics carry
  paper with DOI and NBER working-paper lineage.
- [x] R2 mechanical: broker-swap carry side, 12M adverse-trend guard, weekly
  rebalance, ATR stop, and deterministic exits.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  feed, or multiple positions per magic.
- [x] Non-duplicate: not commodity RSI/pullback, WTI time-series momentum,
  52-week anchor, WTI inventory/weather/calendar/roll/refinery/event logic, or
  commodity relative-value spread logic.

## Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "XTIUSD.DWX D1 only, slot 0, valid lookbacks, swap validity or zero-swap fallback, spread cap, framework news, kill-switch, and Friday close."
  trade_entry:
    used: true
    notes: "Weekly D1 broker-swap carry direction with deterministic structural short fallback for zero-swap tester ties and 12M adverse-trend guard."
  trade_management:
    used: true
    notes: "Max-hold stale-position guard and carry-side flip exit."
  trade_close:
    used: true
    notes: "ATR hard stop plus deterministic time/side-flip exits."
hard_rules_at_risk:
  - friday_close
  - enhancement_doctrine
```

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-02 | initial structural XTI carry build | Q02 | IN_PROGRESS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
| Q02 Baseline Screening | 2026-07-02 | ENQUEUED | D:/QM/strategy_farm |

