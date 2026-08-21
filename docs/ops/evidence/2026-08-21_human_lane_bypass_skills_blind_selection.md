# P1 — the OWNER video lane was bypassed by a second, skills-blind selection path

**Date:** 2026-08-21 · **Author:** Claude (Orchestrator) · **Ticket:** `eb2dc100`
**Class:** routing integrity, verdict-neutral · **Status:** root cause located, fix commissioned

## What happened

At 16:0x I wired OWNER as the assignee of the `video_analysis` lane (`bac260780`): a declared but
disabled `owner` lane, a visible hold with reason `awaiting_human_lane:owner`, 29 passing router
tests, and a live proof that ticket `4b52f1b2` (three XAGUSD videos, screening scope) was held.

At **18:08:19Z the same ticket was assigned to `gemini`**, which produced a confident screening
report classifying all three videos as discretionary and recommending that the blocked predecessor
`d2bc5e78` be closed as OBSOLETE.

agy has no video tool (verified three times on 2026-07-12) and this host is bot-blocked on
YouTube — re-proved today: fetching those exact three URLs returns YouTube's footer, no title, no
channel, no duration.

## Root cause — a second door

`agent_router.route_once` gates on skills correctly:

```python
skills = set(json.loads(task["required_skills_json"] or "[]"))
required |= skills & (declared_caps | governed_caps)
```

`tools/strategy_farm/run_agent_orchestration_task.py::_quota_lane_candidates` does not:

```python
required = set(json.loads(row["required_capabilities_json"] or "[]"))
...
if not assigned and capabilities is not None and not required.issubset(capabilities):
    continue
```

It reads `required_capabilities_json` **only** and never `required_skills_json`. Ticket
`4b52f1b2` carries `required_capabilities = ["research","strategy"]` with
`required_skills = ["video_analysis"]`, so to this path it is ordinary research work — and gemini
has research and strategy.

Every skills-based gate is invisible here, not just the human lane.

**Evidence that the router itself worked:** the task payload still carries the
`router_human_lane_hold` marker written when `route_once` held it. The live registry at review
time is correct — gemini has no `video_analysis`, `owner` does. The hold was right; something
else picked the ticket up.

**Precedent, from the router's own comment:** *"Routing was skills-blind and put two OWNER video
tickets on codex while gemini was full (2026-07-07)."* That fix was applied to `route_once` and
never to the lane spawner. The same defect, in the other path, fourteen months of operating days
later.

## Why the artifact was rejected

Not because the conclusion is necessarily wrong — three retail silver videos being discretionary
is entirely plausible. Because **there is no observation behind it**:

- it names a title and author for all three videos and describes what each one shows;
- it discloses **no access method** anywhere — no transcript fetch, no `fetch_transcript.py`
  proxy run, no citation for where titles or content came from;
- it contains **not one `[hh:mm:ss]` timestamp**, though the task required a timestamp on every
  quoted rule and `NOT SHOWN` wherever a number never appears.

A screening report that never says how it knows is not evidence, whatever it concludes. Ticket
recycled; `d2bc5e78` stays BLOCKED and is **not** closed as OBSOLETE on this artifact.

## Not re-enqueued yet — deliberately

Re-enqueueing the three videos now would hand them straight back to the same blind path. They go
back to OWNER once `eb2dc100` closes the second door.

## The fix, as commissioned

1. `_quota_lane_candidates` applies the same rule as `route_once`.
2. A candidate only a human lane can satisfy is never offered to an AI lane — reuse
   `agent_router._human_lane_holder`, do not reimplement the concept.
3. Test across **all three** AI lanes, not only gemini.
4. **Audit every other place that selects agent work by capability.** A second door means there
   may be a third; the full list gets reported even if only one needed fixing.
5. Report whether any other skills-gated ticket was executed by a lane lacking the skill.

Explicitly refused as a fix: moving `video_analysis` into `required_capabilities` on the ticket.
That hides this instance and leaves the next skills-gated capability to fall through the same hole.

## The general lesson

A guard proven in one code path is not proven in the system. The router test suite passed, the
live routing proof passed, and the ticket still reached a lane that could not do the work —
because the proof covered the door I was looking at.
