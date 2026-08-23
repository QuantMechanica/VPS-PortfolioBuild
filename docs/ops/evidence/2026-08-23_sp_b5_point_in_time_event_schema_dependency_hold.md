# SP-B5 Point-in-time Event Schema (known_at_utc) — Dependency Hold

Date: 2026-08-23

Router task: `f8cf3ca4-e4e0-43a8-80fa-c36f3d97e537` (`SP-B5`)

## Verdict

DEPENDENCY_HOLD — no schema or data changed. SP-B5's own payload declares
`depends_on: SP-B2`. `SP-B2` (`84c988e6-fe11-47ed-b9f3-413096628bd2`, "News
Contract V2 implementieren") remains `BLOCKED` (state unchanged since
`2026-08-22T11:23:11Z`, verdict unchanged: "wartet auf OWNER-DEC-NEWS-MAPPING
+ Q09-Rerun-Abschluss").

Same reasoning already applied to SP-B4
(`docs/ops/evidence/2026-08-23_sp_b4_schedule_view_dependency_hold.md`):
SP-B2's own acceptance criteria bundle "point-in-time fields" as one of the
nine points the V2 contract implementation must ship together (per its
`goal`: "...point-in-time-Felder, Run-Selfreport..."). SP-B5 asks for
exactly that piece — a `known_at_utc`-bound event schema with no look-ahead —
built standalone ahead of SP-B2's own loader/contract. Doing so now would
mean independently choosing the event-timestamp semantics (publication vs.
revision vs. embargo-lift time) that SP-B2 is chartered to define once,
against a single authoritative source, with a fail-closed loader. A
standalone schema built here would either diverge from SP-B2's eventual
implementation or hardcode assumptions ahead of the still-open Q09 rerun gate
SP-B2 itself is honoring.

Re-verified this cycle (read-only): SP-B2 remains `BLOCKED`; the pilot
successor `ba24e7a3` still shows `verdict=REVIEW_REQUIRED` with the
105-missing-cell / expanded-7x4-matrix finding documented in the SP-B4 hold;
the downstream 41-row rerun wave `14487282` is still `BLOCKED`. No new fact
changes SP-B2's own gate state since the SP-B4 hold was written a few hours
earlier today.

No source, calendar seed, work item, pipeline verdict, terminal, or
AutoTrading state was changed.

## Deterministic resume conditions

Same as SP-B4: re-route only once `SP-B2` itself reaches `APPROVED`/`PASSED`
with a committed `qm.news_calendar_semantics_contract.v2` implementation
(including its own point-in-time field design), so SP-B5 can consume rather
than pre-empt it.
