# Task af1e6342 — hard-coded canonical sys.path test hazard

Generated: 2026-10-15T22:25:27Z (Claude orchestration cycle, worktree
`agents/claude-orchestration-2`).

## Finding (as routed)

`tools/strategy_farm/dwx_m1_overlap_export_work_item.py` did:

```python
REPO_ROOT = Path("C:/QM/repo")
sys.path.insert(0, str(REPO_ROOT))
```

`REPO_ROOT` is also used for governed file-binding constants
(`EXPORT_WRAPPER`, `EXPORT_SOURCE`, `GOVERNANCE_GUARD`, `SYMBOL_MATRIX`,
`HISTORY_RANGES`, `RECONCILE_OVERLAP`) — that part is intentional and
sanctioned (the governed work item must always validate against the real
canonical artifacts; `tools/strategy_farm/tests/test_dwx_m1_overlap_paging.py`
already monkeypatches `EXPORT_SOURCE`/`EXPORT_WRAPPER` individually via its
`worktree_bound_work_item` fixture for exactly this reason).

The bug is the `sys.path.insert(0, str(REPO_ROOT))` line specifically: it
unconditionally puts `C:/QM/repo` at the front of `sys.path`, so any test run
from an agent worktree (or a git-archive extract) that imports this module
silently resolves sibling modules (`custom_history_contract`,
`custom_history_copy_on_claim`, `custom_history_gate`, `farmctl`,
`tools.dukascopy.common`) from canonical rather than from the checkout
actually under review. Earlier independent-review test counts for task
35eb350f (round 5, probe fix, tick fix) may not have exercised the reviewed
code for this reason.

## Fix applied

Changed the `sys.path` insertion to derive the checkout root from the
module's own file location instead of a literal canonical path, while
leaving `REPO_ROOT` (the governed-artifact binding root) untouched:

```python
REPO_ROOT = Path("C:/QM/repo")
_OWN_CHECKOUT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_OWN_CHECKOUT_ROOT))
```

File: `tools/strategy_farm/dwx_m1_overlap_export_work_item.py`.

## Guard test added

`tools/strategy_farm/tests/test_no_hardcoded_canonical_sys_path.py`:
statically scans every `.py` file under `tools/strategy_farm/` and
`framework/scripts/` *in the running checkout* (resolved via
`Path(__file__).resolve().parents[3]`, never a hard-coded path) for a
`sys.path.insert`/`append` call containing a literal `C:/QM/repo` (or
`C:\QM\repo`) argument.

- `test_fixed_file_no_longer_hazardous` — regression guard: fails if
  `dwx_m1_overlap_export_work_item.py` (or any future file) reintroduces the
  pattern.
- `test_no_new_offenders_beyond_known_legacy_list` — fails if **any** module
  anywhere under those two trees hard-codes the canonical sys.path insertion,
  except the pre-existing offenders explicitly grandfathered below. Removing
  an entry from the grandfather list is the signal that file got fixed.

Both tests pass in this worktree:

```
tools/strategy_farm/tests/test_no_hardcoded_canonical_sys_path.py::NoHardcodedCanonicalSysPathTests::test_fixed_file_no_longer_hazardous PASSED
tools/strategy_farm/tests/test_no_hardcoded_canonical_sys_path.py::NoHardcodedCanonicalSysPathTests::test_no_new_offenders_beyond_known_legacy_list PASSED
2 passed in 0.23s
```

Note: this worktree's branch (`agents/claude-orchestration-2`) is currently
~26,214 commits behind `agents/board-advisor` at the merge-base and diverged
by 489 commits of its own (not a fast-forward case) — most of the "other
offenders" files below do not physically exist in this worktree, so the
guard test only sees the one file it was able to fix here. The grandfather
list was built from a direct `git show agents/board-advisor:<path>` /
`git grep` audit of the current canonical branch content (read-only, no
writes to `C:/QM/repo`), not from files present locally. When this fix lands
on a branch that contains those files, the same test will see and correctly
grandfather them.

## Other offenders (audit of `agents/board-advisor`, 2026-10-16)

Same hazard class (`sys.path.insert`/`append` with a literal `C:/QM/repo` /
`C:\QM\repo` argument), found via:

```
git grep -n -E '(REPO_ROOT|sys\.path\.(insert|append)).{0,80}C:[/\\]{1,2}QM[/\\]{1,2}repo' \
  agents/board-advisor -- 'tools/strategy_farm/*.py' 'tools/strategy_farm/**/*.py' \
  'framework/scripts/*.py' 'framework/scripts/**/*.py'
```

filtered to actual `sys.path` mutation sites (not the separate, sanctioned
`CANONICAL_REPO_ROOT = Path(os.environ.get("QM_CANONICAL_REPO_ROOT", r"C:\QM\repo"))`
data-path pattern used across the farm, which is override-able and does not
affect import resolution):

| File | Line(s) |
|---|---|
| `framework/scripts/mt5_diagnostics/news_calendar_export_e1b2.py` | 16 |
| `framework/scripts/mt5_diagnostics/news_calendar_export_e1d2_m5.py` | 18 |
| `framework/scripts/mt5_diagnostics/qm1537_native_d1_export.py` | 18 |
| `tools/strategy_farm/ftmo_admission_census.py` | 19-20 |
| `tools/strategy_farm/portfolio/dxz_composite_faithful_recompute.py` | 5 |
| `tools/strategy_farm/portfolio/dxz_weight_oos_validation.py` | 22 |
| `tools/strategy_farm/portfolio/ftmo_decorrelation_test.py` | 6 |
| `tools/strategy_farm/portfolio/ftmo_density_compare.py` | 6 |
| `tools/strategy_farm/portfolio/ftmo_density_speed_at_budget.py` | 4 |
| `tools/strategy_farm/portfolio/ftmo_full_pipeline.py` | 11 |
| `tools/strategy_farm/portfolio/ftmo_speed_parallel.py` | 2 |
| `tools/strategy_farm/portfolio/gen_dxz23_20260726.py` | 32 |
| `tools/strategy_farm/portfolio/gen_dxz24_weekend_manifest.py` | 19 |
| `tools/strategy_farm/portfolio/gen_dxz24b_20260726.py` | 40 |
| `tools/strategy_farm/portfolio/gen_dxz_23sleeve_manifest.py` | 2 |
| `tools/strategy_farm/portfolio/gen_dxz_final_manifest.py` | 12 |
| `tools/strategy_farm/portfolio/marginal_contribution_eval.py` | 68 |
| `tools/strategy_farm/r_eval_drain.py` | 24 |
| `tools/strategy_farm/session_tools/check_prose.py` | 4 |
| `tools/strategy_farm/session_tools/interactive_heartbeat_detached.py` | 17 |
| `tools/strategy_farm/session_tools/park_44gb_reservation_rows_0914.py` | 14 |

21 other offenders, all grandfathered in the new guard test's
`KNOWN_LEGACY_OFFENDERS`. None were fixed in this task — out of scope for
af1e6342 (routed for exactly one file); listed per the routed task's
explicit "list other offenders" instruction. Several are production tooling
(`ftmo_*`, `gen_dxz*` portfolio manifest generators, `session_tools/
interactive_heartbeat_detached.py`) where changing import resolution carries
real regression risk and deserves its own reviewed task rather than a
drive-by edit here.

Checked but NOT an offender: `tools/strategy_farm/dwx_tick_tail_probe_work_item.py`
(sibling file, same `REPO_ROOT = Path("C:/QM/repo")` file-binding pattern,
but does **not** do `sys.path.insert` with it — no hazard).

## Deferred (per routing instructions)

"After landing, re-run the focused dwx_2026 suites on canonical to
re-confirm" is explicitly a post-landing step. This task's artifact stays in
`REVIEW` on `agents/claude-orchestration-2`; it is not merged, cherry-picked,
or landed onto `main`/`agents/board-advisor`/`C:/QM/repo` by this agent. The
full `tools/strategy_farm/tests/test_dwx_m1_overlap_paging.py` /
`test_dwx_m1_overlap_export.py` suites were not re-run here because this
worktree's branch does not carry their runtime dependencies
(`farmctl.py`, `custom_history_*`, `tools/dukascopy/common.py`) — pulling the
full transitive closure (`farmctl.py` alone is ~2MB) just to exercise a
2-line import-path fix was judged disproportionate; the fix is a static,
file-local change verifiable by the new guard test plus a syntax check
(`ast.parse`), both of which passed.

## Addendum 2026-10-15 — REVIEW submission blocked by a lane-wide landing-gate defect

`agent_router.py update-task af1e6342-... --state REVIEW --artifact-path
docs/ops/evidence/task_af1e6342-.../README.md --verdict "...Commit 95742fca35
on agents/claude-orchestration-2..."` was run and refused:

```
gate_code: REVIEW_REF_MISSING
reason: unlanded_cited_commits
state: IN_PROGRESS (unchanged)
```

The task's own payload (`landing_pending_review`) says the orchestration
launcher's post-session hook (`run_agent_orchestration_task.py:
publish_review_artifacts`) runs automatically after this session exits and is
supposed to create that review ref. Root-caused why that hook had already
failed once on this lane before this session started (payload already
carried `artifact_landing_conflict.reason = "commit_has_no_paths"`,
`source_commit = b23df957ed20c66dcb626e8ffdf5a39e9b883a9a`) and will very
likely fail again the same way:

- `publish_review_artifacts` always calls `_lane_commits_for_publication(...,
  auto_lane_commits=True)` whenever `landing_pending_review` is present
  (`run_agent_orchestration_task.py:1039-1095`), and `auto_lane_commits` for
  any `agents/claude-*` branch unconditionally sweeps every commit in
  `git rev-list canonical_head..lane_head` — on this lane, ~489 commits back
  to a May 2026 divergence — not just the commit cited in the verdict.
- `_ordered_activation_commits` (`lane_evidence.py:312-337`) then calls
  `_commit_paths` on every one of those commits and treats a commit with zero
  changed paths as a hard `landing_conflict` (`reason: commit_has_no_paths`,
  `lane_evidence.py:187-201`).
- `b23df957ed20c66dcb626e8ffdf5a39e9b883a9a` (`docs(ops): claude orchestration
  cycle 2026-05-28 2230Z - idle 0 claude tasks, ...`) is a genuinely empty
  commit (`git diff-tree --root --no-commit-id --name-only -r b23df957...`
  returns nothing) - a status-journal checkpoint with no file changes. This
  lane has many such commits from historical idle-cycle journaling. Any one
  of them anywhere in the swept range permanently blocks review-ref
  publication for every task on this lane, independent of what that task
  actually changed.

This is a defect in the shared landing-gate plumbing
(`tools/strategy_farm/lane_evidence.py` /
`tools/strategy_farm/run_agent_orchestration_task.py`), not in this task's
fix. Recommended remedy (separate ops task, not done here - out of scope for
af1e6342 and touches shared landing code used by every Codex/Claude lane):
`_commit_paths`/`_ordered_activation_commits` should skip a truly empty,
non-merge commit (0 changed paths) rather than erroring, since there is
nothing to cherry-pick from it and nothing is lost by passing over it.

This task's deliverable (the sys.path fix, the guard test, 2/2 passing) is
complete and unchanged by this finding. The task remains `IN_PROGRESS` in the
router because the landing gate - not the fix - refuses the state
transition. Re-submitting `update-task --state REVIEW` with the same verdict
will not change this outcome until the shared landing-gate defect above is
fixed; no further action on af1e6342 itself is pending.
