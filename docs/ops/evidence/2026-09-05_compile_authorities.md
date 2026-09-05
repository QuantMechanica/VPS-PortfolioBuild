# Compile backlog exact authorities

RESULT: REVIEW. Router task `74b400f5-6b98-45f1-8f3a-09aeda91f3e8`.
Implementation: `agents/codex-compile-authorities-20260905`, commit `dd4864287d`.
[Review patch](2026-09-05_compile_authorities/compile_authorities.patch).

Eleven explicit authority strings now have per-EA registrations in the isolated
branch. Each predicate binds the exact label, selected source bytes, predecessor
IDs and their queued source hashes, statuses and verdicts, plus SHA-256 of the
source-repair evidence document. Missing/changed evidence, source drift, a different
EA, altered predecessor, or a claimed predecessor is refused. An unrelated open
compile with different source is also refused. Worker rechecks bind the successor
to its exact lineage, authority and evidence payload.

The selected source, Git provenance, unrecoverable queued hashes, and evidence
hash are recorded in [source bindings](2026-09-05_compile_authorities/source_bindings.json).
The four unchanged-source wave predicates use their exact most recent failed
compile predecessors; this path can express the requested authority and waive the
historical WORK_ITEMS_EXIST and BOUND_SETFILE_HASH_EXISTS blockers. No set is unbound
or rewritten by this review.

QM5_1538's successor payload names both `674da780-53ef-4e37-993c-b02ca4f0a243`
and `550b62ec-516d-4fba-b845-e0b1d61e9437`, with the older `674da780` explicitly
listed in `source_repair_superseded_predecessor_work_item_ids`. No predecessor row
is deleted or changed.

## Source selection exception discovered

QM5_1538's working file is materially different from HEAD, not merely different
line endings. The source-repair report's `f4d84bdf...` file is still uncommitted.
The instruction selects the CURRENT **committed** source, so this registration
pins Git source commit `6d5151742b` and blob SHA-256
`d2519ab642dde14bc066996c55a1aea4fcfac9bb4f8c39db4eb9e002945d1460`.
The working file remains untouched and does not satisfy that selection. A CEO
close-out must resolve its working/committed mismatch before enqueueing a successor;
this task does not silently authorize the working edits. The other ten selected
files match committed content; existing canonical line endings are pinned exactly.

## Dry runs and focused verification

**101 tests passed:**

```powershell
python -m pytest tools/strategy_farm/tests/test_compile_backlog_authorities.py tools/strategy_farm/tests/test_compile_work_items.py -q
```

Run from the isolated branch. The 27 new tests cover every registered predicate,
negative identity/source/evidence/predecessor cases, worker payload bindings,
QM5_1538's two-predecessor lineage, all four unchanged-source wave cases, waiver
boundaries, and open-successor idempotence. Focused `git diff --check` passed.

[Exact canonical commands](2026-09-05_compile_authorities/commands.ps1),
[collector](2026-09-05_compile_authorities/collect_dry_runs.py), and
[verification receipt](2026-09-05_compile_authorities/verification.json).
All eleven canonical CLI invocations were run without `--apply`; all enqueue counts
are zero. Seven return idempotent OPEN_COMPILE_EA_EXISTS. The four wave commands
return exit 2 because the new authority registrations are still on the review branch.
These canonical outputs are not misrepresented as proof that the reviewed policy
has already been integrated.

The collector additionally loads the branch's actual implementation against a
SQLite `mode=ro`, `query_only=ON` inventory and canonical files. All eleven exact
selected-source predicates validate. The actual working-file previews are:

| EA | Branch preview |
|---|---|
| QM5_1538 | OPEN_COMPILE_EA_EXISTS; working source fails selected committed hash |
| QM5_41142 | USABLE_CURRENT_COMPILE_VERDICT_EXISTS |
| QM5_41176 | ELIGIBLE |
| QM5_41179 | ELIGIBLE |
| QM5_41189 | ELIGIBLE |
| QM5_41192 | USABLE_CURRENT_COMPILE_VERDICT_EXISTS |
| QM5_41352 | USABLE_CURRENT_COMPILE_VERDICT_EXISTS |
| QM5_41164 | ELIGIBLE |
| QM5_41165 | ELIGIBLE |
| QM5_41166 | ELIGIBLE |
| QM5_41172 | ELIGIBLE |

Each row has `QM5_<id>_canonical_dry_run.json` and `QM5_<id>_branch_preview.json`
under the evidence directory. Existing usable compile receipts remain protected;
this review does not manufacture a reason to compile them again.

The expired task lease was renewed before implementation. Task tags `ops` and
`ea_build` describe capabilities; no EA was built and no build/pipeline skill was
applicable. Source code stays on the isolated branch, evidence is committed only
on agents/board-advisor, and integration/apply remains with the CEO review round.
No compile, terminal operation, EA source edit, queue apply or main advancement
was performed.
