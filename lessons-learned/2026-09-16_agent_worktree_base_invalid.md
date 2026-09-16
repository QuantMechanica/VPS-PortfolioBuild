# 2026-09-16 - AGENT_WORKTREE_BASE_INVALID: agents committed on stale `main` in a shared worktree

Issue: two write-capable agents committed against a stale local `main` checked out in a
shared worktree; the commits were not on the canonical line and had to be cherry-picked
into `agents/board-advisor` afterward (plus byte-equivalence verification).

## Incident

- Canonical orchestration base: branch `agents/board-advisor` at `C:\QM\repo`.
- Local `main` in that checkout is stale: thousands of commits behind `origin/main`
  and 14 ahead (diverged long ago).
- A shared worktree at `C:\QM\worktrees\kimi-readmodels-20260916` had `main` checked out.
- Two write-capable agents ran there and committed to `main`.
- One agent's receipt was folded into another lane's commit via `git commit --amend`,
  destroying the original receipt commit boundary.
- Recovery: cherry-pick the commits onto `agents/board-advisor` + byte-equivalence
  verification of the recovered content.

## Root cause

No base verification before write work. An agent that is about to edit/commit had no
deterministic gate answering: "Am I on the canonical branch, in the canonical checkout,
descendant of the orchestration base, and not colliding with another active agent's
claimed paths?" Any plausible-looking checkout was accepted silently.

## Fix (OWNER mandate 2026-09-16)

Fail-closed, deterministic, read-only preflight:
`tools/strategy_farm/agent_worktree_preflight.py`.

Checks (each emits a structured finding):

1. `EXPECTED_BASE_BRANCH` — current branch == expected canonical branch
   (default `agents/board-advisor`; `--expected-branch` / env `QM_AGENT_EXPECTED_BRANCH`).
2. `EXPECTED_REPO_PATH` — absolute repo root == expected path (default `C:/QM/repo`;
   env `QM_AGENT_EXPECTED_REPO_PATH`). Fails closed inside `.claude/worktrees/*` or
   `*/QM/worktrees/*` unless `--allow-worktree PATH=BRANCH` names an exact pair.
3. `NOT_STALE_MAIN` — never write on `main`; fail closed always. The tool never
   auto-resets and never rebases — a stale-`main` failure means a human/orchestrator
   moves the work, not the agent.
4. `BASE_DESCENDANT` — HEAD contains (descendant of, or equals) the orchestration base
   (default: tip of `origin/agents/board-advisor` as fetched **locally**; env
   `QM_AGENT_BASE_COMMIT` overrides). The tool never fetches; it trusts local refs, so
   the normal fetch cadence must happen outside it.
5. `PATH_OWNERSHIP` — declared `--paths` are scanned against active `spawn_leases`
   (unexpired) and `agent_tasks` (state TODO/IN_PROGRESS/REVIEW) in
   `D:/QM/strategy_farm/state/farm_state.sqlite`. Prefix overlap = reported finding;
   direct collision with another task's claim = hard failure.

Exit-code contract:

- `0` = PASS — one JSON line with `status`, `branch`, `head`, `base`,
  `is_descendant`, and `lease_scan` counts.
- `2` = any hard check failed — exactly one line:

```
AGENT_WORKTREE_BASE_INVALID {"check":"<first-failed-check>","failed_checks":[...],"detail":{"task":...,"worktree":...,"branch":...,"head":...,"base":...,"stale_by":...,"collisions":[...]}}
```

The tool is read-only: it never edits git state, never resets, never rebases, never
fetches, and opens the farm DB in read-only mode.

Tests: `tools/strategy_farm/tests/test_agent_worktree_preflight.py` — 11 hermetic tests
(temp git repos via subprocess, tmp sqlite, env-overridden canonical values). Cover:
canonical-shaped PASS, `NOT_STALE_MAIN` fail, behind-base fail with `stale_by`,
HEAD==base PASS, fabricated active-lease collision fail, expired-lease release,
prefix-overlap finding-only, `--allow-worktree` exact-pair PASS, wrong-branch pair
fail, forbidden worktree dir fail-closed, unresolvable base fail-closed.

## Usage contract

Every write-capable agent/run MUST pass this preflight before its first edit, in the
checkout it is about to write:

```bash
python tools/strategy_farm/agent_worktree_preflight.py --task-id <task-id> --paths <paths-it-will-write>
```

- Exit 0 → proceed.
- Exit 2 → STOP. Do not reset, do not rebase, do not "just commit somewhere". The run
  emits the `AGENT_WORKTREE_BASE_INVALID` line above; the orchestrator/human replays
  the work onto the canonical base.
- Writing without a recorded PASS for the same checkout+HEAD is an incident-class
  violation, same as the one this entry was written for.
