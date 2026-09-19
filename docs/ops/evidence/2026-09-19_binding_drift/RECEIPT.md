# Binding-drift per-EA provenance review — ticket 42877794 (2026-09-19)

Input: `census.json` (42 rows, 26 unique EAs, all `GOVERNED_BUILD_SUCCESSOR_REQUIRED` as of
2026-09-19 09:05Z). Method: git-log provenance of the current mq5/ex5/setfile per row vs the
row-bound sha256, cross-checked against `work_item_supersedes` and the `work_items`
`kind='compile' AND phase='COMPILE_EA' AND status='done' AND verdict='COMPILE_OK'` ledger (the
same predicate `validate_ex5_commit_guard.py` enforces pre-commit for any staged `.ex5` change).
Full machine-readable detail: `dispositions.json`. **Nothing was overwritten, no hold was
released without a successor, no verdict was touched.**

## Defect found in the input tooling

`census.json` and `pending_binding_rebind_plan.py`'s `rebind_plan.json` do not join against
`work_item_supersedes`. Result: **23 of the 42 flagged rows already have a recorded governed
successor** (mostly `farmctl.requalify-q02`, DL-089 zombie disposition, or july-cohort
park/retire, dated 2026-08-24 through 2026-09-18) — the census disposition on those rows is
stale. Separately, `rebind_plan.json`'s `rebind_eligible_count: 0` is a schema mismatch
(`plan.json` uses `work_item_id`/`ea_id` keys; the planner expects `id`/`ea`/`cause_cluster`),
not a real finding — flagging both for whoever owns that tooling.

## Per-EA disposition table

| EA | Rows | Disposition | Detail |
|---|---|---|---|
| QM5_20181 | 2 | **A — already superseded** | july_cohort_park → 407f23c8 (PASS-family, evidence ages never) |
| QM5_20096 | 1 | **A — already superseded** | july_cohort_retire → 41a774ad (terminal ZERO_TRADES) |
| QM5_10717 | 1 | **A — already superseded** | COMPILE_OK 9f797114 rebuilt before seed claimed; marked obsolete |
| QM5_10269 | 1 | **A — already superseded** | `requalify-q02` → 127aab04, 2026-09-12 |
| QM5_10706 | 5 | **A — already superseded** | 1× orphan Q13/Q14 lane hygiene, 4× DL-089 zombie disposition |
| QM5_11421 | 3 | **A — already superseded** | 1× orphan lane hygiene, 2× DL-089 zombie disposition |
| QM5_10700 | 1 | **A — already superseded** | OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903 |
| QM5_41359/60/61 | 3 | **A — already superseded** | `requalify-q02`, CEO-reviewed task 9d8ad690, 2026-09-07 |
| QM5_21505 | 2 | **A — already superseded** | DL-089 zombie disposition, 2026-09-18 |
| QM5_13054 | 2 | **A — already superseded** | DL-089 zombie disposition, 2026-09-18 |
| **QM5_10718** | 1 | **B — verified eligible, successor not yet minted** | Rebuild `ba5a522e2` (2026-09-02); COMPILE_OK receipt `0ce7af66` matches current ex5+mq5 exactly. Live attempt refused cleanly (`q03_predecessor_not_bound_to_current_execution`) — needs a fresh current-binary Q02 pass before Q03 can cascade. Exact next command in `dispositions.json`. |
| **QM5_20202** | 1 | **B — verified eligible, successor not yet minted** | Rebuild `df8310c0a` (2026-09-06); COMPILE_OK receipt `147b9f42` matches current ex5+mq5 exactly. Same Q02-first blocker as QM5_10718. |
| **QM5_20275** | 1 | **B — verified eligible, successor not yet minted** | Rebuild `df8310c0a` (2026-09-06); COMPILE_OK receipt `6411538e` matches current ex5+mq5 exactly. Same Q02-first blocker. |
| QM5_10203, QM5_10593, QM5_1443, QM5_35005(×3), QM5_35004(×3), QM5_10116(×2), QM5_12919 | 12 | **C — keep hold, ex5 unchanged** | Verified the on-disk `.ex5` sha256 still equals `payload_json.expected_ex5_sha256` for every one of these rows — the binary dispatch actually tests has not moved. Only mq5 source text drifted via a later committed fix, with no accompanying recompile. No compiled successor exists to bind; nothing to do but keep the hold. |
| **QM5_20143** | 1 | **C — keep hold, ex5 unchanged; setfile LINE_ENDINGS proof done** | Same ex5-unchanged class. Setfile role classified `LINE_ENDINGS_ONLY`: CRLF→LF normalization of the current bytes reproduces the bound sha256 exactly (proof in `dispositions.json`). Row carries `ARTIFACT_BINDING_REBUILD_IN_PROGRESS` — an active rebuild is already underway; not touched so as not to collide with it. |
| QM5_10649 | 1 | **D — provenance unclear, keep hold** | No COMPILE_EA receipt on record. Commit (2026-08-16) predates the EX5 commit guard (2026-08-24), so absence isn't itself a violation, but there's no mechanical COMPILE_OK proof either. |
| QM5_33007 | 1 | **D — provenance unclear, keep hold, flag** | Rework commit predates the guard by ~3h same day; the one compile receipt on record for this EA is a **COMPILE_FAIL** logged *after* the commit. Recommend a Codex ticket to force a fresh governed recompile and confirm COMPILE_OK before reconsidering. |
| QM5_41362 | 1 | **D — provenance unclear, keep hold** | Sibling pacer EAs from the same 2026-09-06 wave (41359-61) all resolved cleanly; 41362 alone has no matching receipt and carries its own `ARTIFACT_BINDING_SOURCE_SET_UNRECOVERABLE` hold — a pre-existing, more specific block. Left to the build lane. |

**Totals: A=23, B=3, C=13, D=3, sum=42.**

## What was and wasn't done

- No hold released, no verdict touched, no row deleted or overwritten.
- Live-tested the governed successor path for the 3 group-B candidates using the ticket's
  suggested tooling (`enqueue-backtest --from-work-item-id --expected-current-ex5-sha256`);
  all three refused safely (no mutation) with a precise, actionable reason — the direct-to-Q03
  cascade needs a Q02 PASS achieved on the *current* binary first, which doesn't exist yet for
  any of the three. Minting that fresh Q02 identity (`requalify-q02` or `seed-fresh-q02`) is the
  correct next step; left for Codex/next cycle rather than guessing the right predecessor
  identity blind in an unattended run.
- Group C's "ex5 unchanged" finding was verified directly against `payload_json` for every row,
  not inferred from census silence.
- Group D findings are genuine open questions (missing/failed compile evidence), not busywork —
  worth a Codex look, especially QM5_33007's post-commit COMPILE_FAIL.
