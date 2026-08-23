# SH-3 successor: OFF-window and target-schema blocker

- Task: `f01d0098-c28b-448c-a0c1-769360997b11`
- ToDo: `QM-TODO-20260823-509`
- Checked: 2026-08-23
- Verdict: `BLOCKED_OFF_WINDOW_AND_SCHEMA_CONTRACT`

## Decision

No database, schema initializer, writer, reader, verdict, foreign-key setting,
factory process, terminal, or scheduled task was changed. The task requires an
OFF window, but no OWNER-authorized OFF window is active. In addition, the
requested target columns do not cover the measured live reference population.
Applying the stated migration would therefore discard or misclassify valid
lineage.

## Read-only live classification

`python tools/strategy_farm/schema_hardening.py check` reported:

```text
work_items rows                         111400
SH-1 unfilled                               0
SH-1 clean-status mismatches               23
SH-1 taxonomy mismatches                   16
SH-1 valid                              false
foreign-key violations                     99
work_items -> tasks violations             71
tasks -> sources violations                28
PRAGMA foreign_keys                       OFF
safe_to_enforce                         false
```

A second read-only SQL classification, with mutually exclusive target checks,
found:

| Current value class | Rows |
|---|---:|
| `work_items.parent_task_id` non-null | 4,911 |
| resolves to `tasks(id)` | 4,840 |
| resolves to `work_items(id)`, not `tasks` | 39 |
| resolves to `agent_tasks(id)`, not either above | 14 |
| resolves to none of the three tables | 18 |
| `tasks.source_id` non-null | 31 |
| resolves to `sources(id)` | 3 |
| does not resolve to `sources(id)` | 28 |
| EA-shaped (`QM5_*`) | 10 |

This preserves and sharpens the original 99-row measurement; no row was changed
or deleted.

## Target-schema gap

The requested `parent_work_item_id` and `parent_agent_task_id` columns account for
the 39 work-item and 14 agent-task references. They do not define where the 4,840
valid references to the existing pipeline `tasks(id)` table belong. Removing or
repurposing `parent_task_id` without a third typed relation (or an explicit decision
to retain it) would destroy the dominant valid parent relationship.

The `tasks.source_id` instruction is also a choice rather than a migration contract:
only 10 of the 28 dangling values are demonstrably EA-shaped, while 3 existing
values are valid source references and 18 dangling values remain another class.
Renaming every value to `ea_id` would be false; dropping the foreign key versus
splitting the meanings requires an explicit decision and writer/read-path mapping.

The 18 parent values that point nowhere must be retained and marked, but the target
marker column/vocabulary and downstream read behavior are not specified.

## OFF-window evidence

The canonical health/read-only database checks showed 3,232 pending work items,
9 active rows, and a latest work-item update at
`2026-08-23T13:46:11+00:00`. No OWNER-approved Factory-OFF ceremony or migration
window was supplied to this task. Dead/stranded workers do not constitute an
authorized OFF window, and Codex has no authority to stop them.

Changing SQLite foreign-key declarations requires a table rebuild and coordinated
writer rollout; merely adding columns would leave canonical scheduled writers on
the old contract. Enabling `PRAGMA foreign_keys=ON` now remains explicitly unsafe.

## Required unblock and safe migration shape

OWNER/Claude must provide an OFF window and ratify a complete typed schema that:

1. retains or replaces the 4,840 valid `tasks(id)` relationships explicitly;
2. maps the 39 work-item and 14 agent-task relationships to distinct columns;
3. preserves the 18 unresolved parent values with a named disposition marker;
4. separates the 3 genuine source references, 10 EA-shaped values, and 18 other
   `tasks.source_id` values without guessing;
5. defines dual-write/read compatibility and rollback across every canonical writer;
6. runs first on a database copy, then in the approved OFF window with no row or
   verdict deletion; and
7. completes a factory regression before foreign-key enforcement is considered.

The baseline SH-1 validator must also be returned to `valid=true` without rewriting
verdict evidence before `schema_hardening.py check` can be called green.
