# QM5_9010 build preflight — deterministic refusal

- Router task: `2cdbbe4e-095e-4f53-89a2-243ecc4ae615`
- Task type / priority: `build_ea` / `10`
- Assigned agent: `codex`
- EA / expected slug: `9010` / `mql5-envelope-bounce`
- Checked at: `2026-08-24T00:08:27Z`
- Canonical checkout baseline: `755a4b6889ae844d5c81716639bdec60c7e6da8e`
- Verdict: `REVIEW — BUILD REFUSED AT PRE-FLIGHT`

## Deterministic evidence

The canonical registries at `C:/QM/repo/framework/registry/` were loaded with
PowerShell `Import-Csv` and filtered by exact string equality on `ea_id=9010`.

| Gate | Result |
|---|---|
| `ea_id_registry.csv` row count | `1` — active row, slug `mql5-envelope-bounce` |
| `magic_numbers.csv` row count | `0` — FAIL |
| Canonical EA directory | `framework/EAs/QM5_9010_mql5-envelope-bounce/` exists |
| Files beneath directory | only `QM5_9010_mql5-envelope-bounce.mq5`; no `.ex5`, setfile, or build-time card copy |

The `qm-build-ea-from-card` contract requires active magic rows for every symbol
slot before implementation and requires stopping on any failed pre-flight gate.
No source, registry, setfile, framework, terminal, or pipeline mutation was
attempted.

The prior canonical adjudication in
`docs/ops/evidence/2026-07-27_recycle_backlog_worked.md` also classified this
task `NEEDS-SOURCE` for the missing anchored magic row and missing OWNER-approved
mandatory-news revision. This pass did not weaken the mandatory news-blackout
contract or allocate governed registry rows.

## Required upstream action

OWNER-governed intake must provide the approved mandatory-news card revision and
allocate all required symbol-slot magic rows for EA 9010. After those records
exist, route a fresh build attempt.
