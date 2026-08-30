# Mixed `updated_at` normalization implementation

Date: 2026-08-30
Router task: `0f7c7067-77b9-44fa-b86a-a065e2cf93ad`
Branch: `agents/board-advisor`

## Verdict

Implemented the approved format-only correction. All timestamp-window surfaces
identified by the `ef9a3849` audit now compare SQLite datetime values through
the shared, identifier-validated `normalized_timestamp_sql()` helper. The
destructive work-item log pruner was corrected first and its ordering now uses
the same normalized value. No metric window, status set, verdict set, phase
mapping, gate rule, queue rule, or retention duration changed.

The operational Python comparison in `blocked_backlog_retest.py` now parses both
supported timestamp shapes before deciding whether a work item finished after a
blocked task.

## Covered surfaces

- split throughput and completion latency;
- headless heartbeat throughput/verdict mix and stuck-task age;
- Mission Control progress windows;
- morning brief factory light;
- health activity, stagnation, SQLite-crash, infra-graveyard, task-aging, and
  Q02 failure-class windows;
- cockpit frontier freshness;
- concurrency A/B measurement;
- near-miss, NEWS, and optimization service windows;
- Q08 portfolio survivor pool and evidence cohort watch;
- WS0 notification ordering/window;
- work-item log retention classification.

## Live before/after sample

Read-only sample against `D:/QM/strategy_farm/state/farm_state.sqlite` after the
change:

| Measurement | Raw lexical | Normalized |
|---|---:|---:|
| trailing 1 hour, all work items | 2,638 | 40 |
| trailing 6 hours, all work items | 2,638 | 1,265 |

Stored shapes at capture were 115,968 `T`-separated rows and 84
space-separated rows. The raw query's identical 1h/6h result demonstrates the
separator bug; normalized counts restore actual window behavior. This is a
read-only measurement and did not rewrite historical rows.

## Regression fixture and verification

`test_mixed_timestamp_queries.py` inserts paired old/recent rows in both
separator formats and proves equivalent window and retention-age
classification. It also checks every audited module imports the shared helper
and contains no raw parameter comparison of `updated_at`.

Focused verification:

```text
57 passed in 20.29s
```

The suite included the new mixed-format fixture plus throughput telemetry,
Mission Control, WS0 notifier, concurrency A/B, NEWS service, optimization fork,
pruner, SQLite-lock health, and agent-lane heartbeat tests. `compileall` and
`git diff --check` also passed for all touched modules.

## Rollback

Revert the implementation commit. No database migration or data rollback is
required because the change is query-only.
