# QM5_9169 build preflight — deterministic refusal

- Router task: `084be1d0-8d08-4c36-b672-5ff5befdd89e`
- Task type / priority: `build_ea` / `10`
- Assigned agent: `gemini`
- EA / expected slug: `9169` / `tv-mou-triple-lens-mtf`
- Checked at: `2026-08-24T00:53:00Z`
- Canonical checkout baseline: `8a3a6a9ff52058296be8a3bec0c319aaf7a3475d`
- Verdict: `REVIEW — BUILD REFUSED AT PRE-FLIGHT`

## Deterministic evidence

The canonical registries at `C:/QM/repo/framework/registry/` were inspected and filtered by exact string equality on `ea_id=9169`.

| Gate | Result |
|---|---|
| `ea_id_registry.csv` row count | `1` — slug is `aa-employee-sat` (rejected card identity), NOT `tv-mou-triple-lens-mtf` (FAIL: identity mismatch) |
| `magic_numbers.csv` row count | `0` — FAIL |
| Approved card path | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9169_tv-mou-triple-lens-mtf.md` exists |
| Canonical EA directory | `framework/EAs/QM5_9169_tv-mou-triple-lens-mtf/` exists |
| Files beneath directory | only skeleton `QM5_9169_tv-mou-triple-lens-mtf.mq5`; no `.ex5`, `SPEC.md`, or setfiles |

The `qm-build-ea-from-card` contract requires an allocated active EA registry row matching the approved slug and active magic rows for all target symbols before implementation. It requires stopping immediately on any failed pre-flight gate. No source, registry, setfile, framework, terminal, or pipeline mutation was attempted.

The prior orchestrator deprioritisation note on 2026-08-22 recorded `registry precondition missing (no_active_magic_rows); build is structurally guaranteed to refuse. Reversible: restore priority once task 8d1d903f re-registers and allocates.`

## Required upstream action

OWNER-governed intake / registry allocator must register EA ID 9169 with slug `tv-mou-triple-lens-mtf` in `ea_id_registry.csv` and allocate all required symbol-slot magic rows in `magic_numbers.csv`. After those records exist and the magic resolver is regenerated, route a fresh build attempt.
