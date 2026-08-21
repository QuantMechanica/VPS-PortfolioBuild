# Audit: who actually enforces the `required_skills` contract?

**Date:** 2026-08-21 · **Author:** Claude (Orchestrator) · **Feeds ticket:** `eb2dc100`
**Scope:** every code path that selects or gates agent work by capability
**Method:** read-only grep over `tools/`, `scripts/`, `framework/` excluding test files

This is the audit item of `eb2dc100`, done up front so the implementing lane bounds its change
instead of re-deriving the map — and so "we found nothing else" is a measured statement rather
than an assumption.

## The one-line finding

```
grep -rn "required_skills_json" --include=*.py tools/ scripts/ framework/ | grep -v /tests/
  -> tools/strategy_farm/agent_router.py   (all 7 hits, 3 of them schema/DDL)
```

**`required_skills_json` is read by exactly one module.** The skills contract has a single
enforcer and every other consumer is blind to it *by construction*, not by accident. That is the
structural statement behind the `4b52f1b2` bypass: it was never a question of whether the second
path had a bug, but of whether any path other than the router had ever implemented the contract
at all. None had.

## The complete map of capability-aware paths

| Path | What it does | Skills-aware? | Verdict |
|---|---|---|---|
| `agent_router.route_once` (`agent_router.py:968`) | assigns a task to a lane | **yes** — `required \|= skills & (declared_caps \| governed_caps)` | correct |
| `run_agent_orchestration_task.py::_quota_lane_candidates` (`:994-1014`) | **selects which work a spawned lane may take** | **no** — reads `required_capabilities_json` only | **the second door — this is the defect** |
| `run_agent_orchestration_task.py::claude_work_available` (`:827`) | pre-spawn *count*: should Claude wake at all | no — `required_capabilities_json LIKE '%"summary"%'` plus `budget_class IN ('premium','claude','owner')` | not an assignment path; see note below |
| `render_cockpit.py:1893` | renders the registry table | n/a | display only |

Nothing else reads `agent_registry.capabilities_json` outside tests.

## Two observations for the implementing lane

**1. `claude_work_available` is a wake-gate, not a door.** It counts candidate work to decide
whether spawning Claude is worthwhile; it never assigns. So it cannot hand a video ticket to a
blind lane. But it *does* count skills-gated tickets as spawn-worthy — so after the fix the lane
can wake for work it must then decline. That is wasted spawn, not a correctness bug, and it
should be made consistent in the same change rather than left as a puzzle for whoever next reads
a "woke up, took nothing" log line.

**2. `budget_class` already has an `owner` value** and that same query treats it as premium work
to wake Claude for. Worth deciding explicitly whether an OWNER-lane ticket should wake an AI lane
at all. My reading: it should not — but that is a small contract question, so it is stated here
rather than decided.

## What this bounds

The fix is **one** function, `_quota_lane_candidates`, and it should reuse
`agent_router._human_lane_holder` rather than reimplement the human-lane concept — two
implementations of one contract is exactly how this defect happened in the first place.

The test that would have caught it is not another router unit test. It is a system-level
invariant: *no work-selection path may offer a task to a lane that lacks a capability the task
requires, whether that requirement is expressed as a capability or as a skill.* One test,
parameterised over every path in the table above, so a future fourth path fails a test on the day
it is written instead of on the day it silently routes an OWNER ticket to a blind seat.

## Blast radius: how many other tickets went to a lane without the skill?

Measured over all **308** tasks carrying a non-empty `required_skills_json`, comparing each
assigned lane against the **current** registry:

| | |
|---|---:|
| tasks with a governed skill assigned to a lane lacking it (today's registry) | 6 |
| of those, genuine bypasses | **1** |

The other **5 are anachronisms, not violations**, and saying so matters: `fe1704fc`, `ae6c63e6`,
`e398f9d2`, `482fc9be` (gemini) and `3b1fe1ab` (codex) were all routed in July 2026, when gemini
still *declared* `video_analysis` — the capability was only moved to the `owner` lane today. They
were routed correctly against the contract as it stood. That the lane could not actually deliver
was the false-premise problem documented on 2026-07-12, not a routing bypass, and the closures
show it was handled honestly at the time: *"agy's unique deliverable — video ACCESS — is
descoped"*, *"Gemini correctly reported sandbox blocked"*, and `3b1fe1ab` which did obtain a
**4561-row transcript with proxy evidence**.

**So the answer to the acceptance question is: exactly one — `4b52f1b2`, today.** The second door
has been open for as long as `_quota_lane_candidates` has existed, but until today no ticket had
a skill requirement that the assigned lane genuinely lacked. The bypass did not create a backlog
of bad work; it created one bad artifact, on the first day it mattered.

Worth keeping from the July cohort: the captions-via-proxy route **has** produced real evidence
before (`3b1fe1ab`). It is not a substitute for watching — on-screen content stays a documented
GAP — but it is not a dead end either.

## Why the audit came first

`4b52f1b2` passed 29 router tests and a live routing proof and still reached a lane that could
not do the work. A guard proven in one path is not proven in the system. The cheapest defence
against that is knowing how many paths there are before you fix one of them.

## Implementation record — Codex

**Task:** `eb2dc100-58d3-4786-be6d-5622306f118c`
**Branch:** `agents/board-advisor`
**Status:** implemented; focused verification PASS; awaiting review

`tools/strategy_farm/run_agent_orchestration_task.py` now makes
`_quota_lane_candidates` apply the router's exact effective requirement:

```text
required = required_capabilities
required |= required_skills & (declared_registry_capabilities | governed_default_capabilities)
```

It calls `agent_router._human_lane_holder`, filters incompatible unassigned work and stale
pre-assignments, and leaves undeclared skill labels as descriptive metadata. The returned
candidate carries its effective requirements and budget class, so wake gates do not reimplement
the contract.

The wake-only paths now consume that filtered candidate set:

- `_agent_tasks_work_available` for Codex/Gemini, closing the practical Gemini wake path;
- `claude_work_available`, avoiding a wake for work Claude must decline.

The open contract question is resolved fail-closed: `budget_class=owner` alone does **not** wake
Claude. Compatible `premium`/`claude` work, `summary` work, and valid explicit Claude assignments
still do. The pre-filter SQL limit was removed so 100 incompatible high-priority rows cannot hide
eligible lower-priority work.

### Verification

```text
python -m pytest \
  tools/strategy_farm/tests/test_agent_selection_skill_contract.py \
  tools/strategy_farm/tests/test_agent_router.py \
  tools/strategy_farm/tests/test_agent_orchestration_lock.py \
  tools/strategy_farm/tests/test_run_agent_orchestration_heartbeat.py \
  tools/strategy_farm/tests/test_quota_spawn_gate.py -q

69 passed in 24.76s
```

The new system invariant covers `route_once`, quota candidates for Gemini/Codex/Claude, both
wake-gate classes, stale incorrect assignments, governed-default enforcement during live
registry drift, and descriptive non-governing skills. Existing router, lock, heartbeat, and quota
tests remain green.

Read-only live smoke after the fix:

```text
codex:  status=ok, candidates=[eb2dc100-...], work_available=true
gemini: status=ok, candidates=[], work_available=false
claude: status=ok, candidates=[], work_available=false
```

A re-scan at implementation time found 308 non-empty skill rows, 53 whose skills intersect the
current declared/governed capability universe, and the same six current-registry mismatches.
The temporal audit conclusion above remains authoritative: five are July contract anachronisms;
`4b52f1b2` is the sole genuine skills-blind bypass.

No terminal, AutoTrading, work-item, setfile, phase, pipeline verdict, or deployment state was
changed.
