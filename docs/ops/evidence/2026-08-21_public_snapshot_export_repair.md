# Public-Data Snapshot Export — Diagnosis (stalled since 2026-07-28)

- **Date:** 2026-08-21
- **Author:** Claude (T11 diagnostic task)
- **Branch:** `agents/board-advisor`
- **Symptom (reported):** Scheduled task `QM_Public_Snapshot_Hourly` fires hourly but ends
  with `LastTaskResult=1` since ~2026-07-28; `public-data/public-snapshot.json`
  `generated_at` frozen at `2026-07-28T23:07:15.1128698Z`.
- **Verdict:** **The export mechanism is NOT defective.** It is fail-closed by design on
  two unresolved Q02-bypass incident holds. Resuming publication requires releasing those
  holds — a governed `farm_state` mutation touching admission-authoritative state = **ROT**
  (never autonomous per Stehende Vollmacht 2026-08-20). No in-scope code fix applies.
  This is a **step-6 return**: document + precise recommendation, do not fix.

---

## 1. Task definition (as installed)

`Export-ScheduledTask QM_Public_Snapshot_Hourly`:

| Field | Value |
|---|---|
| Command | `powershell.exe` |
| Arguments | `-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\QM\repo\scripts\run_public_snapshot_task.ps1"` |
| WorkingDirectory | `C:\QM\repo` |
| User (Principal) | `S-1-5-18` (SYSTEM), `RunLevel=HighestAvailable` |
| Trigger | hourly, `StartBoundary 2026-05-19T15:07`, `PT1H`, `P3650D` |
| ExecutionTimeLimit | `PT20M` |
| LastRunTime / LastTaskResult | `2026-08-21 08:07:07` / `1` |

The task runs the **wrapper** `scripts/run_public_snapshot_task.ps1`, which in order:
1. Skips (exit 0) if `FACTORY_OFF.flag` present.
2. Acquires `FACTORY_MUTATION.lock` (skips exit 0 if busy).
3. **Runs `tools/strategy_farm/public_snapshot_incident_guard.py` and `throw`s on refusal.**
4. Runs `scripts/build_pipeline_state.py` (writes `D:/QM/reports/state/pipeline_state.json`).
5. Runs `scripts/export_public_snapshot.ps1 -NoGit` (writes `public-data/*.json`).

Steps 4–5 are never reached: the `throw` at step 3 aborts the run with exit 1.

## 2. Root cause (with evidence)

The wrapper's incident-guard block (`run_public_snapshot_task.ps1:88-121`) refuses
publication. Task log `C:\Windows\Temp\qm_public_snapshot.log`, every run since
2026-07-29 (representative line 2026-08-21T06:07):

```
public_snapshot_task exit=1 error=public snapshot publication refused by incident guard
(rc=3 valid=True holds=[FACTORY_OFF_AUTO_Q02_BYPASS:60181936-0403-49bc-b221-dda4f35eb584,
STALE_BUILD_RESULT_AUTO_Q02_BYPASS:88ba4560-fd7f-456f-903f-f4982d8f9cf3] error=)
```

Direct reproduction (2026-08-21, this task):

```
$ python tools/strategy_farm/public_snapshot_incident_guard.py --db D:/QM/strategy_farm/state/farm_state.sqlite
{"active_incident_hold_count":2,"active_incident_holds":[
 {"hold_code":"FACTORY_OFF_AUTO_Q02_BYPASS","work_item_id":"60181936-..."},
 {"hold_code":"STALE_BUILD_RESULT_AUTO_Q02_BYPASS","work_item_id":"88ba4560-..."}],
 "publication_allowed":false,"schema_version":"qm-public-snapshot-incident-guard/v1","valid":true}
RC=3
```

`public_snapshot_incident_guard.py` (docstring): *"The public exporter must not publish
tracked state while either automatic Q02 bypass incident is active."* It is a **read-only,
fail-closed** gate (`mode=ro`, `PRAGMA query_only=ON`). rc=3 = valid read, publication
refused because `work_item_holds` has ≥1 active row with a blocking `hold_code`.

`work_item_holds` (read-only query), both `active=1`, `released_at=NULL`,
`created_at=2026-07-29T09:54:40+00:00`:

| work_item_id | hold_code | reason |
|---|---|---|
| 60181936…584 | FACTORY_OFF_AUTO_Q02_BYPASS | QM5_20182 Q02 auto-enqueued by record_build_result while FACTORY_OFF was intentional; Q01 valid, row not admission-authoritative |
| 88ba4560…3f4 | STALE_BUILD_RESULT_AUTO_Q02_BYPASS | QM5_20172 Q02 from a previous review-failed build result materialized during rework; fresh generation-bound result required |

Incident provenance: `docs/ops/evidence/2026-07-29_qm5_20182_q02_factory_off_bypass_incident.json`
and `..._qm5_20172_q02_stale_build_result_incident.json`, maintenance run
`mnt-20260729-factory-off-reconcile-v1`. Both incidents' `next_action` is:
*"create a fresh generation-bound Q02 only through the coordinated post-maintenance restart contract."*

**Timeline:** last successful publish 2026-07-28T23:07 → FACTORY_OFF maintenance the
morning of 2026-07-29 (wrapper skipped, exit 0) → holds created 2026-07-29T09:54 →
guard has refused every run since. Fully consistent with the frozen `generated_at`.

**The task's hypothesized causes are all absent:**
- (a) Python env / `sys.prefix` — the harmless `Could not find platform independent
  libraries <prefix>` warning appears on **stderr** but the guard emits valid JSON on
  stdout; `py_compile` of guard + `build_pipeline_state.py` passes. Not the cause.
- (b) PS 5.1 stderr trap — already neutralized in the wrapper
  (`run_public_snapshot_task.ps1:82-86` sets `$ErrorActionPreference="Continue"` before
  any native call, with explicit `$LASTEXITCODE` checks). Not the cause.
- (c) path/branch changes since late July — none; the wrapper, guard, exporter and the
  scheduled-task Command/Arguments/WorkingDirectory are intact. Not the cause.

## 3. Staleness assessment of the two blocking holds (read-only)

`work_items` history (farm_state, `mode=ro`):

- **QM5_20182 (`FACTORY_OFF_AUTO_Q02_BYPASS`, row 60181936) — hold is a STALE ORPHAN.**
  The incident's `next_action` (fresh generation-bound Q02) **was fulfilled**: rows
  `34f98716` (Q02 PASS, 2026-07-31T08:43) and `a8d09cc8` (Q02 PASS, 2026-07-31T08:20)
  exist; the EA then progressed and legitimately died at Q03 FAIL (`d1e54b21`,
  2026-08-01) / Q04 FAIL. Remediation complete on 2026-07-31, but the hold row was never
  flipped `active=0`. It no longer protects anything.

- **QM5_20172 (`STALE_BUILD_RESULT_AUTO_Q02_BYPASS`, row 88ba4560) — GENUINELY UNRESOLVED.**
  Only two work_items exist: `ab8d8b7a` (Q02 done, verdict `DRAFT_DEFECT`, 2026-07-26) and
  `88ba4560` (Q02 failed, `BLOCKED_STALE_BUILD_RESULT`, 2026-07-29). **No** fresh Q02 was
  ever created; the EA is stuck at `DRAFT_DEFECT`. The incident's `next_action` is
  outstanding. This hold is still doing its job (protecting public data from a state with
  an unresolved Q02-bypass) and must NOT be bypassed.

Consequence: even if the stale QM5_20182 orphan is released, the guard **correctly**
keeps refusing until QM5_20172 is resolved. Fail-closed behavior is working as intended.

## 4. Why no fix was applied (scope)

Releasing/writing `work_item_holds` is a governed `farm_state` mutation touching
admission-authoritative reasoning. Under Stehende Vollmacht 2026-08-20 this is **ROT**
("delete/overwrite verdicts or trade streams"; farm_state write; candidate/admission
scope) — never autonomous. `governed_work_item_hold.py` only *applies* holds (and only to
`status='pending'` rows); these `failed`-row incident holds were minted by the maintenance
reconcile and have no self-service release verb — release is a governed/OWNER operation.

Bypassing the guard to force a publish would defeat the integrity control while a real
unresolved incident (QM5_20172) is active — refused on principle.

Therefore: **no code change, no JSON regeneration** (correctly impossible in-scope).
`export_public_snapshot.ps1` and `build_pipeline_state.py` are healthy (`py_compile` OK);
the only blocker is the deliberate guard gate.

## 5. Recommendations (OWNER / governed process)

1. **Release the stale QM5_20182 orphan hold** (`FACTORY_OFF_AUTO_Q02_BYPASS`, row
   60181936): remediation completed 2026-07-31 (fresh Q02 PASS `34f98716`/`a8d09cc8`, then
   Q03/Q04 FAIL). Governed release with `released_at` + `release_note` citing this file.
2. **Resolve QM5_20172** (`STALE_BUILD_RESULT_AUTO_Q02_BYPASS`, row 88ba4560): either
   drive a fresh generation-bound Q02 via the post-maintenance restart contract, or make an
   OWNER decision to abandon the EA (`DRAFT_DEFECT` since 2026-07-26) and release the hold.
   Until one of these, public publication stays (correctly) frozen.
3. After both holds are inactive, the very next hourly run publishes normally with a fresh
   `generated_at` — no further code change required.

**Optional mechanism-hygiene (OWNER policy decision — NOT applied here):** the wrapper
escalates a *valid* guard refusal (rc=3) to a hard task failure, identical at the
`LastTaskResult` level to a genuine mechanism crash (rc=2 / build/export failure) — so a
real failure during a hold window would be invisible. One could distinguish a *valid
refusal* as a graceful skip (log `skipped=incident_guard_hold=<codes>` + `return`, like the
existing `FACTORY_OFF.flag` / `factory_mutation_lock_busy` skips at
`run_public_snapshot_task.ps1:29-32,66-69`) while keeping `throw` for guard *errors*
(`valid=False`/rc=2/bad contract). **Trade-off:** this silences the 3-week `LastTaskResult=1`
alarm and would hide legitimate data staleness from task-health monitoring — contrary to the
company's "fail-closed gate without operator looks like backlog" caution. Correct long-term
fix is a separate data-freshness monitor on `public-snapshot.json` `generated_at` age, not
overloading the task exit code. Left for OWNER to decide; deliberately not changed autonomously.

## 6. Rollback

This commit adds only this evidence document (no code/JSON/task-XML change). Rollback:
`git revert <commit-hash>` — pure documentation, zero runtime effect.

## 7. Residual risk

- Public site continues to show 2026-07-28 data until the two holds are resolved. Per the
  `company-operating-model` `stale_data_behavior.ui_label_template`, the site is designed to
  surface stale data with a UI label — so the freeze degrades gracefully rather than serving
  wrong-but-fresh numbers.
- `LastTaskResult=1` persists hourly (benign, expected); it masks any *other* export failure
  that might arise during the hold window (see §5 optional hygiene).
- No change to factory, farm_state, verdicts, or T_Live. Guard remains read-only fail-closed.
