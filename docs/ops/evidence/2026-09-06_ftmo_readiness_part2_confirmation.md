# FTMO readiness part 2 — final confirmation (commit 058d344368) — ACCEPT

- **Task:** `0c1b3295-7044-4f47-8be4-1db5966d56df`
- **Date:** 2026-09-06
- **Executed by:** Claude agent lane, on the Orchestrator's instruction (the Codex lane is occupied).
- **Scope:** Review only. Confirm that the three passages named in the re-check `91ffb9e6` (`docs/ops/evidence/2026-09-05_recheck_ftmo_readiness_part2.md`) are closed at commit `058d344368`, and that no sentence in part 2 (`docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md`) still treats the delivered telemetry pair as absent or orders a duplicate build.
- **Method:** `git show 058d344368` (full diff + `--unified=0` hunk map), `git show`/history for the re-check artifact, direct read of the current file on branch `agents/board-advisor` (working tree == HEAD for this file), and the five phrase greps named in the payload. No operational code was imported or executed. No account numbers, credentials, or host details are reproduced.

## Context

The re-check `91ffb9e6` (artifact `docs/ops/evidence/2026-09-05_recheck_ftmo_readiness_part2.md`, exact revision `355d88586e…`) returned REJECT with three numbered residuals: **§B.2 line 140**, **§B.7 line 192**, and the **§B.6 action row line 206**, all treating the delivered pair `QM_FTMO_TrialTelemetry.mq5` + `ftmo_trial_telemetry.py` as still-to-be-built. Commit `058d344368` ("readiness part 2 — re-check 91ffb9e6 residuals") edited exactly four lines of the part-2 file: the changelog line (`+15`) and the three residual lines (`140→141`, `192→193`, `206→207`), verified via `git show 058d344368 --unified=0` (hunks `@@ -14,0 +15 @@`, `@@ -140 +141 @@`, `@@ -192 +193 @@`, `@@ -206 +207 @@`). Both delivered files exist and are git-tracked: `framework/monitor/QM_FTMO_TrialTelemetry.mq5`, `tools/strategy_farm/portfolio/ftmo_trial_telemetry.py`.

## Passage-by-passage confirmation

| Passage | Required correction (from re-check 91ffb9e6) | Current text location | Status | Evidence (current text, quoted) |
|---|---|---|---|---|
| **§B.2 collector-absence tail** (re-check line 140) | Drop "Until that collector exists" absence wording; close symbol (limit 2) gap; keep only the live-risk set-path (limit 1) gap open; frame as delivered-but-unaccepted. | `docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md:141` | **CONFIRMED** | "For-record capture remains blocked until the delivered collector is accepted, installed under approval and proven with bound capture evidence; until then the interval-minimum daily-loss quantity and the tail-cert intraday minima are **unobserved** — so a **for-record defect-free trial is blocked on that acceptance in addition to the live-risk set-path gap (limit 1)**; symbol coverage (limit 2) is closed by the eight lanes. This is UNVERIFIED/GAP for the evidence, not for the implementation." The absence phrase "Until that collector exists" no longer occurs anywhere in the file (grep: no match). |
| **§B.7 monitor/collector sentence** (re-check line 192) | Replace "the only live instrument (`QM_AccountMonitor.mq5`)"; stop saying the collector must "exist"; state the delivered pair needs acceptance/installation and a bound trial capture. | `docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md:193` | **CONFIRMED** | "…because the older deployed monitor (`QM_AccountMonitor.mq5`) overwrites its snapshot every 60s… until BOTH a trial runs AND the delivered Prague-day-keyed interval-minimum collector (B.2 hard limit 3: `QM_FTMO_TrialTelemetry.mq5` + `ftmo_trial_telemetry.py`, delivered but not yet accepted or installed) is armed to persist it." "the only live instrument" no longer occurs (grep: no match); the collector is named "delivered but not yet accepted or installed", not "exists". |
| **§B.6 action-table duplicate build** (re-check line 206) | Replace the "commission … (new tool)" build order for the collector with a review/acceptance-of-the-delivered-pair action. | `docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md:207` | **CONFIRMED** | "\| review and accept the **delivered Prague-day-keyed interval-minimum + position/pending collector** (`QM_FTMO_TrialTelemetry.mq5` + `ftmo_trial_telemetry.py`), approved installation, bound capture evidence \| AI-commissionable (review/acceptance task; installation under approval) \| closes B.2 limit 3 once accepted and evidenced; standing auth (review lane) \|". No "commission … collector (new tool)" build row survives for the telemetry pair. |

## Contradiction sweep (phrases named in the payload)

- `no on-disk tool` → **no match**.
- `only live instrument` / `the only live instrument` → **no match** (removed from §B.7).
- `Until that collector exists` → **no match** (removed from §B.2).
- `must be commissioned` → survives only at **line 132 (§B.2 hard limit 1)**: "A new live-mode set-generation path must be commissioned before a live trial can run for-record." This refers to the **live-mode FTMO set-generation path (limit 1)**, a genuinely absent tool — not the telemetry collector. Not contradicting.
- `new tool` → survives only at **line 206 (§B.6)**: "commission a **live-mode FTMO set-generation path** (new tool)". Same limit-1 set-generation path, genuinely absent. Not contradicting.
- `new collector` → survives at **line 173 (§B.4)**: "**→ The new collector (B.2 hard limit 3) is the missing capture authority**…". This sentence sits in a paragraph whose opening sentence (`:173`) already states "The delivered pair `QM_FTMO_TrialTelemetry.mq5` + `ftmo_trial_telemetry.py` is designed to feed this stream but is not yet reviewed, installed or evidenced", so "missing capture authority" reads as *not-yet-operational*, not *not-yet-built*. The re-check itself classified this §B.4 wording as a "should … for consistency" nicety, **not** one of its three REJECT residuals; commit `058d344368` was not scoped to it, and it neither treats the pair as unbuilt in a standalone sense nor orders a duplicate build. Non-blocking residual (see Limits).

## Verdict

**CONFIRMED / ACCEPT.** All three passages named in the re-check `91ffb9e6` are closed verbatim at commit `058d344368` (current file lines 141, 193, 207); the absence phrases "Until that collector exists", "the only live instrument", and "no on-disk tool" no longer survive; and the only "new tool"/"must be commissioned" references that remain point to the genuinely-absent live-mode set-generation path (limit 1), not the delivered telemetry pair. No sentence orders a duplicate build of the telemetry collector.

## Limits

- Documentary confirmation only: verified the wording of part 2 and the presence + git-tracking of the two delivered files (`framework/monitor/QM_FTMO_TrialTelemetry.mq5`, `tools/strategy_farm/portfolio/ftmo_trial_telemetry.py`). **Not** verified: the runtime correctness, capture adequacy, review, installation, or bound-capture evidence of the telemetry pair — these remain the open acceptance dependency the text itself states.
- One non-blocking residual survives outside the three named passages: §B.4 line 173 "The new collector (B.2 hard limit 3) is the missing capture authority". It was flagged by the re-check as a for-consistency improvement (not a REJECT item) and reads as not-yet-operational given the paragraph's opening; it does not overturn ACCEPT of the three named passages. A future editorial pass could align it with the "delivered, not yet accepted" framing.
- The live-risk set-path gap (limit 1) and per-lane exact-profile verification remain legitimately open by design and are outside this confirmation's scope.
