# repo_dirty_build_guard self-deadlock — recurring generator allowlist gap

Task: `237837be-dffe-4687-a3f1-763c88715473` (Fable 2026-09-19 factory-unblock
directive item 1; recurrence class `[[project_qm_dirty_guard_build_deadlock_2026-06-04]]`).

## Finding (acceptance item 1) — identified generators

`git status --porcelain=v1` on `C:\QM\repo` (branch `agents/board-advisor`) blocked
again 2026-09-19 with exactly these 5 entries, ~20 min after the manual unblock
commit `fbc9284107` (10:49Z) cleared 49 prior entries:

| dirty path (repo-relative) | generator script |
| --- | --- |
| `docs/ops/FTMO_CHALLENGE_READINESS.md` | `tools/strategy_farm/ftmo/challenge_readiness.py` |
| `docs/research/RESEARCH_PROGRAMME_ROI_2026-09.md` | `tools/strategy_farm/research/external_roi.py` |
| `docs/research/STRATEGY_LINEAGE_MAP_2026-09.md` | `tools/strategy_farm/lineage_map.py` |
| `docs/research/STRATEGY_UNIVERSE_MAP_2026-09.md` | `tools/strategy_farm/research/universe_map.py` |
| `docs/ops/evidence/2026-09-19_stranded_infra_sweep_triage.json` | `tools/strategy_farm/sweep_enqueue_built_eas.py` (`TRIAGE_EVIDENCE`, daily date-prefixed) |

Confirmed via `git status --porcelain=v1 --untracked-files=normal` at 2026-09-19T10:19Z
(before this fix): all 5 of the above and nothing else new since `fbc9284107` among
non-EA, non-artifact paths.

## Root cause

`_repo_dirty_status()` (`tools/strategy_farm/farmctl.py`) classifies each dirty
porcelain entry with `_generated_ea_artifact_kind()`, which recognizes only
`framework/EAs/QM5_*/**` outputs (compiled binaries, set files, SPEC.md, card
mirrors, the untracked `.mq5` scaffold). It has no equivalent for non-EA-scoped
recurring generator outputs.

Separately, `_is_auto_committable_factory_artifact()` (used by
`_auto_commit_build_artifacts` / `_plan_artifact_auto_commit`, the pump's per-cycle
sweeper) recognizes the same EA outputs plus a fixed `ARTIFACT_COMMIT_ALLOWLIST`
(`framework/registry/*`, `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json`,
`public-data/`, `artifacts/`). None of the 5 paths above are under any of those
prefixes, so the sweeper never committed them either.

These 5 files are new since 2026-09-07/09-15 (stranded-infra retry guard,
continuous-book-evolution research generators) and were simply never added to
either mechanism — the same "whack-a-mole allowlist gap" class recorded on
2026-06-09 and 2026-07-14 in `project_qm_dirty_guard_build_deadlock_2026-06-04`.
Because the doc content changes on every regen (hourly heartbeat / daily sweep /
monthly research snapshot) and nothing ever commits it, the guard re-blocks the
Codex build lane on essentially every cycle once the last manual unblock commit's
tree goes stale again.

The "build-retry renames under `artifacts/`" half of the task title
(`qm5_<id>_build_result -> .codex_review_fail_attempt_N`, see
`farmctl.py::_prepare_codex_review_fail_reworks` /
`.codex_review_fail_attempt_{attempt}` archival) is already inside the
`artifacts/` prefix on `ARTIFACT_COMMIT_ALLOWLIST` and inside the `??`/`M`
rename handling in `_parse_porcelain_v1_entry` (destination path only) — no
gap found there at time of audit (2026-09-19T10:19Z no `artifacts/` entries were
dirty). Left as-is; not a live blocker.

## Fix (acceptance item 2a — allowlist by exact path pattern)

Added `_GENERATED_RECURRING_DOC_PATTERNS` in `tools/strategy_farm/farmctl.py`:
5 closed-set regexes (exact filename for the FTMO doc, `\d{4}-\d{2}` month
suffix for the 3 research docs, `\d{4}-\d{2}-\d{2}` date prefix + optional
`.targeted` suffix for the triage JSON), each paired with its generator script
path. Two new helpers:

- `_generated_recurring_doc_kind(path)` — used by `_repo_dirty_status()` (guard
  classification, alongside `_generated_ea_artifact_kind`) and by
  `_is_auto_committable_factory_artifact()` (sweeper eligibility) — so the
  pump's own per-cycle auto-commit now sweeps these files instead of merely
  not-blocking on them (closes the self-heal gap, not just the symptom).
- `_known_generator_for_path(path)` — used by `health._build_lane_block_reason()`
  to name the generator in the `codex_zero_activity`/`codex_auth_broken` detail
  string (acceptance item 3), replacing the bare raw porcelain line.

Deliberately a **closed set of exact regexes**, not a `docs/` or
`docs/ops/evidence/` prefix widen: `test_recurring_generator_doc_allowlist_is_exact_not_a_docs_prefix`
(new) pins that near-miss filenames and generic ops notes
(`docs/ops/human_note.md`, the existing `test_human_source_tree_closes_build_gate_in_both_required_roots`
fixture) still block. No `source/`, `tools/`, or `decisions/` path is touched.

## Verification

```
python -m pytest tools/strategy_farm/tests/test_mnt011_dirty_guard.py \
  tools/strategy_farm/tests/test_build_lane_block_reason_generator_detail.py -q
# 10 passed
python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/health.py
# OK
```

Confirmed the 5 pre-existing `test_health_mt5_capacity.py` failures predate this
change (reproduced identically with the 4 edited files `git stash`-removed, then
restored by exact stash SHA and dropped) — unrelated T11-T14 fleet-scaling drift,
not touched by this fix.

## Rollback (acceptance item 4)

Single commit, isolated to `tools/strategy_farm/farmctl.py`,
`tools/strategy_farm/health.py`, and the two new/modified test files under
`tools/strategy_farm/tests/`. No verdict, evidence JSON, or pipeline gate
criteria mutated — this only widens what the dirty-guard/auto-commit
classifier treats as machine-generated. To roll back: `git revert <this commit>`
(single-commit revert is clean; the new functions and their two call sites are
additive, no other code path depends on them). No DB migration, no flag file,
no scheduled-task change involved.
