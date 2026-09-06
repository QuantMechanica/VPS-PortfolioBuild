# M15 — action-guiding board: agent_tasks status projection

- **Task:** `8db1d722-ee86-48a0-8271-fb197eb39ab4` (ops_issue, Codex Sol medium in the plan; executed in the Claude lane on branch `agents/board-advisor`).
- **Audit finding:** M15 / Priority 2 — `docs/ops/CEO_AUDIT_INTEGRATION_2026-09-05.md:29`. One action-guiding board with a status projection (actionable / waiting / parked / superseded / completed), exactly one task per real blocker, net KPIs in front, tester utilisation and row counts as diagnostics.
- **Boundary:** read-only projection; no gate threshold, no verdict, no candidate pool, no live book touched. New files only — no existing surface was edited; the cockpit wiring is delivered as a described one-line hook (below), inert until an OWNER-governed edit lands it.

## What was built

`tools/strategy_farm/board_projection.py` — a strictly read-only projection of `agent_tasks` into the five classes, per lane, with age / priority / title and a single next action per actionable row, plus the six-value net-KPI strip. Emits the self-contained JSON contract `qm.board_projection.v1`.

- DB opened read-only: `open_ro()` uses `file:...?mode=ro` (`board_projection.py:79`).
- Classification is a pure function `classify(row, superseded_ids, now)` with deterministic first-match precedence (`board_projection.py:230`):
  1. **superseded** — id referenced by another row's `payload.supersedes`.
  2. **complete** — state `PASSED` or `APPROVED` (no agent action pending; complete beats any decision/dependency marker still on the row).
  3. **BLOCKED** → `awaiting_owner_receipt` (router_human_lane_hold), `decision-bound` (open `owner_decision` dict without a resolved `choice`), else **parked** with the explicit `orchestrator_deprioritised.reason` / `blocked_reason`, else `UNKNOWN` (never dropped).
  4. `PIPELINE` → **waiting** `awaiting_pipeline`; `REVIEW` → **waiting** `awaiting_review`.
  5. Live states (`TODO`/`BACKLOG`/`IN_PROGRESS`/`RECYCLE`/`OPS_FIX_REQUIRED`/`FAILED`): human-lane hold / pending decision / `depends_on` → **waiting**; `orchestrator_deprioritised` → **parked**; a `TODO` commissioned to Codex → **waiting** `awaiting_codex_lane`; otherwise **actionable** with a state-keyed next action.
- Lane normalisation `lane_of()` (`board_projection.py:130`): `codex*` → codex, `gemini`/`agy` → `agy/gemini`, unassigned rows under an owner human-lane hold → owner, else `unassigned`.
- Net-KPI strip: six values (received payouts, monthly OPEX, DARWIN status, decidable release candidates, days to next decisive test, open release-blocking defects), each rendered `UNKNOWN` with an M07/M01/M05/M13 source pointer — **never zero** — until those upstream outputs exist on disk (`KPI_SOURCES`, `board_projection.py:55`).
- CLI: `--db-path`, `--out` (default `D:/QM/reports/state/board_projection.json`, atomic write), `--dry-run` (prints JSON), `--markdown` (compact human board). Diagnostics section carries `by_state`, `by_lane`, and `tester_utilisation: UNKNOWN` (not joined here).

## Tests

`tools/strategy_farm/tests/test_board_projection.py` — 15 tests over a temp SQLite fixture (all IO under `tmp_path`, no production state touched). Covers every class, the six waiting reasons, the lane split (incl. `codex:agents/board-advisor` → codex and owner-via-hold), superseded-beats-actionable and complete-beats-decision precedence, deterministic ordering, age arithmetic, the UNKNOWN-never-zero KPI strip, markdown rendering, atomic write round-trip, and read-only refusal of writes.

```
python -X utf8 -m pytest -q tools/strategy_farm/tests/test_board_projection.py
15 passed
```

## Real dry-run summary (production DB, read-only, 2026-09-06 ~03:45Z)

`python -X utf8 tools/strategy_farm/board_projection.py --db-path D:/QM/strategy_farm/state/farm_state.sqlite --dry-run` — 2055 tasks.

**Counts per class**

| class | count |
|---|---:|
| actionable | 238 |
| waiting | 167 |
| parked | 414 |
| superseded | 3 |
| complete | 1233 |

**Waiting reasons:** awaiting_pipeline=165, awaiting_owner_receipt=2, awaiting_review=0, awaiting_dependency=0, awaiting_codex_lane=0, decision-bound=0. (The zero reasons are honest: no `REVIEW` rows, no structured `depends_on` on live rows, no pending `owner_decision` dict on a live row, and every open `TODO` is currently unassigned — so nothing is queued *on the Codex lane* right now.)

**Counts per lane**

| lane | actionable | waiting | parked | superseded | complete | total |
|---|---:|---:|---:|---:|---:|---:|
| claude | 22 | 33 | 20 | 0 | 181 | 256 |
| codex | 95 | 95 | 287 | 3 | 883 | 1363 |
| agy/gemini | 101 | 13 | 95 | 0 | 84 | 293 |
| owner | 0 | 1 | 0 | 0 | 0 | 1 |
| unassigned | 20 | 25 | 12 | 0 | 85 | 142 |

**Diagnostics — by state:** APPROVED=524, BLOCKED=415, FAILED=50, OPS_FIX_REQUIRED=2, PASSED=709, PIPELINE=165, RECYCLE=183, TODO=7. Tester utilisation = UNKNOWN (join deferred to `farmctl mt5-slots` / `heartbeat_state.json`).

**Top 10 actionable** (sorted `-priority`, `-age_days`, `id`)

| pri | age(d) | lane | title | next action |
|---:|---:|---|---|---|
| 1000 | 20 | codex | QM5_1058 Gatev FX pairs Q02 ONINIT/stale-binary recovery | Re-triage: diagnose the failure, then re-enqueue (append-only) or retire |
| 1000 | 5 | codex | Repair and re-enqueue QM5_1090 USDJPY.DWX D1 Q02 peer-history dependency | Re-triage: diagnose the failure, then re-enqueue (append-only) or retire |
| 1000 | 5 | codex | Recover QM5_9107 EURCHF.DWX D1 Q02 after multisymbol history-isolation repair | Re-triage: diagnose the failure, then re-enqueue (append-only) or retire |
| 1000 | 5 | codex | Recover QM5_1251 USDJPY.DWX zero-trade Q02 after undeclared 12-symbol history dependency | Re-triage: diagnose the failure, then re-enqueue (append-only) or retire |
| 1000 | 4 | unassigned | [ops_issue] f066f611 | Re-triage: diagnose the failure, then re-enqueue (append-only) or retire |
| 99 | 41 | unassigned | [pipeline_run] e90c8b4f | Re-triage: diagnose the failure, then re-enqueue (append-only) or retire |
| 99 | 40 | codex | [triage_failure] 598dd8fe | Rework against the review verdict and resubmit for review |
| 99 | 20 | codex | P0 Q09 dam: requalify the eight pre-interface EAs so a sealed calendar plan can exist | Rework against the review verdict and resubmit for review |
| 99 | 15 | codex | [q02_infra_repair] 5f3f72bc | Re-triage: diagnose the failure, then re-enqueue (append-only) or retire |
| 99 | 15 | unassigned | [triage_failure] 8248b6ba | Re-triage: diagnose the failure, then re-enqueue (append-only) or retire |

Read: the actionable list is dominated by high-priority Q02 recovery / triage-failure rows and a large `RECYCLE` backlog surfacing as `parked`(414)/`actionable`(238); the 165 `PIPELINE` rows are correctly `waiting: awaiting_pipeline` (an automated gate is running, no agent acts); and `owner` carries exactly one waiting item (the XAGUSD video-lane hold). This is the diagnostic layer; the net-KPI strip in front stays UNKNOWN until M07/M01 land.

## Proposed one-line hook into Mission Control v2 (render-only, additive, not applied here)

Two additive edits land the strip above the terminal board once an OWNER-governed edit window opens (the data contract change is additive; no schema removal, no P-key exposure):

1. **Data contract** — in `tools/strategy_farm/mission_control_v2_data.py`, `build_contract()` return dict (`mission_control_v2_data.py:1328`-1342), add one key fed from the same read-only DB:

   ```python
   "board": board_projection.build_from_db(db),   # {task_projection, company_kpis, diagnostics}
   ```

   (import `from tools.strategy_farm import board_projection` alongside the existing module imports; the contract already opens `db` read-only.)

2. **Renderer strip** — in `tools/strategy_farm/render_cockpit_v2.py`, insert `_render_board_strip(contract),` as the **first** element of the `body = "".join([ ... ])` list at `render_cockpit_v2.py:1490`, above `_render_control_strip(contract)`, so the KPI strip + class counts render above the terminal board. `_render_board_strip` binds `contract["board"]["company_kpis"]` (six tiles, UNKNOWN→"UNKNOWN" label, never a `0`) and `contract["board"]["task_projection"]["counts"]` / `by_lane`, escaping every string with `e()` and using only `var(--*)` tokens per the render spec.

Both are render-only; the projection itself makes zero data decisions and writes nothing outside its `--out` path.

## Files

- `tools/strategy_farm/board_projection.py` (new)
- `tools/strategy_farm/tests/test_board_projection.py` (new, 15 tests)
- `docs/ops/evidence/2026-09-06_m15_board_projection.md` (this doc)
