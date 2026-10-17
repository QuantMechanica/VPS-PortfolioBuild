# Task c6979815 — router landing-gate verdict-reparsing bug: NOT ACTIONABLE in this lane

Generated: 2026-10-17T09:39:37Z (Claude orchestration cycle, worktree
`agents/claude-orchestration-2`, lane head `b8371bb55a77460e6f68c616c3a11f9fa6e3050a`).

## Task as routed

Title: "Router bug: failed close-review writes 'UNLANDED: <short hashes>' into
the stored verdict, which the landing gate then re-parses as cited source
commits -> every retry fails until the verdict is rewritten"

Requested fix: (1) the landing gate must not parse router-generated notices
(`UNLANDED:`/`LANDING_CONFLICT:` prefixes) as task citations, or a refused
close must not overwrite the lane verdict (store the notice in a separate
payload field); (2) document the out-of-range citation scoping; tests
reproducing refuse-then-retry; land with explicit pathspecs.

## Finding: the subsystem this bug lives in does not exist in this checkout

Grepped this entire worktree (`tools/strategy_farm/**/*.py`) for every term
the task description and the two related in-flight tasks on this same lane
(`af1e6342`, `90f1a25d`) use to name the mechanism:

```
UNLANDED, cited_commit, landing_gate, LANDING_CONFLICT, unlanded_cited_commits,
REVIEW_REF_MISSING, publish_review_artifacts
```

Zero matches anywhere under `tools/strategy_farm/` in this worktree. Specifically:

- `tools/strategy_farm/lane_evidence.py` — **does not exist** in this worktree
  (`ls` -> No such file or directory). On canonical (`C:/QM/repo`, currently
  `agents/board-advisor` @ `bb06b6068b23a237f008996a097728d229a2f2c9`) this
  file is 912 lines and contains the `cited_commit_unresolvable` /
  `_ordered_activation_commits` logic the task description refers to.
- `tools/strategy_farm/run_agent_orchestration_task.py` in this worktree is
  **418 lines** with no landing-gate code at all (only two unrelated
  docstring mentions of the word "verdict"). The canonical copy on
  `agents/board-advisor` is **7,765 lines** and contains the actual
  `UNLANDED` classification path (`run_agent_orchestration_task.py:3339`,
  `:3360`, `:3385`, `:3398`, `:3470`, `:3599`, `:3723`, `:3748`, `:4035`,
  `:4048`, `:4559`) plus `cited_commit_outside_task_range` (`:1421`) — this
  is the exact code the task is asking to be fixed.
- `tools/strategy_farm/agent_router.py` in this worktree is **930 lines**;
  canonical is **6,873 lines**. The `close_review_task()` function present
  in this worktree (lines 720-782) just stores whatever `--verdict` string
  the caller passes — it has no notice-generation or re-parsing logic. The
  bug the task describes (a *different*, much larger `close-review`/landing
  pipeline overwriting the stored verdict with a generated `UNLANDED:` notice
  that a later pass re-parses as cited commits) is implemented in code that
  is not present here.

## Root cause: lane divergence, not a missing grep term

```
git -C C:/QM/repo rev-list --count bb06b6068b23a237f008996a097728d229a2f2c9 ^b8371bb55a77460e6f68c616c3a11f9fa6e3050a
  -> 26662   (commits on board-advisor not on this lane)
git -C C:/QM/repo rev-list --count b8371bb55a77460e6f68c616c3a11f9fa6e3050a ^bb06b6068b23a237f008996a097728d229a2f2c9
  -> 504     (commits on this lane not on board-advisor)
git -C C:/QM/repo merge-base b8371bb... bb06b606...
  -> 1bea1f58b8f68f506c88cb9d0380d6b95bdd13f9
```

This lane (`agents/claude-orchestration-2`) diverged from canonical 26,662
commits ago and has accumulated 504 of its own commits since (mostly
per-cycle idle/evidence journal commits) — not a fast-forward case. This is
the same structural blocker already evidenced twice on this lane:

- `docs/ops/evidence/task_af1e6342-0223-4df1-aa0f-b0e0af697455/README.md`
  ("Addendum 2026-10-15") — a *fix* was made here and blocked from landing by
  the (canonical-only) landing gate.
- `docs/ops/evidence/task_90f1a25d-6476-46c0-a593-3dd44cc71626/` — same
  landing-conflict class, different task.

Task c6979815 is a third instance of the same root problem, but one step
further back: it is not a landing-conflict on a fix made here, it is that
the code to be fixed is **absent from this checkout entirely**, so no
reviewed, tested change can be authored in this lane at all. Writing a
from-scratch reimplementation of a 912-line module (`lane_evidence.py`) and
a multi-thousand-line slice of `run_agent_orchestration_task.py` from
first principles, without the surrounding ~15,500 lines of code it actually
integrates with in this checkout, would not be a verifiable fix of the real
bug — it would be speculative new code diverging further from canonical.

## Disposition

Not actionable in `agents/claude-orchestration-2`. No code change made; no
regression risk introduced. Recommend this task be re-pointed (by
OWNER/board-advisor close-out) to a lane that is current with canonical
(e.g. `agents/board-advisor` itself, where `lane_evidence.py` and the
`UNLANDED` classification path in `run_agent_orchestration_task.py` actually
exist at the line numbers cited above) so the fix can be authored and
exercised against the real code and its existing test suite.

Task remains blocked on lane staleness, same class as `af1e6342` /
`90f1a25d`. Leaving in `REVIEW` per orchestration-cycle instructions (no
self-approval; main/board-advisor integration is OWNER+Claude close-out
only).
