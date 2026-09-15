# Evidence Receipt — Directive-3 Wave-1 merge into main

**Date:** 2026-09-15 ~21:15–23:20 UTC
**Author:** Kimi (interim operator, OWNER_DIRECT_SESSION_DELEGATION)
**Authority basis:** §38 (read reviews, verify, advance) + §39 (merge policy) + §40 (reviews exist as independent Claude adversarial passes; test suites re-verified by me). Merge plan: `docs/ops/evidence/2026-09-15_directive3_wave1_merge_map.md`.

## What was done
1. **Checkpoint-committed all 8 slice worktrees on their own branches** (protection against worktree-janitor loss) — ba6-1 `2239a68cd9`, ba6-2 `8d203c053e`, ba6-3 `5a5ab39a05`, ba6-4 `38c8e33c63`, ba6-5 `9301291df2`, ba6-6 `6c54cf5e3e`, ba6-7 `19a037441b`, ba6-8 `83078bb3f4`.
2. **Settled main drift** `3dabde3575`: committed 4 machine-regenerated living docs (readiness + 3 research maps) and the 7 adversarial review files (they were already untracked in main).
3. **Cherry-picked the 7 reviewed slices in the map's order** (each `-x`, provenance to its checkpoint):
   ba6-1 `5f20a0532f` → ba6-6 `484d3f0228` (runner conflict resolved keep-both) → ba6-4 `a6752e7254` (wiki-sync conflicts resolved keep-both; **one resolution bug of mine caught by tests and fixed**: build() passed `Sources` instead of `sources.live_attribution` to `load_live_pnl`; lint call made keyword-form `live_pnl=`) → ba6-7 `f35f303e4a` (readiness doc conflict → took slice render, then regenerated per review's blocking fix, committed `167174f837`) → ba6-3 `9cad21ef11`, ba6-5 `4eb4058012`, ba6-8 `0b2a5a6b63` (zero conflicts).
4. **ba6-2 NOT merged** — decision gate (needs its design report + adversarial review; recommendation: complete, don't abandon — evidence verified against live scorecard). Worktree checkpointed at `8d203c053e`.

## Verification (all re-run by me on merged main)
- a1 10/10 · h1 7/7 · wiki-sync+register **27/27** · i1 first-passage 15/15 · readiness/fitness/rule-contract/book-evolution 41/41 · d1/e1/g1/j1 risk-contract+intake+card+scheduler+pattern suites **88/88**.
- Touched-module sweep (`book_evolution_runner|external_roi|frozen_snapshot|terminal_worker|mechanization`): 409 passed, **11 failed — failure set byte-identical at pre-merge base `3dabde3575` (verified in scratch worktree) → all pre-existing test noise, zero merge-caused regressions.**

## Boundaries kept
No gate verdicts, no live state, no factory DB writes, no T_Live/FTMO touches. Tracked advisory fixes from reviews remain OPEN for Fable: j1 census-join MAJOR re-run (contaminated baseline buckets), g1 STEP-2 census pin (default-off path), d1 build-path grid guard residual (`governed_magic_allocator.py:374`), e1 OOS-window caveat travel note.

## Residual risks
- The merged `book_evolution_runner.py` now runs `live_sleeve_attribution` + `ai_capacity` state builds at the next 15-min/readmodel cycles; per-build fail-closed EXIT handling verified in code; watch first Friday ceremony (2026-09-18 23:15 local).
- 4 phantom-dirty files resolved by checkout (content == HEAD, verified empty diff before restore).
