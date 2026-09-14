# C2A pending-binding rebind planner — tool + tests (2026-09-15)

Complementary to the peer session's `2026-09-15_artifact_binding_drift_census2/`
(census + plan) and commits `f26343889e` (item 2) / `bdb2b7f6d6` (RESULT items 1/3/4)
for router task `42ff3c7a`. That delivery noted *"No dedicated `--dry-run` rebind tool
was run"* — this fills acceptance criterion 1's **Tool + tests** requirement.

## What this adds
`tools/strategy_farm/pending_binding_rebind_plan.py` — a **dry-run-only** governed
planner for the C2A cluster (pending rows across Q02..Q14 whose pinned
`expected_*_sha256` went stale after a **committed** artifact regeneration).
`farmctl requalify-q02`/`rebind-q02` refuse these
(`source_not_eligible_q02_pending_or_terminal`: Q02-terminal sources only), so no
existing command plans them as a set. The planner reads `plan.json` (the C2A list) and
the DB read-only, hashes the current committed on-disk artifacts, and per row/role emits
`bound_sha256` vs `current_sha256`, an `OK/DRIFT/MISSING` classification, the committed
git provenance of the current file, and the exact governed successor command a *blessed*
apply path would run. **`--apply` is refused** — rebinding a pinned SHA on a live pending
row is a mutation requiring orchestrator REVIEW + an established backed-up/receipted path;
this planner claims no such authority.

Tests: `tools/strategy_farm/tests/test_pending_binding_rebind_plan.py` (5, PASS) —
DRIFT→rebind-eligible+successor cmd, MISSING→blocked, OK→not eligible, `--apply` refused,
and a read-only invariant (plan run does not change the DB mtime).

## Generated plan (this folder)
`c2a_rebind_plan_dryrun.json` — run against the peer's current
`2026-09-15_artifact_binding_drift_census2/plan.json`: **35/35 C2A rows rebind-eligible**
(all pending, drift present, none MISSING), `plan_sha256`
`4e2eb7b2cf2202f3e93135314ea021da8f03404e9fa97df45d6e03f48c1c3198`. Nothing applied.
Before any apply, each drifted binary must be confirmed a faithful rebuild vs a recompile
(recompile in active inventory is ROT → OWNER).

## Provenance note
Produced by a duplicate `claude` session that raced task `42ff3c7a`. Items 2/3/4 and the
item-1 census/plan were delivered first by the peer; only this reusable tool + tests +
regenerated plan is net-new. No competing edits to the peer's files, no task-state change.
