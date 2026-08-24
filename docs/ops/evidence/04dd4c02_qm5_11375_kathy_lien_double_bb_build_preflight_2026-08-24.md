# QM5_11375 build preflight - deterministic refusal

- Router task: `04dd4c02-2889-4a31-bf5c-630843571d34`
- Task type / priority: `build_ea` / `10`
- Assigned agent: `gemini`
- EA / expected slug: `11375` / `kathy-lien-double-bb-1-2sigma-m15`
- Checked at: `2026-08-24T03:21:00Z`
- Canonical checkout: `C:/QM/repo`
- Branch: `agents/board-advisor`
- Verdict: `REVIEW - BUILD REFUSED AT PRE-FLIGHT (MAGIC_GATE_FAIL)`

## Deterministic evidence

The canonical registries at `C:/QM/repo/framework/registry/` were checked for `ea_id=11375`:

| Gate | Result |
|---|---|
| `ea_id_registry.csv` row count | `1` - active row (`11375,kathy-lien-double-bb-1-2sigma-m15,3d831560-f01a-5df3-8843-6d61fd78902f,active,Research,2026-05-23,,,`) |
| `magic_numbers.csv` row count | `0` - FAIL (0 active rows found; card requires 4 symbol slots for EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, GBPJPY.DWX) |
| Canonical EA directory | `framework/EAs/QM5_11375_kathy-lien-double-bb-1-2sigma-m15/` exists |
| Approved Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11375_kathy-lien-double-bb-1-2sigma-m15.md` exists |
| Files beneath directory | Only unbuilt skeleton `QM5_11375_kathy-lien-double-bb-1-2sigma-m15.mq5` (127 lines); no `.ex5`, `.set`, or `SPEC.md` |

The `qm-build-ea-from-card` contract requires active magic rows in `magic_numbers.csv` for every declared symbol slot before building and strict compilation. Under the governance contract and tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee`, build agents must refuse fail-closed when magic rows are absent.

## Actions Taken
- No source modified.
- No registry modified.
- No terminal started.
- Preflight documented and submitted for review.

## Required Upstream Action
The governed registry writer (`governed_magic_allocator.py`) must allocate the 4 active magic numbers for EA 11375 and regenerate `QM_MagicResolver.mqh`.
