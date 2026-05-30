# QM5_1247 fuertes-comm-tsmom

## Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1247_fuertes-comm-tsmom.md`
- Local copy: `docs/strategy_card.md`
- Status: APPROVED / G0

## Framework Mapping

- No-trade: framework kill-switch, news gate, Friday-close handling, D1-only guard, approved three-symbol universe, minimum 252 D1 bars, and local futures-curve CSV freshness gate.
- Entry: first tradable day of each month; compute parameterized momentum from DWX D1 closes, read local deterministic curve CSV, rank momentum plus term spread, go long the highest combined score only when both signs are positive, and short the lowest score only when both signs are negative.
- Trade management: hard initial stop at `3.0 * ATR(D1,20)` from entry; no averaging down and one position per symbol/magic.
- Close: monthly rebalance closes positions that no longer satisfy top/bottom rank and sign requirements, including stale or missing curve data.

## Curve CSV Contract

The EA reads a local MT5 `Files` CSV named by `strategy_curve_csv_path`, default `QM5_1247_comm_curve.csv`. No web/API calls are used. Format:

```text
root,month,near_contract_price,deferred_contract_price
XAU,202605,2380.50,2392.00
XAG,202605,31.20,31.45
XTI,202605,78.10,77.65
```

Rows may use roots `XAU`, `XAG`, `XTI` or the corresponding `.DWX` symbols. If the latest row is older than `strategy_curve_stale_months`, the EA stays flat.

## Symbols And Slots

| Slot | Symbol |
|---:|---|
| 0 | XAUUSD.DWX |
| 1 | XAGUSD.DWX |
| 2 | XTIUSD.DWX |

## Validation

- Build-only scope. No backtests or pipeline phases run from this build handoff.
- Required checks: `compile_one.ps1 -Strict`, `build_check.ps1 -Strict`, and registry validation.
