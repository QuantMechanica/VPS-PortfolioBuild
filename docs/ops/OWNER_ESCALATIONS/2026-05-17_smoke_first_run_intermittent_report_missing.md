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

- **2026-05-17T20:47Z (observe wake)** — **cluster 20 → 25; one new
  parser-variant joins the bucket list; autonomous wake pump-cap working
  as designed.**

  Five new real failures since the 17:51Z update, all at `attempt_count=3`
  (terminal — pump cap reached) per task payloads, last touched
  2026-05-17T20:40:14Z by the pump:

  - **QM5_1117** (`unger-bund-momentum-pullback`, failed attempt=3,
    updated 20:40:14Z) — `framework_error run_smoke report parsing
    failed: no summary.json; parser hit empty Html while reading Expert
    metric`. **New parser-side variant.** Smoke produced raw artifacts
    `D:/QM/reports/smoke/QM5_1117/20260517_201442/raw/run_01/{tester.ini}`
    (no report.htm — cold start empty) and `run_02/{20260517.log,
    report.htm, tester.ini}` (warm run produced report). But the parser
    itself raised reading the empty run_01 HTML instead of cleanly
    classifying REPORT_MISSING, so `summary.json` never landed. This is
    the SAME cold-warm asymmetry underneath but exposes a defensive-
    coding gap in the report parser: it should emit REPORT_MISSING when
    Expert-metric HTML is empty, not crash.
  - **QM5_1118** — `REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS;
    MODEL4_MARKER_REQUIRED` → joins **worker-mortality / metatester-hung**
    bucket.
  - **QM5_1123** — `run_smoke aborted before tester launch: T1 terminal
    instance already running` → joins **preflight-already-running**
    bucket.
  - **QM5_1149** — `REPORT_MISSING;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED`
    → joins **cold-warm-asymmetry** bucket.
  - **QM5_1159** — `T1 terminal already running before tester launch` →
    joins **preflight-already-running** bucket.

  Updated counts: **25 real `build_ea` failures** in self-heal filter
  (was 20 at 17:51Z). All five new entries hit pump cap at attempt=3
  exactly as designed — `19:25Z` autonomous-wake summary already flagged
  `1117/1118/1123/1149/1159` as "framework_error smoke … cycling via
  pump section 2; pump will naturally cap at attempt>3", and that's
  what happened. Pump self-limiting **confirmed functional**.

  Cluster composition (cumulative, all attempt=3 terminal):
  - cold-warm-asymmetry: QM5_1045/1050/1055/1122/**1149**
  - both-runs-fail: QM5_1046/1060/1065/1066/1067/1070
  - preflight-already-running: QM5_1068/1082/1101/**1123**/**1159**
  - worker-mortality / metatester-hung: QM5_1090/1091/**1118**
  - file-lock-on-include-sync: QM5_1121
  - parser-empty-html-not-classified: **QM5_1117** *(new bucket)*
  - other (REPORT_MISSING / NO_REAL_TICKS_MARKER): QM5_1061/1069/1081

  **New fix candidate (8) — defensive parser fallback.** When
  `run_smoke.ps1`'s report-parser encounters an empty Expert-metric
  HTML cell, classify as `REPORT_MISSING` (or `EMPTY_REPORT`) rather
  than raising. This is a one-file change (the parser script) that
  doesn't require any concurrency/locking work and would cleanly fold
  QM5_1117 into the existing REPORT_MISSING bucket the rest of the
  pipeline already handles. Smallest blast radius of the 8 fix
  candidates so far.

  **Recommended escalation path unchanged** — severity remains HIGH but
  cluster growth rate is slowing (4 new 14:50→16:49, 2 new 16:49→17:51,
  5 new 17:51→20:47 over a longer window). OWNER decision on fix-pick
  order still pending; this addendum exists to record the 25-card mark
  + new parser variant + pump-cap confirmation, not to re-raise
  severity. Per DL-046, no further keepalive churn until either (a) a
  new failure-mode bucket emerges, (b) cluster crosses 30, or (c)
  OWNER picks a fix candidate.

- **2026-05-18T08:50Z (observe wake)** — **cluster 25 → 28; NEW bucket
  `data-history-missing` emerges with QM5_1132 + QM5_1133 (regression);
  parser-empty bucket grows by 2 (QM5_1119, QM5_1142).** Commit
  trigger: condition (a) new failure-mode bucket.

  Three new real failures since the 20:47Z update:

  - **QM5_1132** (`qp-futures-weekly-reversal`, blocked attempt=3,
    updated 08:44:18Z) — `framework_error NO_HISTORY;INCOMPLETE_RUNS on
    EURUSD.DWX H1 2024 T1; Model 4 marker present, OnInit failure
    false`. Smoke summary
    `D:/QM/reports/smoke/QM5_1132/20260518_083922/summary.json` records
    `model4_log_marker_detected: true`, `oninit_failure_detected:
    false`, `report_size_bytes: 30438` (report actually exported!),
    `runs[0].status: INVALID`, `invalid_report_reasons:
    [NO_HISTORY_LOG]`, `total_trades: 0`. So unlike REPORT_MISSING
    cluster — here the tester ran, the EA initialized, the report was
    produced and parsed, but the parser's history-context check
    rejected it. Note the symbol name is `qp-futures-weekly-reversal`:
    on H1 chart, weekly-bar logic requires substantially more
    lookback than the smoke window provides. Plausible root cause:
    EA-side `Copy*` call for weekly bars returns insufficient bars
    and the EA emits the log line that the smoke parser classifies as
    `NO_HISTORY_LOG`.

  - **QM5_1133** (`qp-country-etf-pairs`, blocked attempt=1, updated
    08:44:18Z) — `framework_error smoke NO_HISTORY;INCOMPLETE_RUNS on
    NDX.DWX D1 2024 T1; invalid_report_reasons=BARS_ZERO,
    NO_HISTORY_LOG, HISTORY_CONTEXT_INVALID; OnInit failure=false;
    Model4 marker=true`. **Regression** — same EA, same symbol/TF
    successfully smoked at 2026-05-17T16:34:20Z (build_ea task
    `done`, downstream ea_review + backtest_p2 both `done` as of
    early today). Re-attempted today and now blocked. This rules out
    "the EA structurally can't get its history" — yesterday's
    successful smoke proves the data is loadable. The smoke summary
    `D:/QM/reports/smoke/QM5_1133/20260518_083942/summary.json`
    shows both runs of yesterday's pattern failing today with
    NO_HISTORY_LOG. Both invocations within the same retry budget
    failed identically — not the cold-warm asymmetry shape.

  - **QM5_1119** (`pruitt-cl-volatility-breakout-h1`, failed
    attempt=3, updated 08:43:06Z) — `framework_error run_smoke parser
    failed after single Model 4 smoke: Get-ReportMetricValue Text
    empty; raw report
    D:\QM\reports\smoke\QM5_1119\20260518_080612\raw\run_01\report.htm`.
    Same shape as QM5_1117 (parser-empty-html-not-classified bucket).

  - **QM5_1142** (`unger-bund-volatility-pullback`, failed attempt=3,
    updated 08:43:06Z) — `framework_error run_smoke parser crashed:
    Get-ReportMetricValue Expert empty string; summary.json not
    emitted`. Same shape as QM5_1117. Joins
    parser-empty-html-not-classified bucket.

  Updated counts: **28 real `build_ea` failures** in self-heal filter
  (was 25 at 20:47Z, +3 net). Cluster composition:
  - cold-warm-asymmetry: QM5_1045/1050/1055/1122/1149
  - both-runs-fail: QM5_1046/1060/1065/1066/1067/1070
  - preflight-already-running: QM5_1068/1082/1101/1123/1159
  - worker-mortality / metatester-hung: QM5_1090/1091/1118
  - file-lock-on-include-sync: QM5_1121
  - parser-empty-html-not-classified: QM5_1117/**1119**/**1142**
  - **data-history-missing**: **QM5_1132** / **QM5_1133** *(new bucket)*
  - other (REPORT_MISSING / NO_REAL_TICKS_MARKER): QM5_1061/1069/1081

  **New fix candidate (9) — handle NO_HISTORY_LOG separately from
  framework_error.** Two distinct sub-cases the smoke runner cannot
  currently distinguish:

  - **9a EA-side request exceeds available history.** If the EA's
    own `Copy*` (e.g. weekly-bar lookback on H1) returns
    insufficient bars within the smoke window, that's an EA-design
    flaw, not infrastructure flake. Smoke should classify it as
    `EA_HISTORY_REQUIREMENT_EXCEEDS_SMOKE_WINDOW` and treat as a
    permanent strategy-content reject (no retry), not `blocked`. QM5_1132
    is the candidate here (weekly-reversal on H1 chart).
  - **9b Tester state flake.** If the EA successfully smoked
    previously on the same symbol/TF but later fails with
    NO_HISTORY_LOG, classify as `TESTER_HISTORY_NOT_LOADED` and
    retry on a different terminal. QM5_1133 (proven-good yesterday,
    same symbol/TF NO_HISTORY today) is the candidate here.

  The smoke parser already distinguishes
  `invalid_report_reasons=[BARS_ZERO, NO_HISTORY_LOG,
  HISTORY_CONTEXT_INVALID]` vs `[NO_HISTORY_LOG]` only — the
  difference between QM5_1132 (one reason) and QM5_1133 (three
  reasons including BARS_ZERO) is the signal. BARS_ZERO suggests
  tester refused to load any bars (state flake); NO_HISTORY_LOG
  alone with positive trade-search activity suggests EA-side
  Copy* shortfall.

  **Recommended escalation path.** Severity remains HIGH but trend
  is stabilizing: cluster grew +3 over ~12h (vs +5 in the previous
  3h window), and the autonomous wake's pump cap continues to
  prevent retry churn. OWNER decision still pending on fix-pick
  order — adding (9a/9b) to the candidate list does not change the
  recommendation that (5) terminal-pool mutex + (1) cold-start
  warm-up remain the highest-leverage two-fix bundle. Per DL-046,
  no further keepalive churn until either (a) yet another new
  bucket, (b) cluster crosses 30, or (c) OWNER picks a fix
  candidate.

- **2026-05-18T13:00Z (observe wake)** — **threshold-crossed: 28 →
  32 rows / 31 distinct EAs (>30 gate met); three genuinely new
  failures today at 12:07Z, QM5_1133 self-healed.**

  Self-heal filter on `farm_state.sqlite` now returns 32 real
  `build_ea` failure rows. Net delta vs the 08:50Z 28-tally:

  - **+QM5_1093** (failed attempt=3, 2026-05-18T12:07:13Z) —
    `framework_error REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS`.
    Joins **worker-mortality / metatester-hung** bucket.
  - **+QM5_1094** (failed attempt=3, 2026-05-18T12:07:13Z) —
    `smoke runtime infeasible — run_smoke produced no report or
    summary.json under D:\QM\reports\smoke\QM5_1094\20260518_112813
    within wall-time budget`. Joins **both-runs-fail** bucket.
  - **+QM5_1095** (failed attempt=3, 2026-05-18T12:07:13Z) —
    `framework_error REPORT_MISSING;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED`.
    Joins **both-runs-fail** bucket.
  - **+QM5_1062** (failed attempt=3, 2026-05-17T09:07:13Z) — was
    visible in earlier 16-count "run_02-fails / T2-affected" sub-
    cluster but dropped from the 20/25/28 cluster compositions;
    re-counted here under **other (REPORT_MISSING / timeout)**.
    `framework_error smoke runtime timeout after 900s on GDAXI.DWX
    H1 2024 T2; run_02 incomplete and no summary.json emitted`.
  - **+QM5_1119** second row — fresh `framework_error
    REPORT_MISSING;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED` failed
    attempt=3 at 12:07:13Z. The original parser-empty-html row
    (08:43:06Z) is still in the filter; EA now exhibits two distinct
    failure modes on consecutive attempts (parser → REPORT_MISSING).
  - **−QM5_1133** — `done` sibling now exists (2026-05-17T16:34:20Z
    attempt=1), so self-heal excludes both the failed (NO_HISTORY,
    11:07Z) and pending (12:09Z) sibling rows. Removed from
    cluster. The "data-history-missing" bucket reduces to QM5_1132
    alone — confirming the (9b) "tester state flake" sub-case is
    genuinely transient on this strategy / re-classify low-confidence.

  Updated cluster composition (31 distinct EAs, 32 rows):
  - cold-warm-asymmetry (5): QM5_1045/1050/1055/1122/1149
  - both-runs-fail (8): QM5_1046/1060/1065/1066/1067/1070/**1094**/**1095**
  - preflight-already-running (5): QM5_1068/1082/1101/1123/1159
  - worker-mortality / metatester-hung (4): QM5_1090/1091/1118/**1093**
  - file-lock-on-include-sync (1): QM5_1121
  - parser-empty-html-not-classified (3): QM5_1117/1119/1142  *(1119 also contributes a second row in REPORT_MISSING bucket)*
  - data-history-missing (1): QM5_1132  *(QM5_1133 self-healed)*
  - other (REPORT_MISSING / timeout / NO_REAL_TICKS_MARKER) (4):
    QM5_1061/1069/1081/**1062**

  **No new failure-mode bucket.** All three additions land in the
  two largest pre-existing buckets (both-runs-fail and
  worker-mortality), reinforcing — not reshaping — the prioritization.
  The (5) terminal-pool mutex + (1) cold-start warm-up two-fix
  bundle remains the recommended highest-leverage intervention; no
  re-ordering required.

  Growth rate: cluster grew +3 distinct EAs over ~4h (28 → 31), a
  modest acceleration vs the +3-in-12h preceding window. The pump
  cap continues to hold (no retry-storm; all new failures landed at
  attempt=3 in a single dispatcher tick at 12:07:13Z, then halted).

  Per DL-046, this is the threshold-triggered update; next update
  gated again until either (a) yet another new failure-mode bucket
  beyond the eight listed, (b) cluster crosses 40 distinct EAs, or
  (c) OWNER picks a fix candidate.

- **2026-05-18T15:47Z (observe wake)** — **NEW bucket (9)
  `run_smoke_invocation_missing_params` emerges (QM5_1104);
  distinct-EA count unchanged at 31; terminal64 spawn-watchdog patch
  (4dbe855d, 15:20:53Z) landed but pre-validation window.** Commit
  trigger: condition (a) new failure-mode bucket.

  Nine `build_ea` rows updated since the 13:00Z snapshot (all
  status=pending — these are pump retries that haven't yet hit
  attempt cap, so the self-heal filter does not count them; cluster
  remains 32 rows / 31 distinct EAs):

  - **QM5_1104** (`qp-country-bab`, NDX.DWX H1 2024, attempt=3,
    14:09:18Z) — `framework_error run_smoke.ps1 missing mandatory
    parameters: Symbol Year`. **Not in any of the 8 documented
    buckets.** The latest successful smoke artifact
    `D:/QM/reports/smoke/QM5_1104/20260518_115826/summary.json` (at
    12:02Z) shows the smoke harness was invoked correctly with
    symbol/year and produced a NO_HISTORY result. The 14:09Z DB
    update therefore reflects a later, separate invocation where the
    pump dispatched `run_smoke.ps1` without `-Symbol`/`-Year`. This
    is a deterministic invocation bug in the pump retry path — not
    a tester flake — and retries will not self-heal it.

  - **QM5_1103** (`qp-country-low-vol`, NDX.DWX, attempt=3,
    14:09:18Z) and **QM5_1134** (re-attempt after yesterday's done
    at 19:03Z, attempt=1 fresh pending row, 14:14:18Z) — both
    `INVALID_REPORT;INCOMPLETE_RUNS REPORT_PARSE_ERROR despite
    nonempty report files; total_trades=0` with `report_size_bytes`
    ~22 KB. **Variant of bucket (6) parser-empty-html-not-
    classified, but with NON-empty reports.** Parser still fails to
    extract a metric but the underlying report HTML is present.
    Treating as bucket (6) sub-variant rather than a new bucket
    since the upstream fix is the same shape (defensive parser
    fallback).

  - **QM5_1133** (re-attempt at 14:09:18Z, NDX.DWX D1) — fresh
    NO_HISTORY pending row; previously self-healed via done sibling
    at 16:34:20Z 2026-05-17. Reinforces (9b) "tester state flake"
    sub-case — same EA cycles between done and NO_HISTORY across
    attempts.

  - **QM5_1168** (attempt=2, 14:14:18Z) —
    `REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED`.
    Joins **worker-mortality / metatester-hung** bucket.

  - **QM5_1236** (attempt=1, 14:14:18Z) — `T1 terminal instance
    already running; run_smoke refused to launch without
    -AllowRunningTerminal`. **QM5_1237** (attempt=1, 14:14:18Z) —
    `Terminal instance is already running for D:\QM\mt5\T1; smoke
    harness aborted before tester launch`. Both join **preflight-
    already-running** bucket. The "-AllowRunningTerminal" wording
    is the new fail-fast message shape from commit `4dbe855d`
    (15:20:53Z) — but these rows were updated at 14:14Z, ~66 min
    BEFORE the commit landed, so they pre-date the watchdog patch.

  - **QM5_1087**, **QM5_1119** — pump-resets with empty
    failure_reason (re-queued for retry); not failure-mode signal.

  **New fix candidate (10) — audit pump-retry path for
  parameter-passing consistency.** Locate where `run_smoke.ps1` is
  re-invoked by the autonomous wake's pump (likely
  `pump_record_build` in `farmctl.py`) and verify that `-Symbol`
  and `-Year` are pulled from the prior attempt's payload or the
  card's `symbol_tf` field on every retry, not just the first
  invocation. One-EA bucket today but the regression risk is real
  because the missing-params message implies the call site reached
  the script with a partial argument list — could affect any EA on
  retry.

  **Post-`4dbe855d` watchdog status: pre-validation.** The
  terminal64 spawn-watchdog commit landed at 15:20:53Z, ~26 min
  before this wake. No fresh smoke artifacts in
  `D:/QM/reports/smoke/` have a `LastWriteTime > 15:21Z` yet (most
  recent under the recently-failed EAs are 14:14Z or earlier).
  Validation defers to the next autonomous wake at 16:17Z which
  will be the first build attempt to run under the new watchdog.

  Updated cluster composition (32 rows / 31 distinct EAs,
  unchanged from 13:00Z; the new bucket (9) row is status=pending
  and not yet in the self-heal filter):
  - cold-warm-asymmetry (5): QM5_1045/1050/1055/1122/1149
  - both-runs-fail (8): QM5_1046/1060/1065/1066/1067/1070/1094/1095
  - preflight-already-running (5): QM5_1068/1082/1101/1123/1159
    (1236/1237 retry-pending, not yet terminal)
  - worker-mortality / metatester-hung (4): QM5_1090/1091/1118/1093
    (1168 retry-pending, not yet terminal)
  - file-lock-on-include-sync (1): QM5_1121
  - parser-empty-html-not-classified (3): QM5_1117/1119/1142
    (1103/1134-pending are non-empty-report variants of same bucket)
  - data-history-missing (1): QM5_1132
  - other (REPORT_MISSING / timeout / NO_REAL_TICKS_MARKER) (4):
    QM5_1061/1069/1081/1062
  - **(9) run_smoke_invocation_missing_params (NEW, retry-pending):
    QM5_1104**

  **Recommended escalation path unchanged.** Severity remains HIGH.
  The two-fix bundle (5) terminal-pool mutex + (1) cold-start
  warm-up plus newly-landed (4dbe855d) spawn-watchdog covers the
  largest failure surface; (10) is a one-EA outlier that fits a
  cleanup pass once the bundle lands. Per DL-046, next update
  gated again until either (a) yet another new bucket beyond the
  nine listed, (b) cluster crosses 40 distinct EAs, (c) post-
  watchdog validation evidence (positive or negative) from the
  next autonomous wake, or (d) OWNER picks a fix candidate.

- **2026-05-18T19:40Z (observe wake)** — **post-watchdog validation:
  partial-positive. Watchdog 4dbe855d eliminated preflight class for
  new failures; REPORT_MISSING + METATESTER_HUNG persist unchanged.
  Cluster 31 → 36 distinct EAs (32 → 38 rows), still under 40 gate.**
  Commit trigger: condition (c) post-watchdog validation evidence.

  Four terminal failures in the post-patch window (commit `4dbe855d`
  landed 2026-05-17T15:20:53Z):

  - **QM5_1104** (`qp-country-bab`) failed attempt=3 at
    2026-05-18T16:59:03Z — `framework_error REPORT_MISSING;
    INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED`. Previous bucket (9)
    `run_smoke_invocation_missing_params` failure mode did NOT
    recur; final terminal attempt landed in cold-warm-asymmetry
    shape instead. Bucket (9) likely a one-shot pump-retry path bug
    that the next retry naturally bypassed — fix candidate (10)
    deferred from active hot list.
  - **QM5_1168** failed attempt=3 at 17:49:03Z —
    `REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS;
    MODEL4_MARKER_REQUIRED`. Joins worker-mortality bucket.
  - **QM5_1236** failed attempt=3 at 18:19:03Z — same shape.
    Notable: earlier attempt at 14:14Z (pre-patch) had `T1 already
    running` preflight wording; final attempt post-patch is
    METATESTER_HUNG, NOT preflight. Watchdog moved this row out of
    preflight bucket into worker-mortality.
  - **QM5_1237** failed attempt=3 at 18:19:03Z —
    `REPORT_MISSING;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED`.
    Earlier attempt was preflight wording; final is cold-warm-
    asymmetry shape. Same migration.

  **Validation read.** Watchdog patch `4dbe855d` did its job for the
  preflight class: zero new failures with "T1 already running" /
  "AllowRunningTerminal" wording in the post-patch window. Builds
  that previously aborted before tester launch now proceed past the
  preflight gate. But the tester-side flakiness (cold-start
  REPORT_MISSING + metatester process leak / worker mortality) is
  unchanged — those EAs that the watchdog now lets through still
  fail downstream at the report-export step. Net: watchdog converted
  preflight-failures into worker-mortality / cold-warm-asymmetry
  failures, did not eliminate the cluster.

  **Confidence the watchdog is working, not just rotating buckets:**
  observed counts since 15:21Z patch land — 4 terminal failures,
  none with preflight wording (was the dominant class at 14:14Z
  with QM5_1236/1237 both preflight-blocked then). Sample is small
  but directionally consistent with the patch's intent.

  Cluster composition (36 distinct EAs / 38 rows):
  - cold-warm-asymmetry (6): QM5_1045/1050/1055/1122/1149/**1104**
  - both-runs-fail (8): QM5_1046/1060/1065/1066/1067/1070/1094/1095
  - preflight-already-running (5, all pre-patch terminations):
    QM5_1068/1082/1101/1123/1159 — **no new entrants post-patch**
  - worker-mortality / metatester-hung (6):
    QM5_1090/1091/1118/1093/**1168**/**1236**
  - file-lock-on-include-sync (1): QM5_1121
  - parser-empty-html-not-classified (3): QM5_1117/1119/1142
  - data-history-missing (1): QM5_1132
  - REPORT_MISSING (other) (5):
    QM5_1061/1069/1081/1062/**1237**
  - (9) run_smoke_invocation_missing_params: empty (1104 migrated
    out — see above; bucket effectively retired pending recurrence)

  **Knock-on context.** Autonomous wakes 16:20→19:20Z all skipped
  step0b/step2 because the separate `2026-05-17_codex_auth_401_
  websocket.md` escalation is still firing (auth.json last_refresh
  pinned at 2026-05-18T05:00:55Z >14h stale). No fresh builds
  during this validation window — the 4 terminal failures are all
  pump-retry exhaustion on pre-existing blocked EAs, not net-new
  Codex builds. A clean post-watchdog validation pass on a fresh
  build cohort awaits OWNER `codex login` per that escalation.

  **HR16 dual-active-sources note.** `farmctl status` returns 2
  `active` rows during this wake (Allocate-Smartly + ForexFactory).
  Autonomous wake 19:20:00Z already flagged this as a benign
  resume-mining pattern (`resume-mining` flips `cards_ready→active`
  without emitting an `events` row, leaving the older `active`
  ghost-row briefly until the next status transition catches it).
  Not raising as separate escalation; recording here so it's not
  re-discovered as drift by the next observe wake.

  **Recommended escalation path unchanged.** Severity remains HIGH.
  Two-fix bundle (5) terminal-pool mutex + (1) cold-start warm-up
  still the highest-leverage intervention; (10) downgraded to
  cleanup. Per DL-046, next update gated again until (a) yet
  another new bucket beyond the eight currently active, (b)
  cluster crosses 40 distinct EAs, (c) post-codex-auth-recovery
  validation cohort (separate signal class from this watchdog
  validation), or (d) OWNER picks a fix candidate.

- **2026-05-19T00:49Z (observe wake)** — **two gates tripped at once:
  cluster crossed the 40-EA threshold (gate b), and bucket (9)
  `run_smoke_invocation_missing_params` re-emerged from
  retired-pending-recurrence via QM5_1400 (gate a). Plus a new
  post-watchdog preflight variant on QM5_1119: whole-pool exhaustion
  wording rather than the single-terminal AllowRunningTerminal
  wording, which the 4dbe855d watchdog patch was designed to
  fail-fast.**

  Six new terminal failures since the 19:40Z entry (all attempt=3,
  pump cap holding):

  - **QM5_1195** (failed 22:44:02Z) —
    `REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED`.
    Joins worker-mortality bucket.
  - **QM5_1213** (failed 23:44:02Z) — same shape. Joins
    worker-mortality bucket.
  - **QM5_1101** (failed 23:49:02Z, second row — earlier 14:14Z row
    was preflight-class) — same shape as 1195/1213. Migrates from
    preflight to worker-mortality post-watchdog, mirroring QM5_1236
    / QM5_1237 in the 19:40Z entry.
  - **QM5_1119** (failed 23:59:02Z) — `smoke not launched: T1
    terminal already running and T1-T5 are occupied by existing
    tester work items`. **New preflight variant.** Distinct from the
    pre-watchdog `T1 terminal already running` wording (which the
    4dbe855d watchdog fail-fasts with AllowRunningTerminal). This
    one explicitly says **whole pool T1-T5 occupied** — the watchdog
    passed the single-terminal check (no single terminal "already
    running" without authorization) but every terminal in the pool
    was busy with tester work items. Suggests the 4dbe855d patch
    handles per-terminal conflict but not pool-saturation refusal;
    or, the smoke harness's allow-list of terminals does not match
    the dispatcher's pool, so smoke can't find any free terminal
    when dispatcher is saturating T1-T5.
  - **QM5_1448** (failed 00:14:02Z) —
    `REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED`.
    Joins worker-mortality bucket.
  - **QM5_1400** (failed 00:24:02Z) — `run_smoke.ps1 missing
    mandatory parameters: Symbol Year`. **Bucket (9) recurrence.**
    The 19:40Z entry retired (9) when QM5_1104's terminal attempt
    migrated to cold-warm-asymmetry. QM5_1400 now exhibits the same
    deterministic invocation bug on a different EA, contradicting
    the "one-shot pump-retry path bug" hypothesis. Fix candidate
    (10) `audit pump-retry path for parameter-passing consistency`
    is back on the active list — this is no longer a single-EA
    outlier.

  Updated cluster: **40 distinct EAs / 44 rows** (gate (b) crossed
  exactly):
  - cold-warm-asymmetry (6): QM5_1045/1050/1055/1122/1149/1104
  - both-runs-fail (8): QM5_1046/1060/1065/1066/1067/1070/1094/1095
  - preflight-already-running (5, all pre-watchdog terminal):
    QM5_1068/1082/1101-firstrow/1123/1159
  - preflight-pool-exhausted (1, **NEW post-watchdog variant**):
    **QM5_1119-latestrow**
  - worker-mortality / metatester-hung (10):
    QM5_1090/1091/1118/1093/1168/1236/**1195**/**1213**/**1101-latestrow**/**1448**
  - file-lock-on-include-sync (1): QM5_1121
  - parser-empty-html-not-classified (3): QM5_1117/1119-firstrow/1142
  - data-history-missing (1): QM5_1132
  - REPORT_MISSING (other) (4): QM5_1061/1069/1081/1062/1237
    (note: 1237 stays here per 19:40Z classification)
  - **(9) run_smoke_invocation_missing_params (REACTIVATED)**:
    **QM5_1400**

  **Watchdog (4dbe855d) re-evaluation.** The 19:40Z entry concluded
  preflight class was eliminated for new failures. That holds for
  the single-terminal-already-running shape, but QM5_1119 at
  23:59:02Z demonstrates a second preflight failure mode — whole-pool
  saturation — that the watchdog does not cover. The watchdog
  reduces but does not eliminate preflight; a small new bucket
  (`preflight-pool-exhausted`) opens. Net assessment of the patch:
  positive but incomplete; the underlying contention between smoke
  and dispatcher described in fix candidate (5) (terminal-pool
  mutex) remains the load-bearing fix. Candidate (6) (reserve
  T0/T5 as smoke-only) would also eliminate this new variant.

  **Worker-mortality bucket dominates.** 10 of 40 EAs (25%) now sit
  in this bucket — the largest single failure mode. The 19:40Z
  entry already flagged this as the post-watchdog migration target,
  and four hours later the bucket gained four more entries
  (+QM5_1195/1213/1101-latest/1448) — confirming watchdog converted
  preflight-failures into worker-mortality failures without solving
  the underlying tester instability.

  **Recommended escalation path strengthened.** Severity remains
  HIGH. The bundle picks now logically resolve to:
  - **(5) terminal-pool mutex** — addresses both the
    single-terminal preflight (already partly covered by watchdog)
    AND the new pool-exhaustion preflight variant.
  - **(1) cold-start warm-up** OR **(2)/(3) loosened all-runs-OK
    gate** — addresses the worker-mortality + cold-warm-asymmetry
    clusters that are the bulk of the failure mass.
  - **(10) pump-retry parameter-passing audit** — back on active
    list per QM5_1400 recurrence.
  - **(8) defensive parser fallback** — small diff, eliminates the
    parser-empty-html bucket (3 EAs).

  Per DL-046, no further update gating window now stretches to:
  next update only on (a) yet another new bucket beyond the
  currently-active nine (eight original + reactivated (9) +
  preflight-pool-exhausted), (b) cluster crosses 50 distinct EAs,
  (c) post-codex-auth-recovery validation cohort, or (d) OWNER
  picks a fix candidate. No Board-Advisor action beyond this
  log entry — framework + run_smoke.ps1 + farmctl pump-retry path
  remain outside scope.
