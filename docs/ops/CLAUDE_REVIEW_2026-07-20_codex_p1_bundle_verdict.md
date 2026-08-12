# Claude Review Verdict — Codex Framework P1 Evidence Bundle (2026-07-20)

**Scope:** agents/codex commits 6e92c8062, b65e45b87, 162713c82, 5b44b65fc, 369b52887,
82fafec5d (+ coordination docs a6c957dc6, 1bf892a41). Handoff:
`docs/ops/CODEX_HANDOFF_2026-07-20_framework_p1_evidence_bundle.md`.
**Method:** 3-lens adversarial review (evidence integrity / live-safety+destructive-ops /
integration+wave readiness), independent test re-runs, trial merges via `git merge-tree`.

## Verdict: ACCEPTED for the Friday include-freeze. 0 BLOCKER, 1 MAJOR (docs-only), 5 MINOR.

Independently confirmed (selection): H2 GlobalVariable baselines are tester-inert
(restore/persist early-return under MQL_TESTER — backtest evidence stays bit-identical);
H3 selftest cannot false-FAIL any active symbol (index mappings complete, every FX cross
carries a seed-present currency — NZD 2481 / CAD 3524 / CHF 1688 rows verified) and is a
no-op for news-inactive EAs; H4 `sv:1` is additive and all Python consumers tolerate it;
P2.11 moved all 10 cards byte-identically (hashes re-verified on disk) and retired exactly
one unclaimed pending DB row under BEGIN IMMEDIATE; MAE hook is template-only and
O(PositionsTotal)/tick; bundle-owned tests 42/42 green on re-run; unknown-event handling
is WARN-only and cannot reach the sanctioned mail channels.

## Conditions attached to acceptance

1. **Merge route:** codex → agents/board-advisor is conflict-free (executed 2026-07-20);
   the direct codex → main route has one add/add conflict on
   `docs/ops/evidence/2026-07-20_framework_p1_claude_coordination.md` — union both
   evidence sections at the main merge (docs-only, zero code impact).
2. **Atomicity:** `build_check.ps1` and `framework/registry/event_vocabulary.json` must
   always land together (same commit; no pathspec cherry-picking of one without the other)
   — build_check hard-fails on a missing/invalid vocabulary.
3. **12074/12247 sequencing guard:** both re-keyed ids are active in ea_id_registry but
   absent from magic_numbers.csv until the deferred quiescent resolver pass
   (dirs → CSV → regen → verify → compile). Do NOT build/force_build either id before
   that pass; their cards stay out of the active D-store namespace. Scheduled into the
   Saturday wave window (factory OFF).
4. **sv transition doc note:** any manually-passed `-LoggerSamplePath` must be an sv:1
   file (pre-sv samples hard-fail the field check; the resolve-sample filter and the
   embedded fallback make the default path safe).
5. **Preflight CSV:** `news_tester_symbol_selftest_preflight_20260720.csv` covers a
   10-symbol representative sample, not the full universe — safety was verified
   independently here; regenerate full-universe or keep this annotation.

## Claude adjudications requested by Codex

- **Historical RECYCLE rows (P1.9):** remain UNCHANGED, permanently. They are the
  immutable historical record under the old ids; the re-keyed ids start with clean
  histories. No annotation pass needed.
- **Deferred D-store card pass:** scheduled for the Saturday wave's factory-OFF window
  (quiescent by construction), together with the resolver regen of condition 3.

## Known-red baseline (not bundle regressions)

`test_phase_orchestrator_producer` (2 failures, 'blocked_ghost_build' vs 'enqueued') and
`test_q03_plateau_runner` (needs pytest; Python311 lacks the module — use C:\Python311
pytest 9.1.1) predate the bundle; tested sources untouched by these commits. Tracked so
they are not conflated with wave breakage.

## Post-merge verification

Merged into agents/board-advisor (canonical checkout) 2026-07-20; include-graph compile
re-verified via compile_one after the merge (see commit referencing this doc).
