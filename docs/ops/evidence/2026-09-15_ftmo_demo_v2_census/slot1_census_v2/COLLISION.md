# Concurrent-session collision on ticket 42a437a4 (2026-09-15)

Status: **recorded, not committed.** No verdict, no gate, no live surface touched.

## What happened

`run_agent_orchestration_task.py --agent claude --max-sessions 3` (pid 21952, lease
`headless_orchestration:claude` acquired 2026-09-15 09:45:01Z) spawned three headless Claude
sessions at 09:45:04Z:

| slot | worktree | model | pid |
|---:|---|---|---:|
| 1 | `C:\QM\worktrees\claude-orchestration-1` | opus | 11492 |
| 2 | `C:\QM\worktrees\claude-orchestration-2` | sonnet | 18808 |
| 3 | `C:\QM\worktrees\claude-orchestration-3` | opus | 7576 |

The router had moved exactly three tasks to `IN_PROGRESS` for `claude` at 09:37:29Z and minted a
per-task spawn lease for each:

| priority | task | quota-gate model |
|---:|---|---|
| 78 | `42a437a4-9674-47ce-9ca9-80eba8a2bc91` (FTMO demo book v2 admission census) | opus |
| 76 | `c30eebc8-c655-4425-9c01-7dc43348992a` (claim starvation head-of-line preflight) | sonnet |
| 72 | `d2849e93-d018-44e9-a11f-41d7776a1cc6` (T1 tick-archive integrity) | opus |

`run_agent_slot` passes `slot_invocation(slot-1)` — i.e. `allowed_invocations[slot-1]`, a list
built in `_quota_lane_check` from the candidate query `ORDER BY priority DESC, updated_at ASC`,
each entry carrying its own `task_id` (`run_agent_orchestration_task.py:1695-1699`). So the
intended binding is slot *i* → task *i* of that ordering, and the observed per-slot models
(opus / sonnet / opus) match the per-task gate models exactly.

**But `build_prompt(agent, cwd)` emits the same generic prompt to every slot** — "for every
IN_PROGRESS task assigned to claude" — and never names the bound `task_id`. All three sessions
therefore see all three tasks.

Result: slot 1 and (at least) one sibling both worked ticket 42a437a4. At 11:59 local the sibling
overwrote `tools/strategy_farm/ftmo_demo_v2_census.py`; at 12:00 it overwrote
`docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/roster_ftmo_demo_v2.json` and `README.md`. Both
sessions had produced independent, internally consistent reworks of the same critique receipt.

This is the same class as the 2026-08-23 / 08-24 (×3) / 09-12 / 09-13 / 09-14 recurrences. The
2026-09-14 entry already identified `--max-sessions 3` as the smoking gun.

## What slot 1 did about it

1. Before starting work, slot 1 acquired a session-owned lease
   `agent_task_session:42a437a4-9674-47ce-9ca9-80eba8a2bc91` (owner pid 21088,
   host WIN-B95G5LPSJ1O, 09:49:52Z → 10:34:52Z) via
   `agent_scopes.acquire_spawn_lease(..., fail_open_on_error=False)`. The router's own
   `agent_task:<id>` leases carry `owner_token=NULL`, so they identify the *lane*, not a session,
   and cannot arbitrate between siblings.
2. On detecting the overwrite, slot 1 did **not** overwrite back — that is the mirror image of the
   same defect. Instead it restored `roster_ftmo_demo_v2.json` to the sibling's version
   (`git checkout`), removed its own leftovers from the shared names, and re-ran its analysis into
   this private `slot1_census_v2/` directory, which no sibling writes to.
3. **Nothing is committed.** Per the ratified defer-on-collision rule, a collision ends in REVIEW
   with both artifacts preserved and named, and the reviewer picks or merges.

## Why the two outputs differ (do not assume one is simply wrong)

Spot-checked divergences worth a reviewer's attention rather than a coin flip:

* Slot 1 concludes 1 ADMIT / 16 ADMIT_CONDITIONAL / 11 EXCLUDE, driven by a per-row binary-vintage
  predicate against `4fb47bd3b5` and by `QM_MagicSymbolCanonical` base-name matching.
* The sibling's header carries findings slot 1 did not derive — notably that `QM5_1537` keys its
  sealed monthly-sleeve CSV by the logical `.DWX` name and compares with `==`, so
  `strategy_calendar_symbol` must *stay* the `.DWX` name, and that `QM5_41470` canonicalises on
  both sides. It also reads the terminal's own `ftmo_demo_attach_map.json` and chart profile,
  sources slot 1 did not use.

A merge of the two is likely better than either alone.

## Recommendation (structural, for OWNER / the router owner)

The defect is one line of prompt construction, not agent behaviour. Either:

* **(a)** have `build_prompt` interpolate the slot's bound `task_id` (it is already in
  `allowed_invocations[slot-1]["task_id"]`) and instruct the session to work *only* that row; or
* **(b)** have each session acquire an owner-bound `agent_task_session:<task_id>` lease before
  starting and skip any task whose lease is live.

(a) is the smaller change and removes the race entirely; (b) is defence in depth. Until one lands,
every multi-session claude fan-out with more than one `IN_PROGRESS` row can duplicate work.

Evidence for every claim above: `D:/QM/strategy_farm/state/farm_state.sqlite` table
`spawn_leases`; `run_agent_orchestration_task.py` lines 206 (`build_prompt`), 1556-1559 (candidate
ordering), 1695-1699 (`allowed_invocations`), 1801-1806 (`slot_invocation`), 1823-1833 (fan-out);
`Win32_Process` command lines for pids 21952 / 7576 / 11492 / 18808.

## Resolution observed at 12:07 local (10:07Z)

The sibling **backed its own rework out**. As of this write:

* `tools/strategy_farm/ftmo_demo_v2_census.py` is clean at HEAD (commit `9a06adf9bd`, the
  v1 24-ADMIT / 4-EXCLUDE version).
* `docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/roster_ftmo_demo_v2.json` and `README.md`
  are clean at HEAD.
* `git status` for this ticket's paths shows only `slot1_census_v2/` (untracked).

So the sibling's concurrent artifact no longer exists on disk, and the divergences noted in the
previous section can no longer be diffed — they are recorded here from the header of the file as
it stood at 11:59, not from a surviving copy. The 1537 `strategy_calendar_symbol` claim in
particular is worth re-deriving independently before it is relied on.

The sibling *is* still working ticket `c30eebc8` (claim-starvation): `tools/strategy_farm/
dsr_cohort.py`, `terminal_worker.py` and two new test files carry uncommitted changes. Slot 1
has not touched those and does not review them here.

**Net state:** `slot1_census_v2/` is the only live rework of ticket 42a437a4. It is deliberately
*not* promoted onto the canonical `tools/` and shared evidence paths — promoting it would restart
the same race if the sibling re-runs. Promotion is a reviewer/OWNER step, not an autonomous one.
