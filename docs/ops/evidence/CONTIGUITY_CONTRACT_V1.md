# Contiguity projection contract V1

Schema: `qm.contiguity/v1`. Status: review artifact, 2026-09-05. Implementation: `tools/strategy_farm/release_status.py`.

This documents the existing reference census. It changes no gate or admission rule. The active versioned gate manifest determines the automated chain (currently Q02 through Q14). Each stored phase is translated using its contract version. A pair is `(ea_id, symbol)`, never an individual closure row.

A pair is historically contiguous when every gate has at least one completed PASS-class witness under `rebaseline_census.vclass(verdict, gate)`. Informational portfolio siblings cannot prove the news gate. The first unsatisfied gate is the missing link. Later evidence cannot bridge it. Historical witnesses can come from different runs and identities: contiguity alone does not attest an exact binary, set, data and evidence chain.

The OWNER receipt in `decisions/2026-09-02_owner_receipts_ceo_asks.md`, items 2 and 7, ratifies Q08 FAIL_SOFT as historical PASS-class and aligns stream binding with that rule. FAIL_SOFT at another gate retains its existing meaning. An optional diagnostic excluding the Q08 exception has no authority to change the qualified population.

Report terminal closure row count, distinct pair count, reference census pair count, independent fast set-projection count, builder guard population, and physically bound bundle count separately. Duplicate terminal closures do not create extra pairs. Disagreement between reference and fast sets returns a nonzero exit, with the symmetric difference. The legacy standalone fast-census entrypoint was not located; the report explicitly names its new parity projection.

For each terminal cohort pair, report the latest successful version-translated terminal row and typed identity with declared payload fallback; gate witnesses and observed evidence hashes; the existing bundle resolver's Q08 seal and matching physical bytes; declared data window and archive identity; screening score with its stream-hash match; and uncertainty, owner and next action. Missing values stay null. A stream re-seal after terminal closure is flagged. Witness hashes prove observed bytes, not their original acceptance or a complete parent chain. Exact chain attestation remains unproven by this projection.

Execution readiness is not authorized by this report. The unchanged book guard still requires at least 25 qualified pairs and its OWNER order. Screening scores and historical passes establish neither FTMO economic acceptance nor native operational verification. This command opens SQLite in `mode=ro`, enables `query_only`, reads a single transaction snapshot, and emits JSON to stdout. Filesystem evidence is separately observed and hashed; no atomic DB/filesystem snapshot is claimed. It never writes the database, queues, verdicts, evidence sources, terminals, or trading settings.

Operator command: `python C:/QM/repo/tools/strategy_farm/release_status.py`. Redirect stdout only to a new evidence artifact. This contract lives under `docs/ops/evidence/` to satisfy the scheduled-cycle canonical evidence-path instruction.
