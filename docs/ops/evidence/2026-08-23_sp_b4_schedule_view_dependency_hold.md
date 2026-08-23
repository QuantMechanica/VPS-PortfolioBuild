# SP-B4 Schedule-View (Blackout-Filter) — Dependency Hold

Date: 2026-08-23

Router task: `8c46a30d-5aab-46a1-aeb5-2ca9507d3014` (`SP-B4`, priority 50, zone GRUEN)

## Verdict

DEPENDENCY_HOLD — no schedule-view artifact was generated. SP-B4's own payload
declares `depends_on: SP-B2`. `SP-B2` (`84c988e6-fe11-47ed-b9f3-413096628bd2`,
"News Contract V2 implementieren") is currently `BLOCKED` and its own
acceptance criteria bundle "getrennte Blackout-Schedule-View" (the exact
artifact SP-B4 asks for) as one of the nine points SP-B2 must ship together —
so SP-B4 cannot honestly precede it.

No calendar seed, FILE_COMMON copy, Q09 evidence, pipeline verdict, work
item, terminal, or AutoTrading state was changed while producing this hold.

## What changed since SP-B2's own preflight (403be708f, 2026-08-22 13:00)

One of SP-B2's two resume conditions has since been met:

1. **ROT-2 (impact-taxonomy OWNER decision) — now ratified.**
   `decisions/2026-08-22_news_impact_taxonomy.md`: OWNER approved Option 1,
   `forex_factory_calendar_clean.csv` canonical for impact-sensitive gating;
   `news_calendar_2015_2025.csv` retained as audit trail only. This closes
   the gap that made picking an authoritative impact source an invented
   policy value.

2. **Q09_NEWS pilot rerun — still not satisfied.** Read-only DB checks
   performed for this hold, 2026-08-23:
   - Rerun work item `ba24e7a3-4edf-4dc1-b74d-5854a6b5ecf2`
     (`append_only_rerun_of` predecessor `b2468d2e-92a5-4fd8-a6ae-29967da0ca08`,
     which terminaled `INFRA_FAIL`): `status=done`, `verdict=REVIEW_REQUIRED`,
     `updated_at=2026-08-23T05:36:13Z`. The pilot finished running but did
     **not** lock a config — `REVIEW_REQUIRED` is not the "40/40 + review"
     terminal state SP-B2's resume conditions require.
   - Its review is itself still open: `agent_tasks` row `9b40ff25-098e-4a7a-a78c-d510ba7b763b`
     (codex, `ops_issue`) is `IN_PROGRESS` as of `2026-08-23T05:27:55Z`,
     immediately preceding the pilot's completion timestamp — the natural
     read is that this is the in-flight review of `ba24e7a3`'s result, not
     yet closed.
   - Downstream 41-row append-only rerun wave `14487282-3868-43cb-b22d-00ea049de0b8`
     is unchanged: still `BLOCKED`, `updated_at=2026-08-22T06:25:27Z` (its
     verdict text is stale — it cites the predecessor's 16/40-receipt state —
     but the state itself has not been re-opened, so the wave has not
     started).
   - `SP-B2` (`84c988e6-fe11-47ed-b9f3-413096628bd2`) itself: state `BLOCKED`,
     verdict unchanged since `2026-08-22T11:23:11Z`.

So gate 2 of SP-B2's own two-gate dependency ("Q09 rerun complete, reviewed
terminal state") remains open. Per the same reasoning SP-B2's preflight
already applied to itself ("Starting the requested implementation now would
... risk changing calendar semantics underneath an active Q09_NEWS
measurement"), and because SP-B4 explicitly names SP-B2 as its own
prerequisite, generating the schedule-view artifact now would pre-empt SP-B2
rather than follow it.

## Why this cannot be narrowed to "just strip three columns"

The SP-B1 contract (`docs/ops/NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md` §5)
describes the schedule view as `timestamp_utc, currency, impact, event_id`
projected from **the** authoritative source. Building that projection today
still requires choosing which file's rows to read `impact` (and `event_id`)
from for the disagreeing 41.7% of common events — i.e. it consumes the §3
"exactly one active source" declaration that SP-B2 is the task chartered to
implement (loader, fail-closed 0/>1-source behavior, mapping-fingerprint
wiring). Emitting a standalone view ahead of that loader would either (a)
silently pick a source outside the SP-B2 implementation, duplicating and
potentially diverging from it, or (b) hardcode `forex_factory_calendar_clean.csv`
without the fail-closed/fingerprint machinery §3/§9 require — both are
exactly the kind of pre-empting SP-B2's own hold was written to prevent.

## Checks performed

- Read SP-B4's routed payload (`depends_on: SP-B2`, hard_constraint "kein
  Look-ahead") from `agent_tasks`.
- Read `SP-B1` contract in full (`docs/ops/NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md`),
  in particular §5 (schedule view) and §15 (OWNER decision template).
- Read `SP-B2`'s preflight (`docs/ops/evidence/2026-08-22_sp_b2_news_contract_v2_dependency_preflight.md`)
  and its current `agent_tasks` row (state `BLOCKED`, verdict unchanged).
- Read the ratified ROT-2 decision (`decisions/2026-08-22_news_impact_taxonomy.md`),
  confirmed it explicitly states the implementation gate stays closed pending
  the Q09 rerun.
- Opened `farm_state.sqlite` read-only; checked `ba24e7a3` (rerun pilot),
  `b2468d2e` (predecessor), `14487282` (downstream wave), and `84c988e6`
  (SP-B2) rows for status/verdict/updated_at.
- Checked `agent_tasks` for any row referencing `ba24e7a3` or `Q09_NEWS`
  newer than the pilot's completion; found `9b40ff25` `IN_PROGRESS`
  (codex), consistent with an unclosed review.

## Deterministic resume conditions

SP-B4 may be re-routed (or re-attempted) once:

1. `SP-B2` itself reaches a state where its implementation (loader,
   fail-closed single-source selection, mapping fingerprint) is committed —
   at that point SP-B4 becomes "read the already-built view/loader, project
   the four allowed columns" rather than "invent the view ahead of the
   loader"; or
2. OWNER/router explicitly reclassifies SP-B4 as independent of SP-B2 despite
   its own payload's `depends_on` field (a payload change, not something this
   task can decide for itself).

## Evidence

- `agent_tasks` row `8c46a30d-5aab-46a1-aeb5-2ca9507d3014` (SP-B4, this task).
- `agent_tasks` row `84c988e6-fe11-47ed-b9f3-413096628bd2` (SP-B2, state
  `BLOCKED`, unchanged verdict).
- `docs/ops/evidence/2026-08-22_sp_b2_news_contract_v2_dependency_preflight.md`
  (SP-B2's own hold, whose second resume condition this document confirms is
  still open).
- `decisions/2026-08-22_news_impact_taxonomy.md` (ROT-2 ratified; explicitly
  notes the implementation gate stays closed on the Q09 rerun).
- `work_items` rows `ba24e7a3-4edf-4dc1-b74d-5854a6b5ecf2`,
  `b2468d2e-92a5-4fd8-a6ae-29967da0ca08`.
- `agent_tasks` rows `14487282-3868-43cb-b22d-00ea049de0b8` (downstream wave,
  still `BLOCKED`), `9b40ff25-098e-4a7a-a78c-d510ba7b763b` (open review,
  `IN_PROGRESS`).
