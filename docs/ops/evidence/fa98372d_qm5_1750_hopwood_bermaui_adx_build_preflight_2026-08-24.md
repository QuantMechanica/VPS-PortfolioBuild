# QM5_1750 build preflight — deterministic refusal

- Router task: `fa98372d-3350-4ddd-b904-2a00a72bbd05`
- Task type / priority: `build_ea` / `10`
- Assigned agent: `gemini`
- EA / expected slug: `1750` / `hopwood-bermaui-adx-h4`
- Checked at: `2026-08-24T03:39:00Z`
- Canonical checkout: `C:/QM/repo`
- Branch: `agents/board-advisor`
- Verdict: `REVIEW — BUILD REFUSED AT PRE-FLIGHT (EA_ID_AND_MAGIC_GATE_FAIL)`

## Deterministic evidence

The canonical registries at `C:/QM/repo/framework/registry/` were checked for `ea_id=1750`:

| Gate | Result |
|---|---|
| `ea_id_registry.csv` row count | `0` — FAIL (ea_id 1750 absent from EA registry) |
| `magic_numbers.csv` row count | `0` — FAIL (0 active rows found; card specifies target symbols `[EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, NDX.DWX, WS30.DWX]`) |
| Canonical EA directory | `framework/EAs/QM5_1750_hopwood-bermaui-adx-h4/` exists |
| Approved Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1750_hopwood-bermaui-adx-h4.md` exists |
| Files beneath directory | Only unbuilt skeleton `QM5_1750_hopwood-bermaui-adx-h4.mq5` (127 lines); no `.ex5`, `.set`, or `SPEC.md` |
| `compile_ea.py` pre-check | `MAGIC_NOT_REGISTERED` — `ea_id 1750 not in framework/registry/magic_numbers.csv; register the magic before compiling` |

The `qm-build-ea-from-card` contract requires active ea_id registration in `ea_id_registry.csv` and active magic rows in `magic_numbers.csv` for every declared symbol slot before building and strict compilation. Under the governance contract and tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee`, build agents must refuse fail-closed when registry preconditions are missing.

## Actions Taken
- No source modified.
- No registry modified.
- No terminal started.
- Preflight documented and submitted for review.

## Required Upstream Action
1. Register `ea_id=1750` in `ea_id_registry.csv`.
2. Allocate the 6 active magic rows via `governed_magic_allocator.py` and regenerate `QM_MagicResolver.mqh`.
3. Re-dispatch the build task once registry preconditions are satisfied.
