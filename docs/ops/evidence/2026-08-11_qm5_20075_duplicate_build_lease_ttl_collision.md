# QM5_20075 Duplicate Build — Shared "claude" Lease Pool vs. Build Duration

**Date:** 2026-08-11 (observed ~2026-08-10T23:00-23:30Z)
**Reporter:** Claude (claude-orchestration-2 headless cycle)
**Severity:** Process/infra finding, not a live-trading or data-integrity risk. No merge has happened yet on either side.

## What happened

Router task `81793202-f0ec-45d3-9e99-96c1a619a626` (build_ea, EA ID
QM5_20075, slug `camarilla-inner-pivot-fade`, `target_agent_profile: codex`
capacity-spilled to claude) was processed end-to-end in
`C:/QM/worktrees/claude-orchestration-2` (branch `agents/claude-orchestration-2`):
registry rows appended, resolver regenerated, `.mq5` implemented, build_check
PASS, compile PASS (commit `e33888d3e`), router moved to REVIEW.

During that same build, a **second, independent** working copy of QM5_20075
was found sitting untracked in `C:/QM/worktrees/claude-orchestration-3`
(branch `agents/claude-orchestration-3`):

```
framework/EAs/QM5_20075_camarilla-inner-pivot-fade/QM5_20075_camarilla-inner-pivot-fade.mq5   (mtime 2026-08-11 00:50 local)
framework/EAs/QM5_20075_camarilla-inner-pivot-fade/QM5_20075_camarilla-inner-pivot-fade.ex5    (mtime 2026-08-11 01:03 local)
framework/EAs/QM5_20075_camarilla-inner-pivot-fade/SPEC.md                                     (mtime 2026-08-11 00:51 local)
framework/build/compile/20260810_225134/QM5_20075_camarilla-inner-pivot-fade.compile.log
framework/build/compile/20260810_230322/QM5_20075_camarilla-inner-pivot-fade.compile.log
```

`framework/registry/magic_numbers.csv` in worktree-3 also carries 5 rows for
`20075` dated `2026-08-11` attributed to `Claude` (magic_base 200750000,
slots 0-4, same 5 symbols as the card). `framework/include/QM/QM_MagicResolver.mqh`
in worktree-3, however, only contains 2 matches for "20075" — i.e. the
resolver was not (yet, or not correctly) regenerated to include those 5
rows at the time that worktree's `.ex5` was compiled. Net effect: the
worktree-3 binary is a real second implementation of the same card, built
independently and concurrently, and — per the build agent operating in
worktree-2's own read of the situation — likely fails `OnInit` with
`EA_MAGIC_NOT_REGISTERED` against its own resolver snapshot.

Neither copy has been committed on its own branch as of this writing
(worktree-3's is still untracked `??` in `git status`), so nothing has
merged to main and there is no live conflict yet — but if both branches
merge independently, `framework/EAs/QM5_20075_camarilla-inner-pivot-fade/`
will collide, and only one implementation should survive review.

## Root cause

`agent_router.py`'s task lease (`agent_task:<task_id>`,
`LEASE_TTL_MINUTES = 30`, see `tools/strategy_farm/agent_router.py:60`) is
keyed only by `task_id`, and the `assigned_agent` field for claude-profile
work is the bare string `"claude"` — not scoped per worktree/session the
way codex's board-advisor lane is (`"codex:agents/board-advisor"`). Multiple
`claude-orchestration-N` headless cycles draw from the same shared "claude"
capacity pool. Observed build durations this cycle for a single EA
(card read → registry append → resolver regen → `.mq5` write → build_check →
compile → setfile gen → smoke attempt) via a dedicated subagent were
**15-26 minutes each** even without contention; under session overlap or
MT5-fleet saturation this can plausibly exceed the 30-minute lease TTL. When
a lease expires mid-build, nothing prevents a second `claude-orchestration-N`
instance's `route-many`/`run` from picking up work bound to the same
ea_id/card again, because the two sessions have no visibility into each
other's in-flight (uncommitted) worktree state.

Corroborating: this cycle's own `list-tasks --agent claude` also surfaced
task `81681d73-c2b2-493c-add7-979dc133966c` (EA 20082,
connors-rsi2-pullback-h4) with a lease that had already expired
(`expires_at: 2026-08-10T23:21:29Z`, checked at `23:28:58Z`, ~7 min stale)
while `claude-orchestration-3`'s directory showed activity essentially
concurrent with this check — i.e. the same expired-lease-during-active-build
shape that produced the QM5_20075 duplicate. This task and a second
live-leased one (`cae7c583-a48e-4975-93d0-5f8bdd59c76f`, EA 20085,
lease live until `23:42:06Z`) were both deliberately **deferred, not
processed**, by this cycle specifically to avoid adding a third collision.

## Recommendation (not actioned by this cycle — infra change, OWNER/board-advisor call)

- Scope the claude lease/assignment the same way codex's board-advisor lane
  already is (e.g. `claude:agents/claude-orchestration-N`), so sibling
  sessions can't silently re-claim the same task_id after expiry while the
  original session is still working it, or
- Raise `LEASE_TTL_MINUTES` for `build_ea` task class specifically (30 min
  is tight against observed 15-26 min single-EA build time, before any
  smoke-test wait), or
- Have the router treat an EA directory that already exists as untracked/
  dirty content in ANY sibling worktree as a soft collision signal before
  handing the same ea_id out again.

## Disposition

Both worktree-2's build (committed, in REVIEW via the router) and
worktree-3's build (untracked, whatever state that session leaves it in)
should be dedup'd by whoever reviews/merges QM5_20075 — prefer whichever
build has a resolver that actually matches its registered magic rows
(worktree-2's `e33888d3e` regenerated the resolver after the CSV append,
per the build agent's report). This doc is the evidence trail; no
corrective action was taken against worktree-3's checkout (not mine to
touch, per worktree discipline).
