# SP-B4 Blackout-Schedule-View — Dependency Hold

Date: 2026-08-23

Router task: `8c46a30d-5aab-46a1-aeb5-2ca9507d3014` (`SP-B4`)

## Verdict

DEPENDENCY_HOLD — no code or shared data changed. SP-B4's own payload declares
`depends_on: SP-B2`. SP-B2 (`84c988e6-fe11-47ed-b9f3-413096628bd2`, "News
Contract V2 implementieren") is still `BLOCKED` as of this observation, so
there is no `qm.news_calendar_semantics_contract.v2` implementation to derive
an event-time+impact-only view from. Building the view now would mean
inventing the schema/field decisions SP-B2 is explicitly gated from making —
the same reasoning already recorded in the SP-B2 preflight
(`docs/ops/evidence/2026-08-22_sp_b2_news_contract_v2_dependency_preflight.md`).

## Dependency evidence

### SP-B2 state — BLOCKED, not APPROVED/PASSED

Router record (read-only `list-tasks --agent codex --state BLOCKED`):

```text
id: 84c988e6-fe11-47ed-b9f3-413096628bd2
state: BLOCKED
depends_on: SP-B1 + ROT-2
review_close_verdict: BLOCKED (korrektes Gate-Honoring): SP-B2 wartet auf
  OWNER-DEC-NEWS-MAPPING + Q09-Rerun-Abschluss; Vorarbeit committed
  (403be708f) ohne Shared-Data-Mutation.
review_closed_at: 2026-08-22T11:23:11+00:00
```

Only pre-work (`403be708f`) is committed; no shared calendar data or loader
contract has been changed. There is no
`qm.news_calendar_semantics_contract.v2` artifact in the repo to build a
consumer view against.

### Gate 1 (ROT-2 / OWNER-DEC-NEWS-MAPPING) — now met

`decisions/2026-08-22_news_impact_taxonomy.md` records OWNER ratification of
`forex_factory_calendar_clean.csv` as canonical (2026-08-22). That document's
own "Implementation gate — still closed" section states this satisfies only
gate 1 of 2 for SP-B2, and gate 2 (Q09 rerun complete) was "not met" as of
2026-08-22.

### Gate 2 (Q09 rerun complete) — still not met

Read-only farm DB and filesystem observations during this hold:

- Pilot successor work item `ba24e7a3-4edf-4dc1-b74d-5854a6b5ecf2`
  (`QM5_11294` / `XAUUSD.DWX`, Q09_NEWS): `status=done`,
  `verdict=REVIEW_REQUIRED`, finished `2026-08-23T05:36:13Z`. This supersedes
  the earlier `b2468d2e` attempt (`status=failed`, `verdict=INFRA_FAIL`).
- The successor's `aggregate.json`
  (`D:\QM\reports\work_items\ba24e7a3-4edf-4dc1-b74d-5854a6b5ecf2\QM5_11294\Q09_NEWS\XAUUSD_DWX\aggregate.json`)
  reports `reason_codes: ["expanded_7x4_matrix_required"]` and
  `missing_cell_count: 105` — the pilot itself determined the original
  40-cell plan is insufficient and an expanded 7x4 matrix is required. This is
  not a reviewed, terminal pass.
- Downstream 41-row rerun wave `14487282-3868-43cb-b22d-00ea049de0b8`: still
  `BLOCKED`, gate text unchanged ("Gate nicht erfuellt — Pilot b2468d2e steht
  bei 16/40 Receipts ohne finales Aggregat... Wiedervorlage durch
  Orchestrator-Loop bei Pilot-Abschluss"), `review_closed_at`
  2026-08-22T06:25:27+00:00, no newer review recorded.

Neither the pilot nor its downstream rerun wave has reached a reviewed
terminal state. SP-B2's second gate condition is therefore still open, and
SP-B2 itself remains `BLOCKED`.

## Checks performed

- `agent_router.py list-tasks --agent codex --state BLOCKED` for SP-B2 and the
  41-row rerun task; confirmed both remain `BLOCKED` with unchanged gate text.
- Read `decisions/2026-08-22_news_impact_taxonomy.md` in full.
- Opened `farm_state.sqlite` read-only; queried `work_items` for
  `ba24e7a3`, `b2468d2e`, and confirmed no row exists yet for a reviewed
  successor to `14487282`.
- Read the successor pilot's `aggregate.json` and confirmed
  `verdict=REVIEW_REQUIRED` with 105 missing cells, not a clean pass.
- Confirmed no `qm.news_calendar_semantics_contract.v2` implementation exists
  in the repo beyond SP-B1's spec document.

No source, calendar seed, FILE_COMMON copy, Q09 evidence, pipeline verdict,
work item, terminal, or AutoTrading state was changed during this hold.

## Deterministic resume conditions

SP-B4 may be re-routed only once SP-B2 itself reaches `APPROVED`/`PASSED` with
a committed `qm.news_calendar_semantics_contract.v2` implementation (UTC
canonical storage, broker-time derivation, single-active-source fail-closed
loader, mapping code + version hash, point-in-time fields). At that point
SP-B4 can derive the event-time+impact-only blackout view from that contract
without inventing schema decisions.
