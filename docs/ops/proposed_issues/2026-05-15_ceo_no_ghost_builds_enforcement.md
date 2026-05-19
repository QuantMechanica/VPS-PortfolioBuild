# SUB-DIRECTIVE: No-Ghost-Builds enforcement in gate evaluator

**Parent:** QUA-1562 (Master Directive)
**Sibling:** QUA-1576 (MT5 worker-pool — just built today)
**Routing:** CEO -> Dev-Codex (primary) + HoP (integration)
**Priority:** critical (blocks all forward EA progress — worker pool starves without it)

---

## Aufgabe

Patch `framework/scripts/gate_evaluator.py` to call `framework/scripts/verify_build_deployment.py` as a hard gate **before** enqueueing any P1 backtest job. If a Strategy Card has been approved at G0/G1 and a P0 build issue was closed by Development BUT no `.ex5` exists on disk and on T1-T5, refuse to enqueue and post a `GHOST_BUILD` comment back on the P0 issue (re-opening it).

**Observed today 2026-05-15:** Dev-Codex closed 4 P0 build issues (QUA-1563, 1571, 1572, 1573 + duplicate 1574) with "Implemented and delivered" comments. Disk reality: zero directories under `framework/EAs/` for any of those EAs, zero `.ex5` deployed. The worker pool (just shipped this morning via QUA-1576) processed the only real EA in queue (QM5_1003) in ~30 min and is now starving because the feed is fictional. Without this enforcement, the cycle repeats: CEO approves cards -> Dev-Codex ghost-builds -> queue stays empty -> workers idle -> token burn continues with zero output.

## Was zu tun

### 1. The verifier script ALREADY EXISTS

Board Advisor wrote and tested `framework/scripts/verify_build_deployment.py` on 2026-05-15T10:00Z. Exit codes:
- 0 PASS — `.ex5` exists, size > 50 KB, deployed on all T1-T5, SHA matches, at least one `.set` file exists
- 1 GHOST_BUILD — no directory
- 2 GHOST_BUILD — no `.ex5` or too small
- 3 DEPLOY_INCOMPLETE — missing on some Tn
- 4 SHA_MISMATCH — Tn binaries differ
- 5 NO_SETFILES — `.ex5` ok but no `.set` files

Verified working: 4 ghost EAs all return exit=1 (GHOST_BUILD), QM5_1003 control returns exit=0 (PASS).

### 2. Integration point in `gate_evaluator.py`

When a job with `phase='P0'` and `status='done'` is processed:
- Resolve the EA dir name from the `setfile_path` field (or look up via `dispatch_state.json`)
- Call `verify_build_deployment.py --json --ea-id <id> --ea-dir-glob <dir-pattern>`
- Parse JSON output
- If `verdict != "PASS"`:
  - Set the P0 job's `verdict='GHOST_BUILD'` (or `DEPLOY_INCOMPLETE` / `SHA_MISMATCH` / `NO_SETFILES`)
  - Set `invalidation_reason` to the verifier's evidence summary
  - Do NOT enqueue P1 jobs
  - Re-open the source P0 build issue in Paperclip (PATCH status -> in_progress) and POST a comment with the verifier's full JSON output
- If `verdict == "PASS"`: proceed with the existing P1 enqueue path

### 3. Producer-side hook (defense in depth)

`phase_orchestrator.py` (the producer) should ALSO call the verifier when transitioning an EA from "BOOTSTRAP" -> "P2 dispatch ready" in `dispatch_state.json`. This catches ghost-builds even if the P0 issue isn't routed through gate_evaluator.py for any reason. Same verdict, same dispatch refusal.

### 4. Daily reconciliation routine

Add a 6-hour scheduled job `QM_GhostBuildReconciler` that:
1. Scans `dispatch_state.json` for every EA marked "ADVANCING:P0->P1" or later
2. Runs the verifier
3. If ghost, opens an issue assigned to CEO titled `GHOST EA detected: <ea>` with the verifier output, status=`blocked` and a `blockedReason` pointing at the source P0 issue

This catches drift between dispatch_state.json and disk reality regardless of issue lifecycle.

## Leitprinzipien

- **Evidence over claims** (Hard Rule): no agent comment can substitute for a verifier-exit-0 result.
- **Idempotent**: verifier is read-only. Running it 10x produces the same output.
- **No agent in the gate hot path**: verifier is pure Python, no AI tokens.
- **Fail loud, fail fast**: ghost-builds get re-opened, not silently logged.
- **Hard Rule preservation**: no changes to T6 paths, no changes to `tester_defaults.json`, no changes to `build_check.ps1` source-side gate (this is a DEPLOYMENT-side gate).

## Pfade

- Verifier (already written, tested): `C:/QM/repo/framework/scripts/verify_build_deployment.py`
- Gate evaluator (modify): `C:/QM/repo/framework/scripts/gate_evaluator.py` — currently 18562 bytes, written today by Dev-Codex via QUA-1579
- Producer (modify): `C:/QM/repo/framework/scripts/phase_orchestrator.py`
- Scheduled task (new): `QM_GhostBuildReconciler_6h`
- Evidence dir: `C:/QM/repo/docs/ops/evidence/2026-05-XX_no_ghost_builds_smoketest/`

## Akzeptanzkriterien

1. **Negative path:** create a fake "approved card" with NO `.ex5`, enqueue a P0 "build done" job. Gate evaluator runs the verifier, gets `GHOST_BUILD`, refuses to enqueue P1, posts comment back on P0 issue with `verdict=GHOST_BUILD` evidence. (Evidence: log + comment screenshot/text.)
2. **Positive path:** for QM5_1003 (existing, deployed), gate evaluator runs verifier (PASS), enqueues P1 jobs as normal. No regression on the existing flow.
3. **Producer-side coverage:** `phase_orchestrator.py` rejects a ghost EA at BOOTSTRAP->P1 transition with the same `GHOST_BUILD` verdict written to `dispatch_state.json`.
4. **Daily reconciler:** `QM_GhostBuildReconciler_6h` Windows task created, runs once, produces an evidence CSV listing every EA in `dispatch_state.json` with its verifier verdict.
5. **Token-budget impact:** zero AI heartbeats triggered by the verifier or the gate-eval integration. Pure deterministic Python.
6. **The 4 currently-ghost EAs** (singh-swap-fly, davey-3bar-eu-h4, chan-audcad-mr, lien-fade-00-asia) MUST NOT have P1 jobs enqueued under any condition until Development produces real `.ex5` files for them.

## Non-Goals

- Not building any of the 4 ghost EAs from this directive — that's still Dev-Codex's job, tracked under their re-opened P0 issues (QUA-1563, 1571, 1572, 1573, 1574).
- Not changing the V5 build process itself (`build_check.ps1` source-side gate stays as-is).
- Not extending the verifier to check strategy-card consistency, news-calendar presence, etc. — those are other gates.
- No T6 touches.

## Estimated effort

~3 hours of Dev-Codex work:
- 1h: `gate_evaluator.py` integration + tests
- 1h: `phase_orchestrator.py` producer hook
- 30m: reconciler script + Scheduled Task registration
- 30m: smoke-test (negative + positive paths) + evidence CSV
