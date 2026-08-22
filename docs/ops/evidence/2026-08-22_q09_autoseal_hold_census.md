# Q09 autoseal hold census

Date: 2026-08-22  
Router task: `f8878393-1d34-4687-9428-ba09db9dc1e8` (`OPS-Q09-AUTOSEAL-VISIBILITY`)  
Scope: observation only; no `work_items`, hold, gate/bind, terminal, or T_Live mutation

## Result

`farmctl health` now publishes the registered check
`q09_autoseal_hold_census`. Mission Control v2 publishes the same canonical
grouping as the top-level `q09_autoseal_holds` panel. Both consumers call
`tools/strategy_farm/q09_autoseal_hold_census.py`; there is one census and one
threshold implementation rather than two observer-specific interpretations.

The census selects every row satisfying all of:

- `work_items.phase='Q09_NEWS'`
- `work_items.status='pending'`
- an active `work_item_holds` row with
  `hold_code='Q09_AWAITING_SEALED_PLAN'`

It groups by `payload_json.q09_activation_state` and
`payload_json.q09_autoseal_failure.reason_code`. Each group carries its count,
oldest `observed_at`, and up to five full example work-item IDs. A separate
reason-only grouping makes the cross-state reason threshold explicit.

## Severity contract

- `WARN`: at least one selected row has failure `observed_at` older than 1 hour.
- `FAIL`: at least three selected rows have `observed_at` older than 6 hours, or
  any real `reason_code` occurs on at least three rows.
- Malformed payload JSON or an invalid/missing observation timestamp is
  fail-closed as `FAIL`; a hold timestamp is retained as an age fallback where
  readable.
- `OK`: none of those conditions applies, including the zero-row case.

The existing `q09_sealed_plan_hold_age` remains intact. It measures the age of
the hold itself. The new check measures the current autoseal failure observation
and classifies the cause, so a recently retried but structurally repeated
failure is visible without pretending the underlying old hold is new.

## Live proof

Command:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py health
```

Observed at `2026-08-22T20:49:05Z`:

```text
name=q09_autoseal_hold_census
status=FAIL
active_holds=17
AWAITING_SEALED_PLAN/Q09_AUTOSEAL_BIND_PLAN_FAILED=16
AWAITING_SEALED_PLAN/Q09_AUTOSEAL_INCLUDE_CLOSURE_FAILED=1
```

The failure is triggered by the 16-row repeated reason cohort even though the
latest retry observations are less than one hour old. This is the intended
"fail-closed gate is not an empty queue" signal.

Command:

```text
python tools/strategy_farm/mission_control_v2_data.py
```

The regenerated
`D:/QM/reports/state/mission_control_v2_preview.json` validates against the
embedded `qm.mission_control.v2` schema and contains:

```text
q09_autoseal_holds.status=FAIL
q09_autoseal_holds.total=17
q09_autoseal_holds.groups[0].reason_code=Q09_AUTOSEAL_BIND_PLAN_FAILED
q09_autoseal_holds.groups[0].count=16
```

## Verification

```text
python -m py_compile tools/strategy_farm/q09_autoseal_hold_census.py tools/strategy_farm/health.py tools/strategy_farm/mission_control_v2_data.py
PASS

python -m pytest -q tools/strategy_farm/tests/test_q09_autoseal_hold_census.py tools/strategy_farm/tests/test_mission_control_v2_data.py
13 passed
```

The fixtures prove both age thresholds, repeated-reason grouping, the healthy
zero-row path, shared health/Mission-Control output, and full contract schema
validation. The production DB is opened read-only by both consumers; the helper
contains only `SELECT` statements.
