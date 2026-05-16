---
opened_utc: 2026-05-17T01:47Z
raised_by: Board Advisor (observe wake 01:47Z)
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
