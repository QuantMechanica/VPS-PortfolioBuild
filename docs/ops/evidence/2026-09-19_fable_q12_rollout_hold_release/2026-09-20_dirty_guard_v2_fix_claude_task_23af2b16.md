# Task 23af2b16-ff30-459c-a07c-f3189c4c01ea — status 2026-09-20

Router task title: "Factory_ON runtime-activation clean-tree check must use the
dirty-guard classification v2 (generated setfiles/ex5 never block); unblocks
maintenance_control release-on-restart for the 8
Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING holds (re-pinned in 221e4e91)."

## Part 1 — code fix (DONE)

`tools/strategy_farm/build_runtime_activation_decision.py`'s two clean-tree
gates used a raw `git status --porcelain` / `git diff --name-only` requirement
that treated the factory's own continuous generated-artifact churn (.ex5
builds, .set regen, EA SPEC.md/card mirrors, the recurring generator docs) as
"dirty." With the factory building continuously, the tree is close to never
byte-clean, so the mint step (`build_runtime_activation_decision.py`) almost
never opened — which blocks the whole `Factory_OFF -> mint -> Factory_ON`
chain, which in turn blocks `maintenance_control release-on-restart` for the
8 pending holds recorded in `dryrun_postpin.json` (this directory).

Fix: both gates now reuse `farmctl._repo_dirty_status`
(`qm-repo-dirty-classification/v2`, the same classifier the pump's
build-spawn dirty guard already relies on) — known-generated outputs never
block; source/tools/registry/untracked human work still does. The
post-normalization re-check keeps its raw `git diff`/`git diff --cached`/
`git ls-files --others` form (porcelain status can false-positive on the
CRLF autocrlf-normalization case it exists to tolerate — verified by the
pre-existing `test_builder_self_verifies_candidate_and_preserves_crlf_normalization`
test, which failed against a first draft that used `_repo_dirty_status` for
that check too) but applies the same generated-path allowance by bare path,
reusing `farmctl._generated_ea_artifact_kind` /
`farmctl._generated_recurring_doc_kind`.

Commit: `0adc06a4f9` on `agents/board-advisor`
(`tools/strategy_farm/build_runtime_activation_decision.py`,
`tools/strategy_farm/tests/test_build_runtime_activation_decision.py`).

Tests run (canonical checkout `C:\QM\repo`, all pass):
- `tests/test_build_runtime_activation_decision.py` — 9 passed (8 pre-existing
  + 1 new: generated-artifact churn does not block, a tracked source edit
  still does).
- `tests/test_factory_runtime_activation.py`,
  `tests/test_factory_off_build_interlock.py`,
  `tests/test_artifact_autocommit_source_guard.py`,
  `tests/test_mnt012_build_guards.py` — 52 passed, unchanged.

## Part 2 — OFF->ON ceremony + release-on-restart --apply (NOT RUN — deferred)

Acceptance also asked to, "in an idle-fleet window," run the Factory
OFF->ON ceremony and `maintenance_control release-on-restart --apply` for the
8 holds (dry-run plan already captured in `dryrun_postpin.json`, this
directory, from the predecessor task 221e4e91/0ceeea69 lineage).

Checked live fleet state twice during this cycle
(`farmctl.py mt5-slots`, read-only):
- `2026-09-20T08:21:48Z`: T6 (QM5_41347/NDX.DWX, OPT_CENSUS) and T9
  (QM5_41347/NDX.DWX, OPT_CENSUS) actively running.
- `2026-09-20T08:25:31Z`: T6 and T7 actively running (4 terminal64 processes
  total).

This is not an idle-fleet window. Hard rule: "Do not interrupt active T1-T10
backtests unless OWNER explicitly says so." Running `Factory_OFF.ps1` now
would kill those active work items. Deferring the OFF->ON ceremony and the
`--apply` release is correct under the task's own precondition, not a
shortfall — Claude/OWNER standing authorization to self-drive the
Factory_OFF -> mint -> Factory_ON chain
(`feedback_claude_runs_factory_on_off_2026-08-13`) still applies once a
window opens.

**Next step:** re-run `farmctl.py mt5-slots` when picking this back up; once
`running_mt5_terminals` is empty (or only idle-safe), run
`Factory_OFF.ps1` -> `build_runtime_activation_decision.py` (now unblocked by
Part 1) -> `Factory_ON.ps1 -CanonicalRuntimeHost -NoPause` (PS5.1 host only)
-> `maintenance_control release-on-restart --apply` for the 8 work-item IDs
in `dryrun_postpin.json`, then record OFF/ON + release receipts in this
directory.
