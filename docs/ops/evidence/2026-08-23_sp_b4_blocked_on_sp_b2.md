# SP-B4 blocked on unmet dependency SP-B2

Task: `agent_router` task `8c46a30d-5aab-46a1-aeb5-2ca9507d3014` (SP-B4, priority 50,
zone GRUEN, Schienenplan 2026-08-22). Routed to claude 2026-08-23T07:13:01Z, claimed
IN_PROGRESS by the orchestration cycle at 2026-08-23.

## Goal as assigned

"Aus News Contract V2 abgeleitete View, die nur Eventzeit+Impact enthaelt (kein
Actual/Forecast/Previous), vom News-Blackout-Filter konsumiert." Acceptance: generated
file + sample; no Actual/Forecast/Previous fields present. `depends_on: SP-B2`
(declared in the task payload itself).

## Dependency check ("schon durch?")

`SP-B2` (`84c988e6-fe11-47ed-b9f3-413096628bd2`) — the task that implements the News
Calendar Semantics Contract V2 (`docs/ops/NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md`,
§1–§9) — is **not** APPROVED/PASSED. Current state: `BLOCKED`, unchanged since
2026-08-22T11:23:11Z. Its own payload states: "KOLLIDIERT mit Q09-Rerun
b2468d2e/14487282 — erst nach dessen Abschluss auf gemeinsame Daten anwenden" and
hard_constraint "darf laufenden Q09_NEWS-Damm-Rerun NICHT konflatieren." The referenced
rerun task `14487282-3868-43cb-b22d-00ea049de0b8` is itself `BLOCKED` (last updated
2026-08-22T06:25:27Z), so SP-B2's blocking condition has not cleared.

Contract V2 §5 (the exact deliverable SP-B4 asks for — a schedule-view without
Actual/Forecast/Previous) is written as a specification only; SP-B1's own text is
explicit: "Implementation of the 9 points below is follow-up work for Codex... This is
a specification, not an implementation." No `timestamp_utc`-canonical, single-authoritative-source,
versioned-mapping data layer exists yet to derive a "Contract V2" view from — only the
current, pre-V2 two-file pair (`news_calendar_2015_2025.csv` +
`forex_factory_calendar_clean.csv`) that Contract V2 itself was written to replace.

## Why this task is not completed now

1. **Evidence over claims (Hard Rule).** Labeling a file "derived from News Contract V2"
   while V2's UTC-canonical storage, DST rule port, single-source-authority selection,
   and versioned impact-mapping (§1–§4) do not exist yet would misrepresent its
   provenance. The OWNER-ratified source decision
   (`decisions/2026-08-22_news_impact_taxonomy.md`, `forex_factory_calendar_clean.csv`
   canonical) resolves §7's policy gap but does not by itself constitute the Contract V2
   data layer — §1/§2/§4/§6/§7 machinery is still unbuilt.
2. **Collision risk SP-B2 was explicitly built to avoid.** SP-B2's hard_constraint
   forbids touching the shared calendar consumption path while the Q09_NEWS rerun is
   active. Building and wiring a new schedule-view artifact into
   `framework/include/QM/QM_FilterNewsBlackout.mqh` /
   `tools/strategy_farm/news_calendar_gate.py` now — ahead of and independent from SP-B2
   — would touch the same shared data path SP-B2 is blocked from touching, for the same
   reason.
3. **Scope ownership.** SP-B2 (the Contract V2 implementation, including its own §5) is
   assigned to `codex`, not `claude`. Implementing §5's substance myself under the SP-B4
   ticket would duplicate assigned work outside this task's actual scope.

## Action taken

`SP-B4` returned to `BLOCKED` (was `IN_PROGRESS`) with this evidence doc as
artifact-path. No code, filter, or gate-consumption changes made. Re-check when SP-B2
clears `BLOCKED`.
