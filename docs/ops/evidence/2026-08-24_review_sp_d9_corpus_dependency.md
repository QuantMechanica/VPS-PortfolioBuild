# Review — SP-D9 corpus dependency / retention dry-run (task c65592c7)

Date: 2026-08-24 UTC
Reviewer: Claude (review lane)
Router task: `c65592c7-c8f4-4579-baf6-0ec7d9429319` (ops_issue, assigned codex, REVIEW)
Artifact under review: `docs/ops/evidence/2026-08-23_sp_d9_corpus_dependency_dry_run.md`
Worker verdict: `DEPENDENCY_CENSUS_COMPLETE: 130/130 rows; report only; ROT-9 authority still absent`

## Verdict: APPROVED

The deliverable satisfies every acceptance criterion and every hard constraint of the task,
and its cited references verify against the repo/DB read-only.

## Verification performed (read-only)

- Input manifest integrity: recomputed SHA-256 of
  `D:/QM/reports/state/g_corpus_manifest_2026-08-22.json` =
  `e7f256db275de92d0a0fc14ab57310de77d978d3264e7ab027f59c7ef3f5e8ae` — matches the
  manifest hash cited in the report and in the task goal. Manifest carries
  `coverage.files_total=130`, `sha256_missing=0`, `entries` length 130; independently
  confirmed 0 entries lack a `sha256`.
- Census completeness: the per-file table has exactly 130 numbered data rows
  (`docs/ops/evidence/2026-08-23_sp_d9_corpus_dependency_dry_run.md`). Category tally:
  89 `referenced —`, 1 `title-only` (byte identity unproved), 40
  `not demonstrably referenced` = 130. Matches the report's stated 89 / 1 / 40 split.
- Cited-reference spot checks (all confirmed):
  - Row 1 → `cards_approved/QM5_9990_ff-dual-candle-bb-rsi.md:34` contains the
    forexfactory thread 1005994 citation matching `ff_1005994_dual-candle-strategy.pdf`.
  - Row 127 → `tools/strategy_farm/tests/test_raw_mq5_quarantine.py:112` contains
    `Prop Challenger EA.mq5`.
  - Row 130 → `cards_review/QM5_20152_sma-cross-pullback-h1_card.md:30` cites babypips
    forex-system-20150605 matching the row's file.
  - Row 101 (`forums.babypips...41718.pdf`) is classified title-only with an honest
    caveat that a shared title does not prove shared bytes — the correct conservative call.
- Tooling present: `tools/strategy_farm/audit_g_corpus_dependencies.py` exists.
- Deletion-language scan: grep for loesch/loesch/delete/purge/remove/entfern over the
  report returns zero hits. The report is framed "report only; no file action proposed or
  authorized" and states explicitly that a missing reference is not a deletion argument.

## Acceptance criteria

1. One dependency line per manifest file with a location — met (130/130, file:line anchors).
2. Search method named and its limits honestly bounded — met (fixed-string ripgrep over
   Cards/EAs/evidence/decisions/tests + read-only `sources` table; PDF body/OCR/renamed/
   paraphrased/binary references explicitly declared unfindable; 4 MiB cap noted).
3. No deletion proposal or list — met.
4. Rules a ROT-9 retention policy must contain — met (10 enumerated requirements incl.
   default-retain for unresolved/collection-only/title-only, RAW_UNTRUSTED MQ5 handling,
   and an `apply_authorized` gate separate from the dry-run).
5. Evidence document under `docs/ops/evidence/` — met.

## Hard constraints

No deletion/move/rename on G:; audit ran against the D: manifest, not the drive (G:
absent in headless context, correctly acknowledged); no ingestion / card / EA-ID creation;
"missing reference is not a deletion argument" is stated, not violated. All respected.

## Risks / notes

- The census is a lexical snapshot; renamed, runtime-assembled, or paraphrased references
  are out of scope by construction — this is disclosed, not hidden. Downstream retention
  action remains blocked on a signed ROT-9 policy, correctly out of scope here.
