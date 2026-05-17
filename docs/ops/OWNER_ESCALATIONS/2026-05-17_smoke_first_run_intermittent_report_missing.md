---
opened_utc: 2026-05-16T23:47Z
raised_by: Board Advisor (observe wake 23:47Z)
severity: medium
class: test-environment / smoke-runner-flakiness
supersedes_aspect_of: 2026-05-16_codex_deploy_path_mismatch.md (path mismatch was the OLD failure mode; this is the NEW one)
---

# Systemic first-run REPORT_MISSING in `run_smoke.ps1` blocks build_ea at MAX_RETRIES

## Pattern (4 EAs, 4 different symbols/TFs, retry attempts 2–3)

After the deploy-path-mismatch fix landed, `run_smoke.ps1` consistently
hits **REPORT_MISSING on run_01 of each `-Runs 2` smoke session, while
run_02 succeeds with `model4_log_marker_detected: true`**. Because the
runner requires ALL `-Runs N` to be `OK`, a single first-run failure
flips the whole session to FAIL and the build to `blocked`.

Evidence from the latest smoke summaries:

| EA          | symbol/TF      | run_01           | run_02                                     | reason_classes (combined) |
|-------------|----------------|------------------|--------------------------------------------|---------------------------|
| QM5_1045    | SP500.DWX M30  | FAIL REPORT_MISSING | **OK** trades=0, real_ticks_marker=true | REPORT_MISSING, INCOMPLETE_RUNS |
| QM5_1050    | EURUSD.DWX H1  | FAIL REPORT_MISSING | **OK** trades=0, real_ticks_marker=true | REPORT_MISSING, INCOMPLETE_RUNS, MODEL4_MARKER_REQUIRED |
| QM5_1055    | EURUSD.DWX M15 | FAIL REPORT_MISSING | **OK** trades=0, real_ticks_marker=true | REPORT_MISSING, INCOMPLETE_RUNS, MODEL4_MARKER_REQUIRED |
| QM5_1046    | NDX.DWX M30    | FAIL REPORT_MISSING | FAIL REPORT_MISSING + METATESTER_HUNG   | REPORT_MISSING, METATESTER_HUNG, INCOMPLETE_RUNS, MODEL4_MARKER_REQUIRED |

Source files: `D:/QM/reports/smoke/<EA>/<run_tag>/summary.json` (latest dirs).

QM5_1046 is the worst case (both runs fail with metatester process leak
on T1). The other three show a clean **cold-start vs warm-start asymmetry**
— the second run after the first one inside the same smoke invocation
always works.

## Why this matters

The autonomous wake retries build_ea up to `MAX_BUILD_RETRIES = 3`
(`farmctl.py:1573`). All 4 of these EAs have now used 2–3 retries
hitting the same first-run pattern. QM5_1045 is at attempt 3 (terminal,
no further retries). QM5_1046/1050/1055 are at attempt 2.

So even though the EAs compile, deploy correctly to the canonical
`Experts/QM/<EALabel>.ex5` path, and run successfully on the warm run,
they all permanently fail the smoke gate and never enter the backtest
queue. That's 4 EAs lost to a tester-infrastructure flake, not strategy
content.

The autonomous wake at 2026-05-16T23:28Z already identified the systemic
nature ("framework_error … systemic at attempts 2–3 across QM5_1045
SP500/QM5_1046/QM5_1050 FX/QM5_1055 FX") and parked them. New retries
are exhausting fast.

## Likely root cause

`run_smoke.ps1` (`Wait-ForReportExport` line ~701) waits up to 240s
for the tester to write the .htm report. The first tester invocation
after a cold MT5 process state seems to take longer than 240s to
materialize the report — but the second invocation in the same session
inherits a warm cache and finishes inside the window.

The metatester process leak on QM5_1046 is a separate, deeper symptom
of the same first-run failure: when the report wait times out, the
helper kills lingering `metatester64.exe` PIDs (line 720), which
sometimes leaves the terminal in a bad state for the next attempt.

## Fix candidates (NOT executed — framework edits are CTO/Development scope)

Pick one — they're roughly equivalent in effect:

1. **Add a discard-first-run warm-up** in `run_smoke.ps1`: run an extra
   sacrificial tester invocation per smoke session, ignore its result,
   then run the `-Runs N` gate as today. Mirrors how `p2_baseline.py`
   solves "cold-start tester latency" by not gating on the first run.

2. **Per-run retry on REPORT_MISSING**: if any single run fails
   REPORT_MISSING but exit_code=0 and the previous successful run within
   the same session had `real_ticks_marker=true`, retry just that run
   once instead of failing the whole session.

3. **Loosen the all-runs-must-OK gate**: require `>= (Runs-1)` OK and
   at least one OK with `model4_log_marker_detected=true`. Documents
   first-run flakiness as a known infra quirk rather than fighting it.

4. **Bump `Wait-ForReportExport` timeout**: easiest patch, just raises
   `MaxWaitSeconds 240` to 480. Doesn't fix METATESTER_HUNG but probably
   eliminates the cold-start REPORT_MISSING on first run.

(1) is structurally cleanest because it documents the cold-start asymmetry
in code and makes the smoke gate deterministic instead of flaky. (3) is
the smallest diff but adds a fuzzy gate. (4) is the cheapest experiment to
confirm the diagnosis before committing to (1) or (3).

## What this wake did

- Tightened Check 2 self-heal filter in
  `tools/strategy_farm/prompts/board_advisor_observe.md` so observe wakes
  stop firing on build_ea blocked rows whose card already has a downstream
  ea_review / backtest_* done task (forensic tombstones from
  `pump_record_build` path). QM5_1047 and QM5_1048 were two such false
  positives before this commit.
- Wrote this escalation file. Did NOT touch run_smoke.ps1 or
  codex_build_ea.md — framework changes are outside Board Advisor scope.
- Did NOT manually re-queue the 4 blocked EAs. They stay in their
  terminal-or-near-terminal state until the smoke flakiness is resolved
  upstream. Once resolved, OWNER can either:
  - reset the 4 `payload_json.attempt_count` back to 0 in
    `D:/QM/strategy_farm/state/farm_state.sqlite` and let pump retry, or
  - delete the blocked build_ea rows so the next pump cycle creates fresh
    builds from the approved cards.

## Recommended next action

Pick one fix candidate, commit on `agents/cto/*` or as direct OWNER work,
then unblock the 4 EAs above.

## Recurrence log

- **2026-05-17T05:47Z (observe wake)** — fifth EA hit. **QM5_1060**
  (`george-hwang-52w-high`, EURUSD.DWX D1) failed `build_ea` smoke at
  attempt 1 (no prior retries) with `REPORT_MISSING;INCOMPLETE_RUNS` on
  **both** `-Runs 2` invocations (not just `run_01`). Summary:
  `D:/QM/reports/smoke/QM5_1060/20260517_045418/summary.json`
  — `model4_log_marker_detected: false` on both runs, `exit_code: 0`,
  `report_size_bytes: 0`. Same failure mode as QM5_1046 (both-runs-fail
  cluster) rather than the cold-warm asymmetry of QM5_1045/1050/1055.

  Autonomous wake at 2026-05-17T05:17Z correctly identified the systemic
  pattern and recorded the block on first attempt (`autonomous_wakes.log`
  RECORD_BUILD entry: "REPORT_MISSING;INCOMPLETE_RUNS systemic tester-infra
  … chain skipped per Step 2 (blocked)"). No retry exhaustion this time
  — the autonomous wake's pump-record-build path now short-circuits when
  the symptom matches the known systemic failure mode.

  Net: 5 EAs blocked on this issue (QM5_1045 terminal; QM5_1046/1050/1055
  attempt=3 limbo; QM5_1060 attempt=1 blocked). Both-runs-fail cluster grew
  from 1 → 2 EAs. Escalation severity unchanged (medium); fix candidates
  unchanged.

- **2026-05-17T07:48Z (observe wake)** — sixth EA hit. **QM5_1065**
  (`unger-friday-close-reversal-fx`, EURUSD.DWX H1) failed `build_ea` smoke
  at attempt 1 with `REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS` on
  **both** `-Runs 2` invocations. Summary:
  `D:/QM/reports/smoke/QM5_1065/20260517_065351/summary.json` —
  `model4_log_marker_detected: false` on both runs, `exit_code: 0`,
  `report_size_bytes: 0`. Joins QM5_1046 + QM5_1060 in the both-runs-fail
  cluster (now 3 EAs) — METATESTER_HUNG variant of the failure mode rather
  than the cold-warm asymmetry seen on QM5_1045/1050/1055.

  T1 was the smoke runner (per summary.json `terminal: "T1"`). The T1
  tester log `D:/QM/mt5/T1/Tester/logs/20260517.log` shows EURUSD.DWX ticks
  synchronizing and trades executing on `Core 01` at local 09:39:48 (≈ same
  time as the build_ea blocked update at UTC 07:39:18Z), confirming the EA
  itself runs — only the report export fails, consistent with HR7
  `NO_REPORT ≠ EA-Schwäche`.

  Autonomous wake at 2026-05-17T07:17Z handled QM5_1065 via the same
  short-circuit pattern: pump-record-build marked it `blocked` at attempt 1
  rather than wasting 3 retries. No retry-exhaustion churn this round.

  Net: 6 EAs blocked on this issue (QM5_1045 terminal; QM5_1046/1050/1055
  attempt=3 limbo; QM5_1060 attempt=1 blocked; QM5_1065 attempt=1 blocked).
  Both-runs-fail cluster grew from 2 → 3 EAs. Escalation severity unchanged
  (medium); fix candidates unchanged.

- **2026-05-17T08:48Z (observe wake)** — **count jumped 6 → 16 EAs in one
  hour; new failure modes emerged. Severity bumped to HIGH.**

  New blocked since last entry (10 EAs): QM5_1052, QM5_1053, QM5_1058
  (regression — was `done` at 03:25Z with `APPROVE_FOR_BACKTEST`, now
  `blocked` at attempt=3), QM5_1059, QM5_1061, QM5_1062, QM5_1066, QM5_1067,
  QM5_1068, QM5_1070. (QM5_1098 is also blocked but with
  `MIN_TRADES_NOT_MET` — strategy-content failure, not part of this
  escalation.)

  **New failure mode 1 — terminal contention preflight failure.**
  Multiple builds now block with `smoke preflight failed: Terminal
  instance is already running for D:\QM\mt5\T1; no tester report produced`
  (QM5_1058 latest attempt, QM5_1068, earlier QM5_1052 failed-row from
  2026-05-16T19:45Z). This is **not** the cold-start asymmetry — the smoke
  invocation never even starts because another process holds T1's lock.
  Implicates concurrent Codex `build_ea` smoke runs racing each other,
  and/or the backtest dispatcher (`farmctl tick`, Scheduled Task
  `QM_StrategyFarm_Tick_5min`) competing with smoke for the same
  terminal pool. Worth noting: at observe-wake time, `tasklist` showed
  T1 (PID 5420) and T2 (PID 22240) both running (started 08:48:24Z /
  08:48:27Z) — that's the dispatcher kicking off backtests during the
  observe window. There is no documented mutex between smoke and
  dispatcher.

  **New failure mode 2 — T2 affected, run_02 failure (not run_01).**
  QM5_1062 (`unger-inside-day-breakout`, GDAXI.DWX H1 2024) at
  `D:/QM/reports/smoke/QM5_1062/20260517_075617/summary.json` shows
  run_01 OK and run_02 FAIL REPORT_MISSING on **T2**. Reverses the
  original cold-warm asymmetry hypothesis (warm second run is supposed
  to be the reliable one) and extends the failure surface from T1-only
  to T1+T2. The earlier `blocked_reason` for this row mentioned a 900s
  timeout — confirming the wait window is sometimes blown entirely.

  **Regression — QM5_1058.** Same `build_ea` task id (`829365e8`) that
  the autonomous wake recorded `smoke=zero_trades / verdict=
  APPROVE_FOR_BACKTEST` at 03:25Z went `done → blocked` after subsequent
  pump retries (attempt_count now 3). The `backtest_p2` task
  (`59e41aab`) enqueued from the earlier successful run is still
  `pending`. This is an inconsistent state — pipeline shows a queued P2
  for an EA whose underlying build is now marked failed. Either the P2
  task should be cancelled or the build_ea row should be restored to
  `done` (the EA artifact on disk presumably still works since it ran
  green at 03:25Z).

  **Updated count:** 16 EAs blocked on this issue.
  - Cold-warm-asymmetry cluster (run_01 fails, run_02 succeeds):
    QM5_1045 (terminal), QM5_1050, QM5_1055, plus likely subset of newly
    blocked ones (need per-EA inspection)
  - Both-runs-fail cluster: QM5_1046, QM5_1060, QM5_1065, QM5_1068,
    QM5_1058-latest
  - run_02-fails / T2-affected cluster: QM5_1062 (new sub-cluster, n=1)
  - Preflight-already-running cluster: QM5_1058 latest, QM5_1068, plus
    failed-state QM5_1052 from yesterday

  **Updated fix candidates.** All four originals still apply, but
  candidate (1) "add discard-first-run warm-up" no longer covers the
  whole failure surface — would not have caught QM5_1062's run_02
  failure or the preflight contention. Adding:

  5. **Add terminal-pool mutex between smoke and dispatcher.** Smoke
     and `farmctl dispatch-tick` should claim a `D:/QM/strategy_farm/state/terminal_locks/T<N>.lock`
     file (or DB row) before touching `D:/QM/mt5/T<N>`. Whichever runs
     second waits or fails-fast with a clean "terminal busy, defer"
     reason that the pump treats as transient (no attempt_count
     increment), not a framework_error. Eliminates the
     "already running" preflight class and the mid-run interruption
     class.

  6. **Reserve T5 (or T0) as smoke-only.** Lower-effort variant of (5)
     — change smoke runner to always use a specific terminal not in
     the dispatcher pool. Dispatcher continues to use T1–T4. No mutex
     needed, just disjoint resource pools.

  (5) and (6) are about the contention dimension, (1)/(4) are about
  the cold-start dimension. **Both dimensions need addressing**; one
  alone won't unblock the queue.

  **Recommended escalation path.**
  - Severity now HIGH — the pipeline cannot land new EAs to backtest at
    its current rate. 16 of the latest 30 build candidates are stuck
    in `blocked` despite passing compile + content review.
  - OWNER decision needed on: which fix candidate(s) to pick AND
    whether to bulk-reset the 16 blocked rows once the fix lands.
  - Suggest commissioning a one-off CTO/Development worktree task to
    implement (1) + (6) together; (6) is the smallest diff and gives
    immediate isolation, (1) hardens the smoke gate semantics.
  - In the interim, the autonomous wake's pump short-circuit prevents
    retry-churn (good — no wasted Codex calls on the same systemic
    failure) but means no further EAs land in P2 queue until fixed.

  No action this wake other than this recurrence-log update. Smoke
  runner, codex_build_ea prompt, and farmctl all untouched per
  Board-Advisor scope (framework + agent prompts = CTO/Development).

- **2026-05-17T14:50Z (observe wake)** — **fix commits landing; 3 new
  blocks since previous wake but pre-patch.** No new escalation work.

  Smoke-runner patches committed in the last hour, in chronological order:
  - `bb09e964` (14:04Z) — `run_smoke evidence filename collision + try/catch wrap`
  - `8deebf5c` (14:11Z) — `per-terminal deploy in run_smoke (eliminate .ex5 file-lock contention)`
  - `82c9ce68` (14:28Z) — QM5_1087 build via autonomous wake (smoke still framework_error, T1 lock)
  - `be009931` (14:45Z) — `run_smoke worker mortality — full task #014 patch`

  Together these address fix-candidates (5) terminal-pool contention
  and the worker-mortality root cause behind the `METATESTER_HUNG`
  cluster. Per-terminal deploy eliminates the .ex5 file-lock race; the
  worker mortality patch addresses the run_02 / metatester-leak class.

  3 new builds blocked at 14:44:18Z (pre-`be009931` worker-mortality
  patch by ~1 min): QM5_1090, QM5_1091, QM5_1101 — all
  `framework_error REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED`.
  These were attempted under the partially-patched runner. The next
  autonomous wake at 15:17Z will be the first validation of the full
  patch stack on a fresh build.

  Updated counts: 16 build_ea rows still match the self-heal filter as
  real failures (was 16 at previous wake — net flat: QM5_1052/1053/1059/1098
  now have downstream `ea_review`/`backtest_*` progress per filter clause
  (c), and new rows QM5_1090/1091/1101 entered). Cluster composition:
  cold-warm-asymmetry (QM5_1045/1050/1055), both-runs-fail
  (QM5_1046/1060/1065/1066/1067/1068/1070), preflight-already-running
  (QM5_1068 + new), worker-mortality / metatester-hung
  (QM5_1090/1091/1101).

  Severity remains HIGH but trending — patches are landing in real
  time. No Board-Advisor action other than this log entry. Smoke runner
  validation defers to next autonomous wake.

- **2026-05-17T17:51Z (observe wake)** — **post-patch validation arrived;
  smoke patches DID NOT fully resolve. New failure-mode emerged.**

  Codex auth partially recovered since 15:50Z update — recent QM5_1121
  (task `479fce87`) and QM5_1122 (task `d4cb37c0`) builds reached
  attempt 2/3 with `compile_succeeded:true` and smoke summaries written
  (`D:/QM/reports/smoke/QM5_1122/20260517_165513/summary.json` etc.),
  proving Codex `responses_websocket` is currently working (some attempts
  show 0× 401, others still hit 9× 401 — auth flapping). `auth.json`
  `last_refresh` still pinned at `2026-05-17T10:50:35Z`; the silent token
  renewal evidently bypasses that field. **OWNER `codex logout && codex
  login` still recommended** to stabilize, but pipeline is now landing
  fresh post-patch evidence for smoke-runner validation.

  Two new real failures since the 16:49Z observe wake:

  - **QM5_1121** (`unger-corn-trend-h4`, blocked attempt=3, updated
    17:05:07Z) — `compile_one.result=FAIL reason=RUNTIME_EXCEPTION
    errors=-1 file locked during include sync: QM_TradeManagement.mqh`.
    **New failure mode not previously documented in this escalation.**
    Implicates the per-terminal deploy patch (8deebf5c) — concurrent
    builds now sync includes into T1..T5 MQL5 dirs in parallel and race
    on shared include files. Compile fails before smoke ever runs.
    Evidence: `D:/QM/strategy_farm/logs/codex_build_479fce87-b1b1-4660-a8e2-558fc95fe5b2.live.attempt_0.log`
    (28 KB, the include-sync RUNTIME_EXCEPTION first attempt).

  - **QM5_1122** (`unger-crude-donchian160`, failed attempt=3, updated
    17:07:13Z) — `framework_error REPORT_MISSING;INCOMPLETE_RUNS
    report_size_bytes=0 terminal=T1`. **Cold-warm-asymmetry pattern
    continues post-patch.** Build artifacts landed
    (`.ex5`, `.set`, registry rows OK) but smoke session produced no
    report on T1. Evidence: smoke summary path above; codex live log
    `codex_build_d4cb37c0-d36a-499a-adb8-46312942ae9f.live.log`
    (336 KB, completed but classified framework_error).

  Updated counts: **20 real `build_ea` failures** in self-heal filter
  (was 16 at 14:50Z, 18 at 16:49Z with +QM5_1082/1101 preflight,
  +QM5_1121/1122 this wake). Cluster composition:
  - cold-warm-asymmetry (QM5_1045/1050/1055/1122 — QM5_1122 fresh
    post-patch evidence)
  - both-runs-fail (QM5_1046/1060/1065/1066/1067/1070)
  - preflight-already-running (QM5_1068/1082/1101)
  - worker-mortality / metatester-hung (QM5_1090/1091)
  - NEW: file-lock-on-include-sync (QM5_1121) — affects compile, not
    smoke
  - other: QM5_1061/1069/1081 (REPORT_MISSING / NO_REAL_TICKS_MARKER)

  **Fix candidate (7) added — gate include-sync behind a process-wide
  lock.** Either reuse the terminal-pool mutex from candidate (5) so
  only one build at a time syncs into each T<N>/MQL5/Include dir, or
  share a single canonical include dir between terminals (mount/symlink
  D:/QM/repo/framework/include into T1..T5 instead of copying). Without
  this, the 8deebf5c per-terminal deploy patch will keep producing
  RUNTIME_EXCEPTION include-sync races whenever two builds run within
  the same 5-min tick window.

  **Recommended escalation path unchanged** — severity remains HIGH.
  OWNER decision on:
  - which fix candidates to land next ((1) cold-start warm-up, (6) T5
    smoke-only, (7) include-sync mutex)
  - bulk-reset of the 20 blocked rows once stable

  No Board-Advisor action this wake other than this log entry +
  observe_wakes.log line per `no keepalive evidence churn` rule
  (DL-046) — substantive new signal (new failure mode + post-patch
  validation) earns one commit, not a heartbeat ack.
