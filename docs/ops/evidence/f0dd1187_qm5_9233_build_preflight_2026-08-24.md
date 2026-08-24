# QM5_9233 build preflight — deterministic refusal

- Router task: `f0dd1187-ac39-4a61-8e38-77b26f600d71`
- Task type / priority: `build_ea` / `10`
- Assigned agent: `gemini`
- EA / expected slug: `9233` / `mql5-ad-div`
- Checked at: `2026-08-24T02:05:00Z`
- Canonical checkout baseline: `b2ba9fb0700ec0c9fc79e9558669e86e7542ecb5`
- Verdict: `REVIEW — BUILD REFUSED AT PRE-FLIGHT`

## Deterministic evidence

The canonical registries at `C:/QM/repo/framework/registry/` were inspected and filtered by exact string equality on `ea_id=9233`.

| Gate | Result |
|---|---|
| `ea_id_registry.csv` row count | `1` — active row, slug `mql5-ad-div` |
| `magic_numbers.csv` row count | `0` — FAIL (no active magic rows allocated) |
| Approved card path | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9233_mql5-ad-div.md` exists |
| Canonical EA directory | `framework/EAs/QM5_9233_mql5-ad-div/` exists |
| Files beneath directory | only skeleton `QM5_9233_mql5-ad-div.mq5`; no `.ex5`, `SPEC.md`, or setfiles |

The `qm-build-ea-from-card` contract requires allocated active magic rows for every target symbol slot before implementation. It requires stopping immediately on any failed pre-flight gate. No source, registry, setfile, framework, terminal, or pipeline mutation was attempted.

The prior orchestrator deprioritisation note recorded: `registry precondition missing (no_active_magic_rows); build is structurally guaranteed to refuse. Reversible: restore priority once task 8d1d903f re-registers and allocates. No row deleted.`

## Required upstream action

OWNER-governed intake / registry allocator must allocate all required symbol-slot magic rows in `magic_numbers.csv` for EA 9233. After those records exist and the magic resolver is regenerated, route a fresh build attempt.
