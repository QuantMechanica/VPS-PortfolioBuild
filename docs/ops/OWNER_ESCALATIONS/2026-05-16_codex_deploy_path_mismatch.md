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
