# SP-C6 — Recurring Governor Dry-Run Watch

Date: 2026-08-23

Router task: `96eb3708-4c3a-407c-aaf5-3533ecabd036` (`SP-C6`)

## Verdict

IMPLEMENTED (dry-run only, not yet scheduled). `SP-C1`
(`5c02a347-e91c-44e3-b592-6dad7c6f4d81`) is `APPROVED`, so its dependency is
satisfied. `SP-C1`'s own evaluator (`account_portfolio_governor.py`) is a
pure, stateless function of one snapshot; it proved the staged escalation
logic but nothing observed it *over time*. This task adds
`tools/strategy_farm/governor_dry_run_watch.py`, a thin recurring wrapper
that re-evaluates the governor on every invocation, persists state across
runs, and turns level transitions into durable alarm/recovery evidence —
without adding any new authority, execution path, or AutoTrading control.

## What it does

- Calls the unmodified `account_portfolio_governor.evaluate()` against the
  live snapshot (`--snapshot`, default the deployed
  `account_snapshot.json`) plus optional hash-bound policy/emergency-policy
  files, exactly as `account_portfolio_governor.py`'s own CLI does.
- Persists `last_level` / `last_level_name` across runs in
  `D:\QM\reports\state\governor_dry_run_watch_state.json`.
- Appends a plain-text line every run to
  `D:\QM\reports\state\governor_dry_run_watch.log` (steady-state visibility).
- Appends the full decision JSON every run to
  `D:\QM\reports\state\governor_dry_run_watch_history.jsonl` — durable,
  append-only evidence that every recognized position/order ticket was
  detected on every run (Hard Rule: evidence needs a log path, not a claim).
- Appends one entry to the shared `D:\QM\strategy_farm\state\health_alarms.log`
  **only on a level transition**: `ALARM` when the level increases
  (severity `WARN` at level 2, `CRITICAL` at level 3), `RECOVERY` (`INFO`)
  when it decreases. Unchanged steady state — currently level 1
  `ENTRY_FREEZE_POLICY_UNBOUND`/`ENTRY_FREEZE_UNCERTAINTY`, since no OWNER
  policy is bound in production yet — never spams the alarm log.
- Never crashes on bad input: an unreadable/missing snapshot or policy
  load failure downgrades to a level-1 `ENTRY_FREEZE_WATCHER_ERROR` decision
  instead of raising, so a scheduled caller always gets an exit-0 decision.
- Requires the same `--dry-run` acknowledgement flag as the governor itself;
  there is no apply mode anywhere in this file. `action_plan.actions_executed`
  is always `[]`; AutoTrading, terminals, and order state are never touched.

## Acceptance evidence

**"Jede aktive Position im Dry Run erkannt" (every active position
detected):** `test_every_active_position_is_recognized_and_persisted` builds
a 3-position/1-order fixture (magic `111320000`, `0`, and an unregistered
`999`, matching SP-C1's own magic-independence proof) and asserts all four
tickets appear in the persisted state *and* in the appended history record.

**"Alarm/Freeze/Recovery belegt" (evidenced):**
`test_level_increase_writes_alarm_and_level_decrease_writes_recovery` runs
three sequential invocations against a bound policy with a trivially low
gross-leverage ceiling: (1) first observation reaches level 2
`PENDING_CANCEL_AND_ENTRY_FREEZE` with no prior state, so no transition is
recorded yet; (2) the position clears, level drops to 0 `CLEAR` — asserted as
a `RECOVERY` entry (`severity=INFO`) in the shared alarm log; (3) the breach
returns, level climbs back to 2 — asserted as an `ALARM` entry
(`severity=WARN`). `entry_freeze=True` is asserted at every non-zero level
via `action_plan.entry_freeze`.

**"signierte Notfallpolicy als Voraussetzung fuer Stufe-3-Flatten vorhanden"
(signed emergency policy is a stage-3 prerequisite):**
`test_stage3_flatten_requires_owner_signed_emergency_policy_bound_to_trigger`
confirms that a breach with an ordinary bound policy but no emergency policy
stays at level 2 with `would_flatten_position_tickets: []` and
`emergency_policy_binding.bound: false` — the unmodified `evaluate()` logic
from SP-C1 already enforces the independently-hash-bound, incident-scoped,
trigger-bound emergency-policy requirement for level 3; this watcher adds no
alternate path around it.

**Fail-closed on bad input:**
`test_unreadable_snapshot_fails_closed_without_crashing` and
`test_dry_run_flag_is_a_required_acknowledgement` cover a missing snapshot
file and a missing `--dry-run` flag respectively; both return without
raising and without touching state on the acknowledgement-missing path.

## Real (non-synthetic) run against the live account

Two consecutive invocations were run against the actually-deployed
`account_snapshot.json` (not a fixture), confirming the same boundary SP-C1
already documented — the live monitor is still the unversioned v1 shape, so
the watcher correctly stays at level 1 with `snapshot_schema_not_v2` /
`positions_inventory_missing` / `orders_inventory_missing` reasons rather
than inventing a position count:

```text
python tools/strategy_farm/governor_dry_run_watch.py --dry-run --expected-login 4000090541 --max-age-seconds 300
decision: level=1 ENTRY_FREEZE_UNCERTAINTY (snapshot_schema_not_v2:LEGACY_UNVERSIONED, positions_inventory_missing, orders_inventory_missing, ...)
action_plan.actions_executed: []

(second run, unchanged level) -> no alarm-log entry written (steady state)
D:\QM\reports\state\governor_dry_run_watch_state.json: run_count=2, alarm_count=0, recovery_count=0
```

A prior smoke run against a synthetic fixture snapshot had transiently
seeded these same production-path state/log/history files with fabricated
zero-position data; those files were deleted before this real run so the
persisted history starts from genuine telemetry only.

## Focused verification

```text
python -m py_compile tools/strategy_farm/governor_dry_run_watch.py tools/strategy_farm/tests/test_governor_dry_run_watch.py
COMPILE_OK

python -m pytest tools/strategy_farm/tests/test_account_portfolio_governor.py tools/strategy_farm/tests/test_live_book_dd_guard.py tools/strategy_farm/tests/test_governor_dry_run_watch.py -q -p no:cacheprovider
18 passed in 1.25s
```

The combined run with the pre-existing governor/DD-guard suites confirms no
duplicate-module import collision (the known `tools.strategy_farm.X` vs bare
`X` trap documented in `tools/strategy_farm/tests/conftest.py`); this
module's sibling import falls back from the package-qualified form to a bare
import only when run as a standalone script.

## Deployment boundary — not scheduled yet

This task delivers the *capability* to run recurring, not a live recurring
job. Consistent with SP-C1's own deployment boundary (the v1.10 detailed
monitor is source-only, not compiled/deployed), this change does **not**
register a Windows Scheduled Task. Recommended cadence, for OWNER/Codex
review before registration: a new `QM_StrategyFarm_GovernorDryRunWatch` task
alongside the existing `QM_StrategyFarm_LiveBookDDGuard` (5 min), invoking
`python tools/strategy_farm/governor_dry_run_watch.py --dry-run
--expected-login 4000090541`. Until a policy file exists (`SP-C1`'s
`Required gates before any live action` items 1-3 are still open), every run
will report level 1, which is fail-closed by design and produces no false
CLEAR/level-0 reading.

No source, calendar seed, MetaTrader compiler, terminal, T_Live, AutoTrading,
pipeline verdict, or work item was touched. Only the new files below plus
transient (now-removed) synthetic smoke-test state were written.

## Changed files

- `tools/strategy_farm/governor_dry_run_watch.py` (new)
- `tools/strategy_farm/tests/test_governor_dry_run_watch.py` (new)

This artifact remains in REVIEW for Codex/OWNER close-out, including the
scheduled-task registration decision.
