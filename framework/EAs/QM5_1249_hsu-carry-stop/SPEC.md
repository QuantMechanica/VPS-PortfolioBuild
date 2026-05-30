# QM5_1249 hsu-carry-stop

## Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1249_hsu-carry-stop.md`
- Local copy: `docs/strategy_card.md`
- Status: APPROVED / G0

## Framework Mapping

- No-trade: framework kill-switch, news gate and Friday-close handling, plus symbol-scope validation and flat behavior when monthly rates CSV is missing or stale.
- Entry: on the first trading day of the month, read deterministic short-rate CSV, rank the six configured FX pairs by base-minus-quote rate differential, enter long top-ranked positive differentials and short bottom-ranked negative differentials.
- Trade management: fixed initial stop at `ATR(D1, 20) * 2.5`; after stop detection, the same symbol is blocked from new entries until the next monthly rebalance.
- Close: monthly rebalance closes positions that leave the selected top/bottom rank set or whose differential crosses through zero.

## Data Contract

- Rates CSV input: `QM5_1249_fx_monthly_rates.csv`
- Expected CSV columns by position: `date,USD,EUR,GBP,JPY,AUD,NZD,CAD,CHF`
- Missing, unreadable, future-dated or stale rates data produces no entries and exits active positions at rebalance when no valid desired direction is available.

## Symbols And Slots

| Slot | Symbol |
|---:|---|
| 0 | AUDJPY.DWX |
| 1 | NZDJPY.DWX |
| 2 | GBPJPY.DWX |
| 3 | USDJPY.DWX |
| 4 | AUDUSD.DWX |
| 5 | NZDUSD.DWX |

## Validation

- Build-only scope. No backtests or pipeline phases run from this build handoff.
- Required checks: `compile_one.ps1 -Strict`, `build_check.ps1 -Strict`, and registry validation.
