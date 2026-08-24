# QM5_9167 build preflight — deterministic refusal

- Router task: `f1d3f7a3-1999-48e5-ada5-caac982e382d`
- Task type / priority: `build_ea` / `10`
- Assigned agent: `gemini`
- EA / expected slug: `9167` / `tv-boswaves-supertrend-extensions`
- Checked at: `2026-08-24T00:35:40Z`
- Canonical checkout baseline: `3ca77815602859fa485a3e33498074b4cf4bdc4e`
- Verdict: `REVIEW — BUILD REFUSED AT PRE-FLIGHT`

## Deterministic evidence

The canonical registries at `C:/QM/repo/framework/registry/` were inspected and filtered by exact string equality on `ea_id=9167`.

| Gate | Result |
|---|---|
| `ea_id_registry.csv` row count | `1` — slug is `aa-deep-value-spread` (rejected card identity), NOT `tv-boswaves-supertrend-extensions` (FAIL: identity mismatch) |
| `magic_numbers.csv` row count | `0` — FAIL |
| Approved card path | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9167_tv-boswaves-supertrend-extensions.md` exists |
| Canonical EA directory | `framework/EAs/QM5_9167_tv-boswaves-supertrend-extensions/` exists |
| Files beneath directory | only skeleton `QM5_9167_tv-boswaves-supertrend-extensions.mq5`; no `.ex5`, `SPEC.md`, or setfiles |

The qm-build-ea-from-card contract requires an allocated active EA registry row matching the approved slug and active magic rows for all target symbols before implementation. It requires stopping immediately on any failed pre-flight gate. No source, registry, setfile, framework, terminal, or pipeline mutation was attempted.

The prior orchestrator deprioritisation note on 2026-08-22 recorded `registry precondition missing (no_active_magic_rows); build is structurally guaranteed to refuse. Reversible: restore priority once task 8d1d903f re-registers and allocates.`

## Required upstream action

OWNER-governed intake / registry allocator must register EA ID 9167 with slug `tv-boswaves-supertrend-extensions` in `ea_id_registry.csv` and allocate all required symbol-slot magic rows in `magic_numbers.csv`. After those records exist and the magic resolver is regenerated, route a fresh build attempt.
