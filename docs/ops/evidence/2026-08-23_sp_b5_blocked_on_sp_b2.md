# SP-B5 blocked on unmet dependency SP-B2

Task: `f8cf3ca4-e4e0-43a8-80fa-c36f3d97e537` (SP-B5, zone GELB). Goal: "Event-Schema
mit `known_at_utc` definieren+befuellen; Actual/Forecast/Previous point-in-time
(known-at) binden, kein Look-ahead." `depends_on: SP-B2` (declared in the task
payload).

Same pattern as `SP-B4` this cycle (`docs/ops/evidence/2026-08-23_sp_b4_blocked_on_sp_b2.md`,
independently confirmed by a concurrent lane at
`docs/ops/evidence/2026-08-23_sp_b4_schedule_view_dependency_hold.md`): `known_at_utc`
point-in-time binding is Contract V2 §6
(`docs/ops/NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md`), one of the 9 points whose
*implementation* is SP-B2's scope, not SP-B1's (specification-only) or a
standalone task's. SP-B2 (`84c988e6-fe11-47ed-b9f3-413096628bd2`) remains
`BLOCKED` (unchanged since 2026-08-22T11:23:11Z), gated on the active
Q09_NEWS rerun collision per its own hard_constraint.

Producing a `known_at_utc`-bearing event schema now, ahead of SP-B2's UTC-canonical
storage and single-authoritative-source selection, would mean inventing the
same field/provenance decisions SP-B2 is explicitly gated from making —
scope duplication, not completion. No schema or data file created.

**Action taken:** `SP-B5` returned to `BLOCKED` (was `IN_PROGRESS`), this
evidence doc as artifact-path. Re-check once `SP-B2` clears `BLOCKED`.
