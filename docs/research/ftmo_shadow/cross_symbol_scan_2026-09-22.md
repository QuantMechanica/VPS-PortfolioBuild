# Cross-symbol/session transmission scan — 2026-09-22

State: research prescreen only. `WORTH_MT5_TEST` is not economic validation.

## Result

The deterministic scan evaluated **75,660 cells** across 39 symbols, 1,482 ordered pairs, 6 windows, and 2 locked lead-size thresholds. BH FDR 10% rejected 0 selection nulls; **0** also retained the same positive net-R sign and at least half the selection effect in the locked 2023-2025 holdout.

Data availability: 37 of 39 declared symbols have 2018-2025 HCC history. The missing-history symbols are `JPN225.DWX, XBRUSD.DWX`; only 2026 files exist for them. Their pre-declared cells remain in the BH family and fail closed as `UNKNOWN`.

States: `{"CLEAR_REJECT": 65230, "UNKNOWN": 10430, "WORTH_MT5_TEST": 0}`. Runtime target: `< 7200 seconds on four workers`.

## Locked method

- SEL 2018-07-02..2022-12-31; VAL 2023-01-01..2025-12-31.
- Lead thresholds: 0.5 and 1.0 prior-14 same-window ATR; continuation and reversal are separate tests.
- Lead-only entries use only a completed predecessor window. Peer-confirmed entries wait for the first completed 15-minute reference bar and use the next bar open.
- F2 spread plus slippage priors are charged once per round trip. Double-cost means are included per cell.
- One-sided net-R t-stat p-values enter a single BH family at q=0.10; both SEL and VAL need at least 30 observations.
- No validation threshold tuning, ML, terminal access, factory rows, roster changes, or gate changes.

## Survivors in OWNER section-28 format

No cell survived both FDR and the locked validation rule.

## Reproduction

```powershell
python tools/strategy_farm/research/cross_symbol_scanner.py --workers 4
```

The companion JSON contains every cell, its SEL/VAL statistics, BH q-value, state, neighboring-cell check, cost prior, and HCC source inventory.
