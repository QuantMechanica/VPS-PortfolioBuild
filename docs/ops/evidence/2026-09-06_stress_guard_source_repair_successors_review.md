# Six stress-guard compile successor registrations — REVIEW

Router task `04f011a6-6b6a-4562-b2ee-f2cb6f641e5a`.
Code branch `agents/codex-stress-guard-successors-20260906`, commit `d3ef95bdee1eedfdec0d492e312d4d3bc4663668`; isolated worktree `C:/QM/worktrees/codex-stress-guard-successors-20260906`.

Registered six exact authorities for QM5_41171 and QM5_41358 through QM5_41362, each keyed by this router task and EA ID. Each registration binds the current post-fix MQ5 hash, its latest completed/unclaimed predecessor, the predecessor source hash, and the immutable evidence document. Older failed compile rows for 41358 are preserved. No predecessor is marked for supersession mutation. QM5_41319 is excluded.

Immutable binding document: `2026-09-06_stress_guard_source_repair_successors.md`, SHA-256 **d7ca2e0cb76a21c000a36d161ce9d1703f817a5fa5489873d4b210c2a4392f11**. That file contains the complete old/new source hash table, exact predecessor IDs, rationale and six CEO-only canonical apply commands. It is deliberately separate from these test results so its pinned hash remains stable.

The existing backlog registration helper now chooses evidence path/hash per authority, preserving its legacy defaults. Authorization, candidate output and worker recheck all use the same authority-specific evidence binding. Tests include valid registrations, wrong authority/label/source/EA, missing or changed predecessor, claimed predecessor, changed/missing evidence, unrelated open compile, and worker successor lineage. Existing registrations continue through the same focused suite.

## Verification

```
python -m pytest -q tools/strategy_farm/tests/test_compile_work_items.py tools/strategy_farm/tests/test_compile_backlog_authorities.py --tb=short
113 passed in 10.05s
```

`git diff --check`: clean before commit.

| EA | Candidate classification | Enqueued | Refused |
|---|---|---:|---:|
| QM5_41171 | ELIGIBLE | 0 | 0 |
| QM5_41358 | ELIGIBLE | 0 | 0 |
| QM5_41359 | ELIGIBLE | 0 | 0 |
| QM5_41360 | ELIGIBLE | 0 | 0 |
| QM5_41361 | ELIGIBLE | 0 | 0 |
| QM5_41362 | ELIGIBLE | 0 | 0 |

The canonical `C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile --from-file <single-label-file> --source-repair-authority <exact-authority>` command was exercised six times in **dry_run** mode. To test the unintegrated branch without replacing canonical code, the harness preloads only the isolated candidate `compile_work_items.py` module in memory before running the canonical CLI. Source, registries, bound evidence and farm database are read from canonical locations; no eligibility check is stubbed or bypassed. Thus these results prove the candidate implementation, not that the unchanged canonical module already contains the registrations.

Reproducer and six complete CLI JSON receipts are retained in `2026-09-06_stress_guard_source_repair_successors/`. `dry_run_summary.json` pins the tested module hash and reports all eight historical compile rows for these six EAs byte-for-value unchanged before/after the dry runs. No `--apply`, compile, queue release, source/set mutation, pipeline verdict or Q02 rerun was executed.

After independent acceptance and authorized code integration, CEO can use the six exact apply commands in the immutable document, release the governed compile wave and seed append-only Q02 reruns with the new binary identity. This handoff remains REVIEW; canonical code and main integration were not performed here.
