# QM5_13211 build preflight — deterministic refusal

- Router task: `4f53ec6b-9e40-4266-9a59-dbd707316c2e`
- Task type / priority: `build_ea` / `10`
- Assigned agent: `gemini`
- EA / expected slug: `13211` / `mulham-tgif-weekly-fade`
- Checked at: `2026-08-24T03:36:00Z`
- Canonical checkout: `C:/QM/repo`
- Branch: `agents/board-advisor`
- Verdict: `REVIEW — BUILD REFUSED AT PRE-FLIGHT (MAGIC_GATE_FAIL)`

## Deterministic evidence

The canonical registries at `C:/QM/repo/framework/registry/` were checked for `ea_id=13211`:

| Gate | Result |
|---|---|
| `ea_id_registry.csv` row count | `1` — active row (`13211,mulham-tgif-weekly-fade,YT-MULHAM-2026-07_TGIF-WEEKLY-FADE_S01,active,Research+Development (OWNER Mulham channel mandate),2026-07-13,,,`) |
| `magic_numbers.csv` row count | `0` — FAIL (0 active rows found; card requires 2 symbol slots for `NDX.DWX` and `EURUSD.DWX`) |
| Canonical EA directory | `framework/EAs/QM5_13211_mulham-tgif-weekly-fade/` exists |
| Approved Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_13211_mulham-tgif-weekly-fade.md` exists |
| Files beneath directory | Only unbuilt skeleton `QM5_13211_mulham-tgif-weekly-fade.mq5` (127 lines); no `.ex5`, `.set`, or `SPEC.md` |
| `compile_ea.py` pre-check | `MAGIC_NOT_REGISTERED` — `ea_id 13211 not in framework/registry/magic_numbers.csv; register the magic before compiling` |

The `qm-build-ea-from-card` contract requires active magic rows in `magic_numbers.csv` for every declared symbol slot before building and strict compilation. Under the governance contract and tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee`, build agents must refuse fail-closed when magic rows are absent.

## Actions Taken
- No source modified.
- No registry modified.
- No terminal started.
- Preflight documented and submitted for review.

## Required Upstream Action
1. Allocate the 2 active magic numbers (`132110000`, `132110001`) via `governed_magic_allocator.py` and regenerate `QM_MagicResolver.mqh`.
2. Re-dispatch the build task once magic rows exist.
