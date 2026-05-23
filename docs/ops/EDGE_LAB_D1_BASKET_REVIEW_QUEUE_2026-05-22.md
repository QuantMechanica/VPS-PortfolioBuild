# Edge Lab D1 Basket Review + Queue Evidence - 2026-05-22

Task: `8542bc4b-0370-4c19-82b9-0ac1fc3832aa`

## Reviewed EAs

- `QM5_10717_edgelab-xsec-fx-momentum`
- `QM5_10718_edgelab-regime-filtered-carry`

## Build Reconfirmation

```text
framework/scripts/build_check.ps1 -EALabel QM5_10717_edgelab-xsec-fx-momentum -RepoRoot C:/QM/worktrees/codex-orchestration-1
build_check.result=PASS
compile_one.errors=0
compile_one.warnings=0
build_check.report=D:\QM\reports\framework\21\build_check_20260522_144613.json

framework/scripts/build_check.ps1 -EALabel QM5_10718_edgelab-regime-filtered-carry -RepoRoot C:/QM/worktrees/codex-orchestration-1
build_check.result=PASS
compile_one.errors=0
compile_one.warnings=0
build_check.report=D:\QM\reports\framework\21\build_check_20260522_144613.json
```

## QM5_10717 Review Verdict

Verdict: `PASS_WITH_QUEUE_ENVIRONMENT_CAVEAT`

- Ranking is cross-sectional and deterministic: currency strength is computed from signed D1 returns across the 28-pair FX8 basket.
- Weekly rebalance closes existing basket positions, applies the volatility crash guard, then opens four extreme-vs-extreme legs.
- Leg placement uses `QM_BasketOpenPosition`; `symbol_slot` maps to the selected basket pair index.
- Magic model is deterministic via `qm_ea_id * 10000 + symbol_slot`.
- FTMO design controls are present: `QM_NEWS_FTMO_PAUSE`, Friday close, D1 swing horizon, `2.0 * ATR(20)` hard stop, no grid/martingale/ML.
- Defect noted: the task text expects slots 1-2 as the two legs, but the implementation uses the selected pair index as `symbol_slot` across slots 0-27. This matches the existing registry and basket helper model, but it is not a two-slot-only model.

## QM5_10718 Review Verdict

Verdict: `PASS_WITH_QUEUE_ENVIRONMENT_CAVEAT`

- Carry ranking is mechanical and pinned to broker swap proxy: `SYMBOL_SWAP_LONG - SYMBOL_SWAP_SHORT`, signed by base/quote currency.
- Regime filter is basket 20-day realized volatility versus 252-day median; red regime closes basket positions and stays flat.
- Weekly green-regime rebalance closes existing basket positions and opens top-2 carry currencies against bottom-2.
- Leg placement uses `QM_BasketOpenPosition`; `symbol_slot` maps to the selected basket pair index.
- Magic model is deterministic via `qm_ea_id * 10000 + symbol_slot`.
- FTMO design controls are present: `QM_NEWS_FTMO_PAUSE`, Friday close, D1 swing horizon, `2.0 * ATR(20)` hard stop, no grid/martingale/ML.
- Defect noted: same slot wording mismatch as `QM5_10717`; implementation is 28-slot pair-indexed rather than two-leg-only slots 1-2.

## Queue Evidence

`QM5_10717`:

```text
python tools/strategy_farm/farmctl.py work-items --ea QM5_10717
count=1
id=f587cbe6-478c-42cb-b4ff-94ba86130d77
phase=Q02
symbol=FX8_BASKET_D1
status=failed
verdict=INVALID
preflight_reason=ea_dir_missing
```

`QM5_10718`:

```text
python tools/strategy_farm/farmctl.py work-items --ea QM5_10718
count=1
id=c730d1d0-81e5-47ab-86c8-b99776c3d969
phase=Q02
symbol=FX8_BASKET_D1
status=failed
verdict=INVALID
preflight_reason=ea_dir_missing
```

Both EAs have exactly one logical basket Q02 work item and no per-symbol fanout.

## Queue Caveat

Both existing Q02 work items failed before execution because the worker preflight searched `C:/QM/repo/framework/EAs/QM5_10717_*` and `C:/QM/repo/framework/EAs/QM5_10718_*`. The isolated codex worktree contains the basket EA files and setfiles, but the worker checkout did not have matching files at the time of preflight. Requeue should wait until the worker repo root contains these same committed basket files.

## Verdict

`BOTH_EAS_REVIEWED_SINGLE_BASKET_Q02_ITEM_PRESENT`
