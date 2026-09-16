# RECEIPT — OWNER-DEC-REQUEUE-LIFT-20260916 (both parts)

Operator: `kimi-interim` · Date (UTC): 2026-09-16 · Repo: `C:\QM\repo`

## D2A — QM5_11561 — EXECUTED

| Step | Result |
|---|---|
| Exclusion lift | `c08d677e…f84a` → `3f092f0a…f3f3` (only the `QM5_11561` line removed; backup `requeue_excluded_eas.txt.before_D2A_lift`, hash-bound) |
| Enqueue | `enqueued: true`; task `3262b0b1-86f4-4edb-aed8-30bb2ba77584`; work item **`132aca67-b907-4d34-a232-cf972de4fb32`** (USDJPY.DWX D1) |
| Claim | Worker **T8** claimed 3 s after enqueue; worker PID **10960**, tester child PID **21040** |
| Terminal outcome | Q02 **done/PASS** at 06:32:47Z — Model 4 (Every Real Tick), 1 run exit 0, deterministic; evidence `D:\QM\reports\work_items\132aca67-…\summary.json`; recorded economics net −31 256 / PF 0.86 (economic gates come later) |
| History | Zero prior work items; no verdict rewritten |
| Fanout decision | n/a (single-symbol EA; one work item) |
| STOP | none |

## D2B — QM5_11731 — STOP, NO STATE CHANGE

- Exclusion **not** lifted (file hash unchanged at D2A after-hash; `QM5_11731` line intact).
- Nothing enqueued; no factory DB writes.
- Cause: no legitimate single-symbol Q02 scope exists in the tool for this EA's state —
  `--target-symbol` is universe-expansion-only (needs a native Q02 PASS parent);
  `intake-first-q02` (the governed EURUSD canary path) needs a done/`COMPILE_OK`
  `COMPILE_EA` work item that does not exist; the canonical review enqueue would
  fan out all 4 symbols, violating the pilot condition.
- Unblock options documented in `QM5_11731_receipt.md` (compile→intake canary, or OWNER-
  ratified scoped enqueue). Pilot verification (a–e) and fanout were therefore not reached.

## D2B continuation — QM5_11731 — STOP at step 1 (2026-09-16, 06:54Z)

- Provider mandate resolved: deterministic local MetaEditor compile is the COMPILE_EA
  provider; codex is **not** mandated (build_check.ps1 → compile_one.ps1; the codex lane
  is authoring-only and already done for this EA).
- The authorized path `enqueue-compile → COMPILE_EA claim → intake-first-q02` is blocked
  at step 1: the candidate guards refuse `EX5_ALREADY_PRESENT` + `BUILD_TASK_EXISTS`, and
  no legitimate waiver exists for QM5_11731 (not in any force-rebuild allowlist; no
  source-repair registration; build task `1a17f439-…` is `done` so `--build-task-id`
  binding refuses it as not open).
- No state change: exclusion file still at D2A after-hash `3f092f0a…f3f3` with the
  `QM5_11731` line intact; zero work items; no DB writes; no terminal touched.
- Detail: `QM5_11731_D2B_continuation_RECEIPT.md` + `d2b_continuation_enqueue_compile_dry_run.json`.
  Unblock requires an OWNER-ratified force-rebuild/source-repair authority or a scoped
  single-symbol enqueue variant (the option-(b) code+decision change).

## D4 — QM5_11731 — EXECUTED (2026-09-16, 11:45–12:23Z)

| Step | Result |
|---|---|
| Authority | `OWNER-DEC-REQUEUE-LIFT-20260916-D4` registered (document-bound force-rebuild wave, QM5_11731 only) — commit `98207717da` |
| Compile | COMPILE_EA **`528c42c5-bd83-46d1-ab2c-954cb1669c0b`** done/COMPILE_OK 11:58:27Z, 0E/0W, hardening PASS, new ex5 identity `6e6fbf44…` (worker T3); old ex5/build task untouched |
| Incident | 12:00:23Z ambient `clean_repo_worktree -RestoreTrackedEx5` reverted worktree ex5; fresh bytes recovered from the sweep's own archive (`C:\QM\archive\repo-dirty-20260916T120023Z`); intake hash guard correctly refused while stale |
| Lift | `3f092f0a…f3f3` → `a614bfc2…682a`, only the `QM5_11731` line, backup + `d4_lift_hashes.json` |
| Canary | `intake-first-q02` → ONE row **`55d28c4a-75fd-4084-9444-18666b364dc5`** (EURUSD.DWX M5, `qm-q02-canary-fanout/v1`); claimed T1→T4; done/PASS 12:17:31Z; pilot a–e CLEAN (Model-4 Every Real Tick, deterministic, 1,784 trades, hashes stable); economics net −99,123 / PF 0.65 recorded for later gates |
| Fanout | `sweep_enqueue_built_eas.py --apply --ea QM5_11731` (RELEASE decision) promoted GBPUSD/USDCHF/USDJPY — rows `5b514f67…`/`bb70676c…`/`9e3b0a5a…`, claimed T10/T8/T7, all bound to ex5 `6e6fbf44…` |
| STOP | none — detail `QM5_11731_D4_execution_RECEIPT.md` |

## Files

- `QM5_11561_receipt.md` — D2A detail
- `QM5_11731_receipt.md` — D2B STOP detail with code references
- `QM5_11731_D2B_continuation_RECEIPT.md` — D2B continuation STOP (provider mandate + guard refusal)
- `OWNER-DEC-REQUEUE-LIFT-20260916-D4_QM5_11731_force_rebuild.md` — D4 decision document (code-bound)
- `QM5_11731_D4_authority_registration_RECEIPT.md` — D4 authority registration + verification
- `QM5_11731_D4_execution_RECEIPT.md` — D4 full execution report
- `d4_enqueue_result.json` / `d4_release_wave.json` / `d4_intake_result.json` — machine-readable step records
- `d4_lift_hashes.json` — machine-readable lift record
- `d4_canary_monitor.log` — canary status transitions
- `requeue_excluded_eas.txt.before_D4_lift` — backup of prior exclusion-file bytes
- `d2a_enqueue_result.json` — raw enqueue output
- `d2a_lift_hashes.json` — machine-readable D2A lift record
- `d2b_continuation_enqueue_compile_dry_run.json` — machine-readable enqueue-compile refusal
- `requeue_excluded_eas.txt.before_D2A_lift` — backup of prior exclusion-file bytes
