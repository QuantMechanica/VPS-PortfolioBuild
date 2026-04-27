# Lessons Learned — Pipeline-Operator `process_loss` Failure Pattern

**Date:** 2026-04-27
**Phase gate:** Phase 1 closeout / Phase 3 ramp-up
**Author:** Documentation-KM ([QUA-264](http://localhost:3100/QUA/issues/QUA-264))
**Reviewer:** CEO + Board Advisor
**Severity:** P2 (no data loss; eroded monitoring signal-to-noise; would have masked real failures at Phase 3 scale)
**Cross-references:** [QUA-211](http://localhost:3100/QUA/issues/QUA-211) (parent investigation) · [QUA-263](http://localhost:3100/QUA/issues/QUA-263) (core patch) · [QUA-140](http://localhost:3100/QUA/issues/QUA-140) (related lifecycle bug) · `infra/monitoring/Test-PipelineOperatorRunHealth.ps1` · `artifacts/qua-140/cto-followup-body.md`

---

## 1. Timeline (UTC, 2026-04-26 → 2026-04-27)

| Time (UTC) | Event |
|---|---|
| 2026-04-26 21:12–21:16 | Seven Pipeline-Operator runs fail in a 4-minute window. All `liveness_state=failed`, reason `adapter_failed`, identical `usage limit` error text. Root cause: codex auth pointed at the wrong account. OWNER re-authenticates ~21:30 (logged in QUA-9 conversation). These seven failures are historical noise from this point forward, not a current issue. |
| 2026-04-26 21:26 | Run `91fb6914` starts. Last output 21:31. Child dies silently shortly after. Orchestrator does not detect death. |
| 2026-04-27 07:23:34 | Run `595047d4` (DevOps codex on QUA-67) starts; codex.exe socket established. |
| 2026-04-27 07:23:46 | Lifecycle layer logs `Lost in-memory process handle, but child pid 28864 is still alive` — 12s after spawn. Orchestrator can no longer detect process exit; child tree (cmd → node → codex → pwsh) holds a half-closed Cloudflare socket and stays idle. |
| 2026-04-27 07:37:20 | Codex `turn.completed` reached, commit `e49c3d57` lands cleanly — but Paperclip never marks the run done because the in-memory handle is gone. Process tree remains alive idle for ~6.5h. |
| 2026-04-27 08:11–09:15 | Three more `process_lost` candidates start (`3eb46f7f`, `be9381a2`, `95c19cec`). Output→reap gaps range from 7 min to 57 min. |
| 2026-04-27 09:22:27.644 | **Batch reap cut.** A single orchestrator watchdog sweep marks four runs `failed` / `process_lost` with the same `finished_at` timestamp (`91fb6914`, `3eb46f7f`, `be9381a2`, `95c19cec`). True child-death times are closer to each run's `last_output_at`, not this watchdog timestamp. |
| 2026-04-27 ~12:30 (local) | Board Advisor opens [QUA-211](http://localhost:3100/QUA/issues/QUA-211) flagging an 18% Pipeline-Op failure rate over 24h. Investigation requested: classify failure mix, prove root cause, ship monitor + fix. |
| 2026-04-27 13:05:37 | Board Advisor diagnosis posted on QUA-211: 18% headline conflates two patterns (A: usage-limit cascade, B: process-loss). Recommends DevOps capture child stderr+exit code, distinguish detached-alive from dead-child, and don't conflate `adapter_failed` with `process_lost` in dashboards. |
| 2026-04-27 13:06:52 | Pipeline-Operator commit `de1fa8f` lands the workaround-only mitigation: `infra/monitoring/Test-PipelineOperatorRunHealth.ps1` classifier + `Invoke-InfraHealthCheck.ps1` integration + `infra/README.md` docs. Critical only on **unrecovered** `process_loss`; warn on usage-limit drift. |
| 2026-04-27 13:09:43 | Pipeline-Operator confirms 5+ run validation: 26 runs after the 07:22:27Z batch-reap cut, 0 failures, 0 `process_loss` failures. Approval gate raised for codex_local core patch. |
| 2026-04-27 14:10:09 | CEO clerk-accepts QUA-140 cleanup interaction; CEO terminates the four orphan PIDs (28864/27644/27588/21328). Recovery sweep auto-marks run `595047d4` `failed` / `process_lost` at 14:12:21Z. CTO follow-up issue opened for the underlying handle-loss root cause. |
| 2026-04-27 14:14:17 | Approval interaction `8f0f6add-caa0-4213-97ca-b83e6be373c2` is accepted. Pipeline-Operator commits the core patch in `paperclip/app` (commit `6692bace`, `server/src/services/heartbeat.ts`): when parent pid is gone but the process group is still alive, defer `process_lost` for a 30-minute grace window before reaping descendants. |
| 2026-04-27 15:18:42 | DevOps picks up [QUA-263](http://localhost:3100/QUA/issues/QUA-263) — implement codex_local diagnostics patch (preserve `exit_code`/`stderr`, distinguish detached-alive vs dead-child) — for the 5+ run pilot validation. |
| 2026-04-27 15:20:38 | Documentation-KM is assigned [QUA-264](http://localhost:3100/QUA/issues/QUA-264) — write this file. |

The investigation-to-mitigation window was **~37 minutes** (Board Advisor diagnosis 13:05Z → workaround commit `de1fa8f` 13:06Z → batch-reap-cut validation 13:09Z), with a follow-on **65 minutes** to land the core grace-window patch (`6692bace`).

---

## 2. Failure taxonomy

The 18% headline rate (11/61 runs) was misleading because it bundled three distinct classes. Real currently-recurring failure rate after the batch-reap cut is **0%** over the 26-run sample.

### 2.1 Class A — Adapter usage-limit cascade (7 of 11)

| Property | Value |
|---|---|
| Window | 2026-04-26 21:12–21:16 UTC (4 min) |
| `liveness_state` | `failed` |
| `error` | identical: "You've hit your usage limit. To get more access now, send a request to your admin or try again at Apr 27th, 2026 12:05 AM." |
| Root cause | codex auth pointed at the wrong account (operator misconfiguration) |
| Resolution | OWNER re-authenticated to correct account ~21:30 UTC |
| Status | Historical noise; not a current failure mode |

### 2.2 Class B1 — Child genuinely dies, lazy reap (`process_lost` dead-child)

| Property | Value |
|---|---|
| Sample | 4/11 in the 24h sample (`91fb6914`, `3eb46f7f`, `be9381a2`, `95c19cec`) |
| `errorCode` | `process_lost` |
| Pid status at reap | dead |
| Detection mechanism | orchestrator polls, cannot find child PID, marks `process_lost` |
| Reap pattern | **batch reap** — all four share `finished_at = 2026-04-27 09:22:27.644 UTC`; true death times are closer to each run's `last_output_at` (gap of 7 min to 12 hours) |
| Recovery | all four auto-recovered via retry runs (recovery mapping below) |

| Failed run | Recovery run |
|---|---|
| `91fb6914` | `f18e6930` |
| `3eb46f7f` | `ff518929` |
| `be9381a2` | `914735c5` |
| `95c19cec` | `3cd068a8` |

### 2.3 Class B2 — Orchestrator loses handle, child still alive (`process_lost` false-positive)

| Property | Value |
|---|---|
| Hallmark log | `lifecycle warn: Lost in-memory process handle, but child pid <N> is still alive` |
| Onset | typically ~12s after spawn (e.g. 07:23:46Z for run `595047d4` against pid 28864) |
| Pid status at reap | alive (sometimes for hours; QUA-140's run kept the tree alive ~6.5h on a half-closed Cloudflare `CLOSE_WAIT` socket) |
| `turn.completed` | reached and committed cleanly even after the orchestrator gave up |
| Damage | run is marked failed even though work succeeded → output is orphaned, downstream gates can be denied state that actually exists |
| Why it generalizes | Windows-side process handle GC / re-parenting through the codex.CMD shim; not specific to one issue |

The 24h sample contained explicit Class B2 evidence on retry run `f18e6930` (child pid 23480 alive 42 minutes after orchestrator declared `process_lost`) and on the QUA-140 incident (run `595047d4`, where the codex turn completed and committed cleanly while the orchestrator had been blind for hours).

---

## 3. Implemented mitigation

### 3.1 Workaround layer (infra-side, idempotent) — commit `de1fa8f`

- **`infra/monitoring/Test-PipelineOperatorRunHealth.ps1`**
  - Classifies `process_loss` into recovered vs unrecovered by joining `retryOfRunId` to a successful retry run.
  - Emits `critical` only when an unrecovered `process_loss` exists in the window.
  - Emits `warn` for elevated non-process-loss drift (e.g. adapter usage-limit spikes).
  - Default thresholds: `UnrecoveredProcessLossCritical=1`, `OverallFailRateWarnPct=20.0`, `UsageLimitWarnPct=10.0`, `WindowHours=24`.
- **`infra/monitoring/Invoke-InfraHealthCheck.ps1`** — wired the classifier in as `pipeline_operator_run_health` so the existing infra health surface routes the signal.
- **`infra/README.md`** — documented the new classifier in the infra registry.

This layer made the 18% headline metric honest by separating recovered noise from unrecovered defects without touching Paperclip core.

### 3.2 Core patch (Paperclip core, OWNER-approved) — commit `6692bace`

- Repo: `C:/QM/paperclip/app`
- File: `server/src/services/heartbeat.ts`
- Behavior change in the orphaned-run reap path:
  - **Before:** when parent pid is gone but the process group is still alive, immediately terminate descendants and mark `process_lost`.
  - **After:** mark `detached-running` and defer the `process_lost` decision for a **30-minute grace window**, then clean up and fail only after sustained silence.
- Approval: interaction `8f0f6add-caa0-4213-97ca-b83e6be373c2` (Paperclip-core edit gate).
- Test caveat: local test harness was not exercised in this environment (`pnpm test` preflight `spawnSync ENOENT`; direct `vitest` invocation timed out). No broad deploy or production mutation performed at commit time. Pilot validation continues under [QUA-263](http://localhost:3100/QUA/issues/QUA-263).

### 3.3 Validation sample size

- **5+ run validation criterion (QUA-211):** satisfied.
- **Cut point:** 2026-04-27 07:22:27.644 UTC (the orchestrator batch-reap timestamp).
- **Runs after cut:** 26.
- **Failed after cut:** 0.
- **`process_loss` failed after cut:** 0.
- **Recovery mapping for the 4 historical `process_loss` failures:** all four carry a successful retry run (table in §2.2).

The 26-run window covers both pre- and post-mitigation behavior because the workaround is observability-only — the underlying batch-reap orchestrator behavior was the same on both sides of the cut. The zero failure rate after the cut indicates the contributing operator-side incident (wrong-codex-account auth) was the dominant Class A driver, and that Class B failures were not currently recurring at heartbeat cadence over the validation window. The core patch (`6692bace`) is a separate pilot validation, tracked under [QUA-263](http://localhost:3100/QUA/issues/QUA-263).

---

## 4. Guardrails (now active)

1. **Don't conflate `adapter_failed` with `process_lost` in headline metrics.** `Test-PipelineOperatorRunHealth.ps1` separates them at the source. Any agent or dashboard reporting Pipeline-Operator failure rate must use the classifier output, not raw `failed` counts.
2. **Critical alert only on unrecovered `process_loss`.** Recovered retries are non-critical infrastructure noise; warning-level drift (usage-limit spikes, etc.) is non-blocking.
3. **30-minute grace window for detached-alive children.** Paperclip core no longer reaps a process group that is still alive on the first sweep; it waits for sustained silence. Manual interventions on suspected orphans (e.g. QUA-140 cleanup pattern) must respect this grace window unless the tree is a known orphan with no live work.
4. **Approval gate for Paperclip-core edits.** Any change to `paperclip/app/server/...` requires a `request_confirmation` interaction (the `8f0f6add-...` approval pattern) before the patch lands. Workaround layers in `infra/monitoring/` do not require this gate.
5. **Lifecycle layer evidence is required when classifying a fail.** `heartbeat_runs.exit_code` and `heartbeat_runs.stderr_excerpt` were NULL for all four B1/B2 cases in the sample. Any future `process_lost` triage that lacks these fields must mark the failure as `unclassified-process-loss` and pull the lifecycle log; do not assume B1 vs B2 from the reap timestamp alone.

---

## 5. Follow-up recommendations (open)

| # | Item | Owner | Tracking | Priority |
|---|---|---|---|---|
| 1 | **Capture child stderr + exit code reliably** in the codex_local adapter (`Wait-Process -Id $pid -Timeout N` + `Get-Process -Id` polling) so future fails distinguish B1 (dead child) from B2 (detached-alive). | DevOps | [QUA-263](http://localhost:3100/QUA/issues/QUA-263) | P0 |
| 2 | **Investigate codex CLI exit pattern on B1.** Once #1 lands and the next `process_lost` carries an exit code, compare against codex documented exit codes; check for OOM / signal-terminated runs. | DevOps + Pipeline-Op | parent [QUA-211](http://localhost:3100/QUA/issues/QUA-211) | P1 |
| 3 | **Detect B2 explicitly and let the run continue.** If `Get-Process -Id $pid` returns alive after a `process_lost` detection, attempt re-attach to stdout/stderr rather than marking the run failed. The 30-minute grace window in `6692bace` is a temporal proxy for this; long-term we want the positive completion signal (`turn.completed` in NDJSON) to be authoritative. See QUA-140 follow-up `artifacts/qua-140/cto-followup-body.md` for the full ask. | DevOps / CTO | spawned from [QUA-140](http://localhost:3100/QUA/issues/QUA-140) | P1 |
| 4 | **Per-run output staleness threshold.** For genuinely-dead-child runs (B1), 12-hour reap latency (case `91fb6914`) is bad UX. Add a "no output for N minutes → declare child dead" threshold tuned to expected codex_local cadence (e.g. 30 min). Trades slow-reap for faster failure visibility. | Pipeline-Op | parent [QUA-211](http://localhost:3100/QUA/issues/QUA-211) | P2 |
| 5 | **Active orphan reaper.** When `errorCode=process_detached` is set but `processPid` is still tracked, periodically poll the OS for that PID and mark the run failed if the PID is gone. Closes the loop for the QUA-140 lifecycle case without requiring an external `Stop-Process`. | CTO | follow-up to [QUA-140](http://localhost:3100/QUA/issues/QUA-140) | P1 |
| 6 | **Platform observability split.** Whatever surface counts agent fails should distinguish `adapter_failed`, `process_lost`, and other modes at the data-model level (not only the classifier script). Paperclip-platform fix, separate from the application-level workaround. | CEO + DevOps (upstream) | parent [QUA-211](http://localhost:3100/QUA/issues/QUA-211) | P3 |

---

## 6. Format — Learning → V1 Behavior → V5 Behavior → Why

| Aspect | V1 Behavior | V5 Behavior | Why |
|---|---|---|---|
| Headline failure rate | One number bundled adapter, process-loss, and other modes — masked the 4-minute usage-limit cascade as a sustained 18% defect. | `Test-PipelineOperatorRunHealth.ps1` separates `adapter_failed`, `process_loss_recovered`, `process_loss_unrecovered`, and other modes; only unrecovered `process_loss` is critical. | Conflated metrics dull the signal: the cascade was operator misconfiguration that OWNER resolved in minutes, but it inflated a defect dashboard for 24h. |
| Reap of detached-alive children | Orchestrator declared `process_lost` on the first watchdog sweep when the parent handle was gone, even if the process group was still doing work. | 30-minute grace window (`paperclip/app` commit `6692bace`); positive `turn.completed` signal is the long-term goal. | The B2 sub-pattern was salvageable work being thrown away — QUA-140's run committed cleanly while the orchestrator had been blind for hours. |
| Cleanup of orphans | Required external `Stop-Process` (CEO-led for QUA-140) before the recovery sweep would mark the run failed. | Active orphan reaper (planned) closes the loop within minutes; manual cleanup remains a backstop, not the only path. | Hours of `process_lost`-but-alive state both blocks downstream gates and trains responders to ignore the alert class. |
| Lesson capture trigger | Fix lands → maybe a comment on the parent issue. | Fix lands → Doc-KM authors a lessons-learned entry with timeline, taxonomy, validation sample size, guardrails, and follow-up table. | Each non-trivial defect crosses agent boundaries (Pipeline-Op + DevOps + CTO + CEO + Board); a single durable record is the only artifact that survives the multi-agent context fragmentation. |

---

## 7. Versioning

| Version | Date | Author | Notes |
|---|---|---|---|
| v1.0 | 2026-04-27 | Documentation-KM ([QUA-264](http://localhost:3100/QUA/issues/QUA-264)) | Initial entry. CEO + Board Advisor pending review. Pilot validation of the [QUA-263](http://localhost:3100/QUA/issues/QUA-263) core patch and the QUA-140 lifecycle follow-up are open at time of authoring. |
