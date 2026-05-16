---
opened_utc: 2026-05-16T13:14Z
raised_by: Board Advisor (autonomous wake 12:57Z)
severity: medium
class: codex-build-flow + deploy-path-convention
---

# Codex build deploys to legacy `<EALabel>\<EALabel>.ex5`, but smoke harness expects `QM\<EALabel>.ex5`

## Observed (QM5_1046 build task `57ee887a-a86b-4913-a431-e0a6f6a64e45`)

Codex compiled `QM5_1046_maroy-intraday-vwap-exit.ex5` cleanly to
`C:/QM/repo/framework/EAs/QM5_1046_maroy-intraday-vwap-exit/QM5_1046_maroy-intraday-vwap-exit.ex5`
(116 386 bytes, 15:05 local). Build_check + compile actually succeeded.

The .ex5 was deployed to
`D:/QM/mt5/T1/MQL5/Experts/QM5_1046_maroy-intraday-vwap-exit/QM5_1046_maroy-intraday-vwap-exit.ex5`
— the legacy nested layout.

`run_smoke.ps1` (post-commit `5fdc3169 fix(run_smoke): correct default Expert path to QM\<EALabel>`)
launches MT5 tester with `Expert=QM\QM5_1046_maroy-intraday-vwap-exit`, which MT5
resolves to `MQL5/Experts/QM/QM5_1046_maroy-intraday-vwap-exit.ex5` (flat under
`QM/`). That file does not exist → tester exit `-1000012355`, REPORT_MISSING,
INCOMPLETE_RUNS, MODEL4_MARKER_REQUIRED on both `-Runs 2` attempts.

Tester log evidence (UTF-16 LE):
```
OR  2  15:05:51.088  Tester  Experts\QM\QM5_1046_maroy-intraday-vwap-exit.ex5 not found
DM  2  15:09:55.436  Tester  Experts\QM\QM5_1046_maroy-intraday-vwap-exit.ex5 not found
```

Codex's `build_result.json` reported `compile_succeeded=false` because it inferred
from the framework_error smoke result. That is misleading — the EA compiled
fine; only the deploy layer is broken.

## Root cause

Two conventions in tension:

- **Legacy (pre-corset, before 2026-05-16T12:00Z)**:
  `MQL5/Experts/<EALabel>/<EALabel>.ex5` — what `build_check.ps1` /
  `codex_build_ea.md` still tell Codex to deploy to.
- **Canonical (post-corset)**:
  `MQL5/Experts/QM/<EALabel>.ex5` — what `run_smoke.ps1` looks for now, and
  what `framework/scripts/verify_build_deployment.py` enforces (MIN_EX5_BYTES,
  SHA256 across T1..T5).

QM5_1047 worked only because the corset upgrade commit (`dadbed61`) **manually
redeployed** 1047 to the new canonical location ("QM5_1047 .ex5 redeployed to
T1-T5 fresh from the regenerated resolver"). For the next EA that goes through
the autonomous Codex build, the manual redeploy doesn't happen and smoke breaks.

QM5_1050 has a stale `pending` build_ea task `af71aa1a-…` from before the
run_smoke.ps1 fix; its earlier build_result.json shows the same
`framework_error REPORT_MISSING` for the same root cause.

## Fix candidates (NOT executed — outside Board Advisor scope)

Pick one — they're equivalent in effect:

1. Update `tools/strategy_farm/prompts/codex_build_ea.md` to instruct Codex to
   deploy `<EALabel>.ex5` directly under `MQL5/Experts/QM/` on each terminal,
   not under `MQL5/Experts/<EALabel>/`.
2. Update `framework/scripts/build_check.ps1` to perform the canonical deploy
   itself after compile (idempotent, drives the convention from one place).
3. Wire `framework/scripts/verify_build_deployment.py` into the Codex post-
   compile step so the build hard-fails at SHA mismatch / wrong path instead
   of letting smoke discover it.

(3) is structurally cleanest — it makes the canonical path the only path the
build can succeed at. The verify script already exists, just isn't called from
the build flow yet.

## What this wake did

- Created build task `57ee887a-a86b-4913-a431-e0a6f6a64e45`, ran Codex full
  build, recorded `status=blocked` per the framework_error result.
- Committed Codex's build artefacts (.mq5 + .ex5 + 2 setfiles for NDX.DWX / WS30.DWX)
  and the regenerated `QM_MagicResolver.mqh` (190→192 rows). EA dir
  `framework/EAs/QM5_1046_maroy-intraday-vwap-exit/` is on disk and ready —
  the only thing missing is a correct deploy.

## Recommended next step

Pipeline-Operator (or CTO via OWNER) picks fix candidate, lands it, then SQL-
flips `tasks` row `57ee887a-…` from `blocked` → `pending` and lets the next
autonomous wake rerun the build. QM5_1050 (`af71aa1a-…`) likely cures
automatically by the same fix; its EA dir is already on disk.

The Board Advisor did NOT manually copy the .ex5 to the canonical path and
re-run smoke — that path crosses into Pipeline-Operator scope and breaks the
one-pass build discipline (commit `69bafe7f`). Better to fix the flow once
than patch each EA by hand.

## Update — 2026-05-16T13:47Z (observe wake)

**Fix candidate 2 has been landed** as commit `891b04c4 fix(run_smoke):
self-deploy .ex5 to all T1-T5 before invoking tester` (committed 13:24Z by
the previous autonomous wake). The run_smoke harness now drives the canonical
deploy itself.

Verified state on disk: `QM5_1046_maroy-intraday-vwap-exit.ex5` (116386 bytes)
present at `D:/QM/mt5/T{1,2,3,4,5}/MQL5/Experts/QM/` with mtime
2026-05-16T13:05:23Z. Legacy nested copy still lingers at
`T1/MQL5/Experts/QM5_1046_maroy-intraday-vwap-exit/` (109436 bytes, mtime
09:24Z, stale from earlier sandbox-locked build attempt) — cosmetic only,
not load-path-resolved by the post-`5fdc3169` tester invocation.

Verification that the fix works end-to-end: the next autonomous wake at
13:34Z successfully built and smoked **QM5_1048 estrada-lazy-6m-rotation**
(`smoke=zero_trades  review=APPROVE_FOR_BACKTEST`, p2_task=7f3b8801) using
the new canonical-deploy path. So fix candidate 2 is operationally proven.

### New evidence on QM5_1046 — TIMEOUT, distinct from the deploy bug

A second smoke run for QM5_1046 captured at
`D:/QM/reports/smoke/QM5_1046/20260516_132039/summary.json` (timestamp
2026-05-16T13:30:39Z, terminal=`any`/T5) shows a **different** failure mode:

```
result: FAIL
reason_classes: TIMEOUT, METATESTER_HUNG, INCOMPLETE_RUNS
run_01: TIMEOUT after 300 s, exit_code=null
run_02: TIMEOUT after 300 s, exit_code=null
report_size_bytes: 0 (both runs)
```

This is **not** REPORT_MISSING / exit `-1000012355` (file not found). The
tester subprocess was killed by the 300 s wall-clock, suggesting the EA
loaded and started executing but didn't reach end-of-period inside the
budget. NDX.DWX 2024 M30 with `model=4` (every real tick) is tick-dense; a
year-long backtest can plausibly exceed 300 s on a heavier EA.

A quick read of `QM5_1046_maroy-intraday-vwap-exit.mq5` doesn't show an
obvious per-tick recompute hotspot like QM5_1044's full-EMA-warmup
(line 244 `UpdateSessionVwap()` is gated by `QM_IsNewBar(_Symbol,
PERIOD_M5)`; `Strategy_EntrySignal` is gated by `QM_IsNewBar()`). The
TIMEOUT may simply be "model=4 + NDX intraday + 1 yr" being inherently
slow at smoke budget — not a code bug.

### Why this wake did NOT flip the task to `pending`

The escalation originally recommended SQL-flipping `tasks.57ee887a-…`
from `blocked` → `pending` once the fix lands. Two reasons not to do that
unilaterally now:

1. **Codex-token cost.** Flipping `build_ea` → `pending` re-runs the full
   Codex build cycle (new .mq5 + compile + smoke), not just smoke retry.
   Codex sandbox already burned tokens for QM5_1046 once; a rebuild
   spends them again with no expected change to the .mq5 (the EA dir is
   on disk and unmodified).
2. **TIMEOUT is unresolved evidence.** Even after the deploy fix, the
   13:20 smoke timed out. We don't know whether that was: (a) the 13:20
   run executed before the canonical-deploy fix landed (commit hadn't
   been merged yet at 13:20:39), or (b) a genuine EA/symbol perf issue
   that will reproduce on every retry. Without disambiguation, flipping
   to `pending` risks an infinite retry/block loop.

### Recommended next step (OWNER decision)

Pick one — they're cheap to differentiate:

A. **Manual smoke re-run only** (Test-Environment Ownership, ~10 min):
   invoke `framework/scripts/run_smoke.ps1` directly against the existing
   `framework/EAs/QM5_1046_maroy-intraday-vwap-exit/` to disambiguate
   deploy-bug-residual vs real-perf-issue. If smoke now passes →
   SQL-update `tasks.57ee887a-…` to `done` with the success summary.
   If TIMEOUT reproduces → move to (B).

B. **Reclassify as perf rework**, parallel to QM5_1044's
   `project_qm5_1044_perf_rework_2026-05-16.md` memory. Don't flip the
   task; add a `blocked_reason` update via direct SQL and let it stay
   blocked until Codex (or CTO) reviews the OnTick path. Likely actually
   fine — but documenting it forces the next look.

C. **Just flip to `pending`** and let Codex eat the rebuild tokens. If
   smoke passes, free win; if TIMEOUT reproduces, we get a fresh
   `build_result.json` with current-fix data and the next observe wake
   can pivot to (B). Cheapest in human-attention, dearest in tokens.

Board Advisor leans toward **A**: it's in the Test-Environment Ownership
zone, costs no Codex, and the new evidence is the only thing actually
missing to clear or reroute this task.

The other still-blocked build_ea tasks (QM5_1044 perf rework,
QM5_1045 SPY-permanently-unavailable) are correctly classified and
not affected by this fix.

## Amendment 2026-05-16T14:51Z (Board Advisor observe wake)

### New evidence: option B (perf rework) is ruled out for QM5_1046

Ran the new `Invoke-PerfStaticCheck` from `build_check.ps1` (added in
commit `f6a32965`) against `framework/EAs/QM5_1046_maroy-intraday-vwap-exit/`
on pwsh 7:

```
build_check.result=PASS
build_check.failures=0
build_check.warnings=0
```

So the EA has no local `IsNewBar` redefinition, no raw `iATR/iMA/...` calls,
no ungated `CopyRates/CopyBuffer/Copy*`, no manual `IndicatorRelease`. The
QM5_1044-class perf-wall pattern is NOT present.

That rules out option **B** (reclassify as perf rework). The remaining call
is between option **A** (manual smoke re-run with the post-`891b04c4`
canonical-deploy harness, ~10 min, Test-Environment Ownership) and option
**C** (just flip to `pending` and let the next autonomous wake rebuild +
smoke, ~15 min of Codex tokens). Board Advisor still leans **A** since
the EA dir is already on disk and a clean rebuild adds no new information
about the TIMEOUT root cause.

### Side fix — build_check.ps1 parser break under Windows PowerShell 5

The new `Invoke-PerfStaticCheck` block in `f6a32965` introduced em-dash
characters (UTF-8 `E2 80 94`) inside double-quoted strings. The file is
saved without BOM, so Windows PowerShell 5 (the `powershell` binary)
reads the bytes as Win-1252 (`â€"`), and the embedded `"` prematurely
terminates the string literal, producing cascading "Missing closing '}'"
parser errors at lines 602/654. PowerShell 7 (`pwsh`, default UTF-8) is
unaffected.

The strategy_farm pipeline always invokes `build_check.ps1` via
`pwsh -File ...` (per `codex_build_ea.md` line 254), so operational flow
is **not broken**. The break only surfaces on manual gate-verification
with the `powershell` binary (which is how I tripped over it).

Fix landed: replaced all 8 em-dashes in `build_check.ps1` with ASCII `-`.
Verified PASS under both `powershell` and `pwsh`. Committed via this
observe wake.

### Disposition

- Option B ruled out — perf-static-check PASS.
- Side-channel fix (build_check.ps1 em-dash parse break) landed.
- Option A vs C decision still pending OWNER. Escalation stays open.
