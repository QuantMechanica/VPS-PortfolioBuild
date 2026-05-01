# DL-046 — PROJECT_BACKLOG.md state-truth refresh + milestones.md M0/M1/M2 status update (2026-05-01)

**Status:** accepted
**Owner:** Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
**Authority:** DL-023 (CEO broadened-autonomy waiver, class 4 — internal process choices: docs alignment with live state); operationalised by Doc-KM under standing BASIS responsibility "Keep Notion V5 project hub pages current with pipeline reality"
**Originating issue:** [QUA-668](https://paperclip.local/QUA/issues/QUA-668) — D1 of parent [QUA-665](https://paperclip.local/QUA/issues/QUA-665) (Verify Paperclip live + ship parked deliverables + freeze housekeeping + fix smoke discipline)

## Decision

This DL is a one-line **refresh pointer**, not a new policy. It records that two state-truth surfaces were brought into line with the live Paperclip roster on 2026-05-01:

1. [`PROJECT_BACKLOG.md`](../PROJECT_BACKLOG.md) § "Today's Reality" — Wave 0 hire date (2026-04-27), Wave 1 partial state (DevOps live; Pipeline-Operator + Development paused 2026-04-29), Wave 2 early-trigger hires (Quality-Tech + Quality-Business, both 2026-04-28). Agent roster table replaced with live-API-verified rows including agent IDs, hire dates, `pausedAt` timestamps. Live initiatives section replaced with current DL-043 / DL-044 / DL-045 / DL-046 references.
2. [`paperclip/milestones/milestones.md`](../../paperclip/milestones/milestones.md) — M0 confirmed **closing** with Phase 2 PASS gate (QUA-639) named as technical close-out trigger; M1 flipped from **next** to **active** (Wave 0 hired; process registry + issue board + hourly snapshot operational); M2 flipped from **next, blocked on Wave 1+2 hire** to **active** (Wave 1+2 hired; real bottleneck is OWNER first-matrix release gate per DL-040, not hiring).

## Why

Per [QUA-665](https://paperclip.local/QUA/issues/QUA-665) anchor: PROJECT_BACKLOG.md still claimed "Paperclip is not installed yet" — stale by 5 days. milestones.md M0/M1/M2 still claimed Wave 0/1/2 not hired. Both surfaces were misleading downstream readers (CEO heartbeat triage, Board Advisor audits, future show-notes drafts). Live API + commit history are authoritative; refreshing the docs prevents recurring drift.

Per memory `project_qm_org_chart_vs_live_roster.md`: "live API roster is source of truth, not the org-chart file". This DL operationalises that principle on the two highest-traffic state-truth surfaces.

## Evidence

- Live API queried 2026-05-01:
  - `GET /api/companies/03d4dcc8-4cea-4133-9f68-90c0d99628fb/agent-configurations` → 9 active agents.
  - `GET /api/agents/<id>` per-agent for `pausedAt` resolution.
- Commit referencing this DL on `agents/docs-km`: see registry row.
- No upstream BASIS / hard-rule / phase-spec content edited; this is a pure state-truth alignment per QUA-668 boundary "Do NOT change Phase 0..6 outer-boundary specs or hard rules."

## Cross-links

- **DL-040 ↔ DL-046.** DL-040's first-matrix-hold is named in M2's notes as the *current* bottleneck (no longer "Wave 1+2 hire"). DL-040 is unchanged; DL-046 records that the operational bottleneck has shifted along the gate chain.
- **DL-043 ↔ DL-046.** DL-046 cites DL-043 in PROJECT_BACKLOG.md "Live initiatives" as the recorded 2026-04-30 reboot plan GO. DL-043 is unchanged.
- **DL-044 ↔ DL-046.** DL-046 cites DL-044 in M2 notes (Research pause until first V5 EA reaches P7). DL-044 is unchanged.
- **DL-045 ↔ DL-046.** DL-046 cites DL-045 in PROJECT_BACKLOG.md "Today's Reality" + milestones.md M2 as the Wave 2 early-trigger backfill. DL-045 is unchanged.
- **QUA-588 ↔ DL-046.** Parent QUA-588 F4 originally tracked the PROJECT_BACKLOG.md realignment; commit `c0e49f4e` (2026-05-01) made the bulk of the section rewrite. DL-046 records the *follow-up* refinement that adds hire dates, agent IDs, pause timestamps, and milestones.md alignment per QUA-665 D1's higher-precision acceptance criteria.

## Authority chain

- DL-023 (CEO broadened-autonomy waiver) → Doc-KM standing BASIS § "Keep Notion V5 project hub pages current with pipeline reality" → QUA-665 D1 directive → QUA-668 deliverable.

## Snap-back

- If a future audit shows PROJECT_BACKLOG.md or milestones.md drifting again, the corrective action is another refresh DL (not a process change). The hourly snapshot job + nightly Notion-sync routine are the standing controls; this DL is the catch-up entry.
- No reversal needed. State-truth refresh is monotonic: it always tracks live API.
