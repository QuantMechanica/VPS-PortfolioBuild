---
opened_utc: 2026-05-16T10:00Z
raised_by: Board Advisor (observe wake)
severity: medium
class: codex-build-quality + autonomous-wake-reliability
---

# Residual after observe wake fix at 2026-05-16T10:00Z

Observe wake fix committed: `84e61a51 fix(strategy_farm): restore 1047 rows in MagicResolver, harden Codex build prompt via observe wake 2026-05-16T10:00Z`.

Two follow-ups OWNER (or the next autonomous wake) needs to make decisions on:

## 1. QM5_1047 build task still `blocked`

Task `73653753-8d6b-411f-bc59-a6221c0b250a` is in `status=blocked` with `blocked_reason: "smoke framework_error: REPORT_MISSING;INCOMPLETE_RUNS"`. The upstream cause (missing 1047 rows in `QM_MagicResolver.mqh`) is now fixed in source. To retry:

1. Recompile `framework/EAs/QM5_1047_halloween-sell-in-may-idx/QM5_1047_halloween-sell-in-may-idx.mq5` against the fixed resolver. The deployed `.ex5` in `D:/QM/mt5/T1/MQL5/Experts/QM5_1047_halloween-sell-in-may-idx/` (built 2026-05-16 12:46 local) is stale and will still fail OnInit.
2. Unblock the task via SQL or farmctl (the autonomous wake does NOT currently auto-retry blocked tasks):
   ```
   sqlite3 D:/QM/strategy_farm/state/farm_state.sqlite \
     "UPDATE tasks SET status='pending', updated_at=datetime('now') WHERE id='73653753-8d6b-411f-bc59-a6221c0b250a'"
   ```
3. Let the next autonomous wake run the build (it will redo compile + smoke). If smoke passes, the build flows on to ea_review.

Board Advisor did NOT unblock the task — that's an operational decision (re-running a build burns ~15 min of Codex; OWNER may want to inspect the other 2 blocked tasks first).

The smoke detector also has a small bug: `oninit_failure_detected: false` was reported even though tester log shows `tester stopped because OnInit returns non-zero code 1`. Detector should grep for that exact string in `D:/QM/mt5/T<n>/Tester/logs/<date>.log`. Low priority — file under build-tooling backlog.

## 2. Three consecutive autonomous wakes exited `-1`

```
2026-05-16T08:44:35Z WAKE_INVOKED ... 2026-05-16T09:08:03Z WAKE_EXITED exit=-1
2026-05-16T09:09:11Z WAKE_INVOKED ... 2026-05-16T09:37:23Z WAKE_EXITED exit=-1
2026-05-16T09:38:37Z WAKE_INVOKED ... 2026-05-16T09:57:23Z WAKE_EXITED exit=-1
```

The 08:17Z wake exited `0`; the 08:44Z onward sequence is `-1`. Coincides with the broken-resolver build attempts. Likely the wake failed mid-pipeline (Codex returned framework_error, the wake didn't commit its in-flight work, and `claude -p` propagated a non-zero exit).

Evidence: working-tree has uncommitted Codex artifacts that should have been committed by their wakes:
- `framework/scripts/{gen_setfile.ps1, mt5_worker.py, phase_orchestrator.py, verify_build_deployment.py}` — modified/added but uncommitted
- `tools/strategy_farm/farmctl.py` — modified
- `framework/registry/ea_id_registry.csv` — 1050 added, 1046 removed (consistent with `_obsolete_QM5_1046_*` dir rename, but the rename + CSV removal need committing together with rationale)
- `framework/EAs/{QM5_1006_davey-eu-day, QM5_1047_*, QM5_1050_*, QM5_SRC02_S09_chan_audcad_mr, _obsolete_QM5_1046_*}` — untracked dirs
- Various `docs/ops/evidence/` files

Board Advisor did NOT commit these — they belong to Codex/CTO/Pipeline-Operator scope and need their context (especially the 1046 obsoletion rationale and farmctl.py changes).

Recommended action: have the next autonomous wake's bookkeeping step audit `git status` and commit its own work before exit, instead of leaving it in working tree. This is a structural reliability issue — re-introduce in the autonomous_loop prompt as an explicit pre-exit checklist.

## Disposition

- Resolver source + Codex prompt: FIXED + committed (`84e61a51`).
- QM5_1047 .ex5 rebuild + task unblock: deferred to operator.
- Wake exit=-1 root cause + uncommitted-artifacts hygiene: deferred to OWNER for autonomous_loop redesign discussion.

## Amendment 2026-05-16T11:48Z (Board Advisor observe wake)

`QM_StrategyFarm_AutonomousWake_Hourly` is now `State: Disabled` with `NumberOfMissedRuns: 2` (10:17Z + 11:17Z fires skipped). LastTaskResult=0 at 09:38Z so the wrapper exited cleanly even though the wake-internal exit was -1. Assuming this is an intentional OWNER pause pending the autonomous_loop redesign — no re-enable performed per observe-wake boundaries. Two long-lived `claude.exe` orphans (PIDs 27508 from 2026-05-15T10:38Z and 8940 from 2026-05-15T18:21Z) noted but left alone (predate strategy_farm and prior observe wakes accepted them).
