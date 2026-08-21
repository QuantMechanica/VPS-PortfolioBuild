# MNT-011 repo-dirty build-guard evidence — 2026-08-21

Router task: `df0cfed8-cc0c-431d-a13b-be914eee3bc3`

Status at this handoff: implementation and deterministic absorption are complete,
but the router task remains `IN_PROGRESS`. The acceptance condition requiring a
real post-fix build spawn and recovery of `codex_zero_activity` has not yet occurred.
An unrelated human edit to `CLAUDE.md` correctly remains build-blocking, and the
scheduled pump also reported an orphan lock below. Neither was altered.

## M011-1 — measured live classification

Reproduction commands:

```powershell
git status --porcelain=v1 --untracked-files=all
python -c "import json,sys; sys.path.insert(0,r'C:\QM\repo\tools\strategy_farm'); import farmctl; print(json.dumps(farmctl._repo_dirty_status(farmctl.REPO_ROOT),indent=2))"
```

The pre-fix all-file census contained exactly 205 entries:

| Origin/class | Count | Disposition |
|---|---:|---|
| generated card mirror (`*/docs/strategy_card.md`) | 89 | retained on disk; ignored for new/untracked copies |
| compiled EA binary (`*.ex5` directly in a canonical EA directory) | 34 | generated; guard-irrelevant and batch-committed |
| untracked canonical EA scaffold (`<EA label>.mq5`) | 40 | generated only while `??`; batch-committed |
| generated setfile (`sets/*.set`) | 7 | generated; guard-irrelevant and batch-committed |
| generated `SPEC.md` | 34 | generated; guard-irrelevant and batch-committed |
| human-edited source/documentation | 1 | `CLAUDE.md`; remains build-blocking and untouched |
| **Total** | **205** | **204 generated, 1 human** |

Mirror provenance was checked against
`D:\QM\strategy_farm\artifacts\cards_approved`: 87/89 were byte-identical to
the approved card of record. The remaining two (`QM5_38006` and `QM5_38008`)
differed only in horizontal whitespace in an ASCII state diagram. No mirror was
deleted. Historical tracked mirrors are unaffected by the ignore rule.

Classification is status-aware and fail-closed:

- only an **untracked** canonical `<EA label>.mq5` is generated scaffolding;
- any tracked/modified `.mq5` is human source and blocks;
- exact EA binaries, setfiles, `SPEC.md`, and card mirrors are build products;
- everything else blocks, including `tools/`, `scripts/`, `framework/include/`,
  `framework/scripts/`, `framework/registry/`, ordinary `docs/`, malformed git
  status, and arbitrary EA-directory content.

The guard now asks git for `--untracked-files=all`, so each file is classified
instead of accepting a collapsed directory as a unit. Its health payload reports
`total_count`, `generated_count`, `generated_by_class`, and
`blocking_by_class` under schema `qm-repo-dirty-classification/v2`.

## M011-2 — two-direction guard verification

Implementation commits:

- `bfce1fa3a` — status-aware guard, batch absorption support, mirror disposition,
  and regression tests.
- `6aa4b5543` — aligns the absorption safety contract with the implemented scope.

Focused verification:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_mnt011_dirty_guard.py \
  tools/strategy_farm/tests/test_artifact_autocommit_source_guard.py \
  tools/strategy_farm/tests/test_auto_build_routing.py

41 passed, 12 subtests passed in 8.19s
```

The generated-only fixture includes a card mirror, `SPEC.md`, `.ex5`, `.set`,
and untracked canonical `.mq5`; it produces `blocked=false`, leaving the existing
pump build budget open. The opposite fixture covers tracked EA `.mq5`,
`framework/include/*.mqh`, `tools/*.py`, both script roots, a registry, and an
ordinary ops document; all seven remain blocking. The existing per-EA test also
confirms that a modified tracked `.mq5` prevents its matching `.ex5` from being
published.

No dirty-repo override was set or used.

## M011-3 — batch absorption

Before mutation, `inspect_artifact_auto_commit_plan()` returned:

```text
valid=true
dirty_count=119
candidate_count=115
skipped_active_paths=[]
skipped_source_dirty_paths=[]
rejected_dirty_paths=[.gitignore, CLAUDE.md, farmctl.py, test_mnt011_dirty_guard.py]
```

After the implementation commit removed its three paths from the rejected set,
the same deterministic helper committed all 115 generated paths in one batch:

```text
commit bfd467bc6 — build: pump auto-commit 115 factory artifact path(s)
committed=true
n_paths=115
skipped_active_build_eas=[]
rejected_dirty_paths=[CLAUDE.md]
```

The immediate post-absorption guard result was exactly one entry:

```json
{
  "blocked": true,
  "count": 1,
  "total_count": 1,
  "generated_count": 0,
  "blocking_by_class": {"other": 1},
  "entries": [" M CLAUDE.md"]
}
```

This demonstrates that the generated backlog was drained as a batch and that the
remaining refusal is the intended human-source side of the contract. No untracked
EA content was deleted, no factory or terminal was started, and no active backtest
was interrupted.

The next real build-lane write supplied an additional status-aware observation:
an untracked canonical `QM5_41088_xauxag-wclv-div-rv.mq5` appeared while
`CLAUDE.md` remained modified. The guard reported `total_count=2`,
`generated_count=1`, but still `count=1` with only `CLAUDE.md` in `entries`.
Thus fresh generated scaffolding no longer increases the blocking count even
before the next absorption cycle.

## M011-4 — applied disposition

- The 89 untracked card mirrors remain in their EA directories and are ignored by
  `framework/EAs/QM5_*/docs/strategy_card.md`. They are redundant locality copies;
  the approved card on `D:` remains the record.
- Untracked canonical `.mq5` scaffolds and `SPEC.md` are real build content. They
  were committed, together with available `.ex5` and setfiles, by `bfd467bc6`.
- Modified tracked `.mq5` is never auto-classified as scaffolding and is never
  absorbed by this rule.
- Ordinary documentation, tools, scripts, includes, and non-allowlisted registry
  content remain fail-closed.

## Real health before/after and remaining acceptance gap

The cycle's initial health run was `overall=FAIL`; `codex_zero_activity` reported
zero direct Codex build activity in three hours while 37 `build_ea` tasks were
pending. MNT-011's task payload attributed the build refusal to roughly 165–199
porcelain entries; the exact all-file census above resolved that collapsed range
to 205 files.

Post-fix command:

```powershell
python tools/strategy_farm/farmctl.py health
```

At `2026-08-21T09:37:53Z`, health was still `overall=FAIL` (30 OK, 9 WARN,
4 FAIL). `codex_zero_activity` still reported 0/37. The health snapshot saw three
human-class changes (`CLAUDE.md` plus two concurrently authored QM5_41088 G0
files); the G0 files were subsequently committed by their owner in `b51b2de24`,
leaving `CLAUDE.md`. The guard is therefore no longer blocked by the 204-item
generated pool, but a real generated-only pump/build-spawn observation is not yet
possible without overriding or consuming someone else's human edit.

The same health run also reported `pump_task.lock` owned by dead PID 11748, age
524 seconds, with the scheduler instructed to wait for the 1200-second stale-lock
threshold. Per task constraints, this cycle did not remove the lock or invoke the
pump manually.

Required continuation before REVIEW:

1. Allow the owner of `CLAUDE.md` to commit or otherwise resolve that edit.
2. Observe one scheduler-owned full pump cycle using `bfce1fa3a` or later.
3. Record `repo_dirty_build_guard.blocked=false` with generated-only churn and a
   real build spawn.
4. Re-run health and record recovery of `codex_zero_activity` before moving the
   router task to `REVIEW`.
