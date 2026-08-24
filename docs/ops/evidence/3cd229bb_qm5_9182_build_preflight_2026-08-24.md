# QM5_9182 build preflight — deterministic refusal

- Router task: `3cd229bb-8900-4dac-9367-3dbfaf84f67c`
- Task type / priority: `build_ea` / `10`
- Assigned agent: `gemini`
- EA / expected slug: `9182` / `jstm-heikin-ashi-trend-long`
- Checked at: `2026-08-24T01:05:00Z`
- Canonical checkout baseline: `c93c467442e4077c040421b4544cb1294c5f0c49`
- Verdict: `REVIEW — BUILD REFUSED AT PRE-FLIGHT`

## Deterministic evidence

The canonical registries at `C:/QM/repo/framework/registry/` were inspected and filtered by exact string equality on `ea_id=9182`.

| Gate | Result |
|---|---|
| `ea_id_registry.csv` row count | `0` active rows (ea_id 12331 exists under this slug but is `retired`) (FAIL: unregistered ea_id / missing active registry row) |
| `magic_numbers.csv` row count | `0` — FAIL |
| Approved card path | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9182_jstm-heikin-ashi-trend-long.md` exists |
| Canonical EA directory | `framework/EAs/QM5_9182_jstm-heikin-ashi-trend-long/` exists |
| Files beneath directory | only skeleton `QM5_9182_jstm-heikin-ashi-trend-long.mq5`; no `.ex5`, `SPEC.md`, or setfiles |

The `qm-build-ea-from-card` contract requires an allocated active EA registry row matching the approved slug and active magic rows for all target symbols before implementation. It requires stopping immediately on any failed pre-flight gate. No source, registry, setfile, framework, terminal, or pipeline mutation was attempted.

The prior orchestrator deprioritisation note on 2026-08-22 recorded `registry precondition missing (ea_id_unregistered); build is structurally guaranteed to refuse. Reversible: restore priority once task 8d1d903f re-registers and allocates.`

## Required upstream action

OWNER-governed intake / registry allocator must register EA ID 9182 with slug `jstm-heikin-ashi-trend-long` in `ea_id_registry.csv` and allocate all required symbol-slot magic rows in `magic_numbers.csv`. After those records exist and the magic resolver is regenerated, route a fresh build attempt.
