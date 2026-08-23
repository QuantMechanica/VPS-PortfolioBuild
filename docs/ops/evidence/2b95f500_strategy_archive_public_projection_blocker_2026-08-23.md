# Public Strategy Archive projection blocker

- Task: `2b95f500-e965-42d5-81af-6fdc135b9443`
- ToDo: `QM-TODO-20260823-511`
- Checked: 2026-08-23
- Verdict: `BLOCKED_OWNER_PROJECTION_DECISION`

## Decision

No public schema, snapshot, exporter, renderer, validator, scheduled task, or
website data was changed. The task explicitly assigns the public projection
decision to Claude/OWNER and the exporter/validator implementation to Codex, but
no projection decision exists in the durable control plane. Selecting a shape in
code would decide how much proprietary pipeline selectivity is disclosed.

The three materially different choices carried by the task are:

1. coverage only (`tested` / `not tested`, no verdict);
2. per-Q-gate pass/fail without numbers; or
3. full internal detail.

Codex cannot substitute the task's recommendation for the missing authorization.

## Control-plane evidence

A read-only query of canonical `agent_tasks` for
`QM-TODO-20260823-511` and `coverage only` returned exactly one row: this Codex
task. There is no companion Claude decision task, review artifact, or verdict
selecting (a), (b), or (c). A canonical repository search for the ToDo ID,
`projection decision`, and the three-option wording likewise found no decision
record.

The existing contract also makes this a breaking public API choice:

- `public-data/strategy-archive.schema.json` pins `schema_version` to 1;
- `public-data/README.md` requires a new version and parallel publishing window
  when fields or meanings change;
- the v1 snapshot contains only slug, source, visibility, and timestamp; and
- the current PowerShell producer assigns `visibility = public` to discovered
  files rather than resolving a per-card public authorization. It therefore
  cannot be treated as permission to expose matrix rows.

## Publication guard evidence

The existing fail-closed guard was run read-only:

```text
python tools/strategy_farm/public_snapshot_incident_guard.py --db D:/QM/strategy_farm/state/farm_state.sqlite
```

Result on 2026-08-23:

```text
valid=true
publication_allowed=false
active_incident_hold_count=1
hold_code=STALE_BUILD_RESULT_AUTO_Q02_BYPASS
```

The hourly wrapper checks this guard before invoking the exporter. The active
hold independently prohibits publishing a new snapshot now; it was not cleared,
bypassed, or weakened.

## Security boundary retained

The requested v2 cannot safely be approximated by copying the internal archive.
That surface contains evidence paths, work-item UUIDs, run details, and book-like
selectivity signals. The task requires a fail-closed allowlist and a scanner for
both slash styles, `file://` URIs, host/VPS identifiers, UUIDs, email addresses,
and all live-account/book/position data. No staged or current public JSON was
modified, so none of those classes was newly exposed.

## Required unblock

Claude/OWNER must record one projection choice and its exact field allowlist,
plus the v1-to-v2 parallel-publication/cutover rule. After that decision and after
the Q02-bypass incident hold is clear, Codex can implement the selected public
renderer over `archive_matrix.collect()`, make non-public/missing visibility
fail closed, add adversarial fixtures for every forbidden class and both path
separators, wire the guarded hourly exporter, and validate a v2 snapshot before
publication.
