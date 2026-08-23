# SP-D10 Placeholder Cleanup — Dependency Hold

Date: 2026-08-23

Router task: `3c365266-68b6-4474-87ac-9049af52c7ec` (`SP-D10`, priority 35,
zone GELB)

## Verdict

DEPENDENCY_HOLD — no folder, file, or DST prompt was removed. SP-D10's own
acceptance criteria require two things before any removal: "bestandenem
Dry-Run" (a passed dependency/retention dry-run) and "OWNER-Freigabe" (OWNER
sign-off). Neither exists yet:

1. **Dry-run — not passed, report-only.** The current retention dry-run task
   (`c65592c7-c8f4-4579-baf6-0ec7d9429319`, "SP-D9 neu: Dependency-/
   Retention-Dry-Run gegen das jetzt existierende 130/130-Corpus-Manifest")
   is in state `REVIEW`, verdict `DEPENDENCY_CENSUS_COMPLETE: 130/130 rows;
   report only; ROT-9 authority still absent`. A census report is not the
   same as a passed dry-run authorizing deletion — the verdict itself says
   ROT-9 (the deletion-authorization decision) is absent.
2. **OWNER-Freigabe — not given.** No `decisions/YYYY-MM-DD_*` record
   ratifying a placeholder-cleanup or ROT-9 deletion authorization exists as
   of this observation. The original `SP-D9` task (`2f36c28c-6430-4a55-8af7-
   8d213f372cc6`) remains `BLOCKED` on the same OWNER-decided
   `Manifest-first` sequencing (`OWNER-DEC-G-RETENTION`,
   `decisions/2026-08-22_owner_decisions_evening_batch.md` §3): no deletion
   on `G:` before both a content-addressed manifest and a dependency
   dry-run exist. The manifest exists (130/130); the dry-run is
   report-only, not a pass; OWNER approval for any removal has not been
   sought or given.

Removing "empty" folders or a "done" DST prompt without both gates would be
exactly the kind of Manifest-first sequencing violation `OWNER-DEC-G-RETENTION`
was written to prevent — an "empty folder" on `G:` is not verifiable as
truly inert without the dependency census being a *pass*, not just a
completed *count*.

## Checks performed

- Read `SP-D10`'s payload (`depends_on: SP-D9`, hard_constraint "historische
  Evidenz nicht mit operativer Wahrheit verwechseln").
- Read both `SP-D9` rows in `agent_tasks`: the original (`2f36c28c...`,
  `BLOCKED`) and its replacement (`c65592c7...`, `REVIEW`,
  `DEPENDENCY_CENSUS_COMPLETE`, report-only).
- Confirmed no OWNER decision record ratifying placeholder removal or
  ROT-9 deletion authority exists in `decisions/`.

No file, folder, or DST-prompt state was changed while producing this hold.

## Deterministic resume conditions

SP-D10 may be re-routed once: (1) the retention dry-run reaches a genuine
pass state (not just a completed census) with ROT-9 authority ratified, and
(2) OWNER explicitly signs off on removing the specific empty folders / DST
prompt this task names.

## Evidence

- `agent_tasks` row `3c365266-68b6-4474-87ac-9049af52c7ec` (SP-D10, this task).
- `agent_tasks` row `c65592c7-c8f4-4579-baf6-0ec7d9429319` (SP-D9 neu, `REVIEW`, census-only).
- `agent_tasks` row `2f36c28c-6430-4a55-8af7-8d213f372cc6` (SP-D9 original, `BLOCKED`).
- `decisions/2026-08-22_owner_decisions_evening_batch.md` §3 (`OWNER-DEC-G-RETENTION`: Manifest-first).
