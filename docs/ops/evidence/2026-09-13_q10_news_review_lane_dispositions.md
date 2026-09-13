# Q10_NEWS REVIEW_REQUIRED lane — governed readjudication and append-only closure

Date: 2026-09-13
Decision id: `ORCH-Q10NEWS-REVIEW-LANE-CLOSURE-20260913`
Companion (historical lane, closed earlier the same day):
`docs/ops/evidence/2026-09-13_q09_news_review_lane_dispositions.md`

## Why this exists

`Q10_NEWS` is the **active** NEWS storage phase (`farmctl._NEWS_PHASE`). At the
start of this work it carried **95** `done` / `REVIEW_REQUIRED` rows with no
supersession edge — the head-block the SP-B2 preflight calls "no Q09_NEWS run
remains active against the shared V1 calendar inputs".

The canonical governed tool for this lane is
`farmctl readjudicate-news-8cell` (`tools/strategy_farm/farmctl.py:19896-20234`).
It re-runs the **current** `q09_news_contract.adjudicate` rule over sealed
8-cell evidence and, only when that rule now returns `CONFIG_LOCKED`, inserts
one append-only successor. It refuses everything else with a machine-readable
`reason`. It is the first instrument used here; this document's tool handles
only what that instrument refuses, and it closes nothing the rule itself would
not close.

## Step 1 — the governed tool, per row

`farmctl readjudicate-news-8cell --list` reported `eligible_count: 0`,
`already_readjudicated_count: 32`, `excluded_historical_phase_count: 1`.

`--list` is **not** the whole action surface: `_readjudicate_news_list` builds on
`news_gate_service.expansion_requests`, which keeps only the newest row per
`(ea_id, symbol, setfile_path)` identity (`news_gate_service.py:122-137`),
whereas the action path binds a single `work_item_id` and applies no such
dedup. A per-row dry-run over all 95 rows therefore found four rows the tool
accepts that `--list` hides behind a newer sibling.

Per-row dry-run outcome over the 95 (before any apply):

| tool outcome | rows |
|---|---|
| `would_readjudicate` (accepted) | 4 |
| `readjudicate_successor_already_exists` | 32 |
| `readjudicate_source_not_expanded_8cell` | 59 |

All four accepted rows were dry-run first, then applied. Each produced one
append-only `CONFIG_LOCKED` successor, chosen config `OFF` / `DXZ`:

| source work item | EA / symbol | successor | verdict |
|---|---|---|---|
| `c8f1f977-46fe-48ea-9d20-68926f938d7c` | QM5_21505 / XAGUSD.DWX | `6ccfd94c-8149-432c-9566-c75b72f7eee5` | CONFIG_LOCKED |
| `c5260944-a106-4c5f-a4f6-3f4aefcd5bb4` | QM5_21507 / XAUUSD.DWX | `6aea665c-5aec-4bc7-95c9-e1e223aa1502` | CONFIG_LOCKED |
| `f5aa4af4-01b9-4eb8-89eb-4a08878c5364` | QM5_11881 / GBPUSD.DWX | `86d63dcb-5779-4ed1-b2d1-43697038c65e` | CONFIG_LOCKED |
| `fe33550e-2de4-4886-9b10-e7ea48a382d7` | QM5_10700 / XAUUSD.DWX | `4066a5fb-7dee-4664-ad92-176a349ab1f9` | CONFIG_LOCKED |

Each identity already held a `CONFIG_LOCKED` conclusion from a newer sibling,
and every one of those existing locks is also `OFF` / `DXZ` — the four new
successors agree with the standing conclusion and contradict nothing. CLI
receipts (dry-run and apply) are stored under
`D:\QM\strategy_farm\artifacts\q10_news_review_dispositions_20260913\readjudications\`.

## Step 2 — classification of what the tool refuses

`readjudicate_source_not_expanded_8cell` is one reason code covering several
distinct facts (`news_gate_service.verified_expansion_adjudication` fails closed
on all of them). Measured per row against the evidence on disk:

| cause | rows | fact |
|---|---|---|
| `cell_execution_failed` aggregate | 46 | the sealed run recorded failed cells; the aggregate's own `reason_codes` are `["cell_execution_failed"]`, not the expansion request the tool binds |
| `control_or_policy_off_not_qualifiable` aggregate | 11 | the CONTROL_OFF / POLICY-OFF arms did not qualify; the **current** rule returns this same non-terminal `REVIEW_REQUIRED` again |
| aggregate file absent | 2 | DL-090 report retention removed the aggregate; nothing left to adjudicate |

For the 46, re-running the current `q09_news_contract.adjudicate` over the
sibling `q09_news_evidence.json` is terminal: **INVALID_EVIDENCE** /
`contract_invalid`, split 40 × `cells must not be empty` and 6 ×
`contract v3 cell count is not a complete 8- or 29-config matrix`. That is the
rule's own verdict, not a new judgement.

For the 11 it is **not** terminal — the current rule still says
`REVIEW_REQUIRED` / `control_or_policy_off_not_qualifiable`. Closing those would
mean either a new measurement (a rerun) or a change to the gate rule. Both are
outside this work: gate thresholds and contract criteria are ROT. They are
therefore enumerated as a **declared open residual**, not dispositioned.

## Step 3 — the append-only disposition classes

`tools/strategy_farm/apply_q10_news_review_dispositions.py` (same shape as the
Q09 lane tool: content-addressed plan, hash-bound apply, online SQLite backup,
`FactoryMutationLock`, one `BEGIN IMMEDIATE` transaction, per-row immutable
receipt, one `work_item_supersedes` edge per source):

* `SUCCESSOR_SUPERSESSION` (36) — a governed `farmctl readjudicate-news-8cell`
  successor already exists for the row (32 pre-existing + the 4 from step 1).
  The measurement is already concluded; only the supersession edge was missing.
  **No new work item is inserted** — the edge points at the existing successor
  and carries its `readjudication_provenance.json` as evidence.
* `SEALED_READJUDICATION` (46) — the current rule's own terminal verdict over
  the sealed bytes: `INVALID_EVIDENCE` /
  `Q10_NEWS_SEALED_READJUDICATION_INVALID_EVIDENCE`.
* `EVIDENCE_AGED_OUT` (2) — `INVALID_EVIDENCE` / `EVIDENCE_AGED_OUT_DL090`.
* declared residual, **not closed** (11) —
  `CONTROL_OR_POLICY_OFF_NOT_QUALIFIABLE`.

36 + 46 + 2 + 11 = 95.

## Hard invariants (verified by the tool, asserted in the receipt)

* historical `work_items` rows are never UPDATEd (`historical_work_item_updates: 0`);
* no verdict, trade stream or evidence file is deleted or overwritten;
* no `q09_news_tests` / `q09_news_cells` / `q09_news_arms` row is written by a
  disposition — a disposition is an adjudication **receipt**, not a new seal;
* no hold is created or released, nothing is enqueued, no tester runs;
* gate thresholds and `q09_news_contract` are untouched;
* the residual set is enumerated by exact id and re-checked at apply time: the
  tool refuses if the unsuperseded remainder is anything other than those 11.

## Not in scope, and deliberately untouched

* **52 pending Q10_NEWS rows** (51 with an active hold:
  28 `NEWS_CALENDAR_TAINTED`, 12 `NEWS_CALENDAR_TIMESTAMP_DEFECT`,
  9 `NEWS_RUNNER_SPAWN_SILENT_ABORT`, 2 `Q09_AWAITING_SEALED_PLAN`, 1 unheld).
  No hold is released here.
* **12 `failed` / `INFRA_FAIL` rows** — an infrastructure class, not a review
  backlog; none carries a hold.
* The live path. `ENV=live` EAs use the native MT5 calendar, fail-closed
  (DL-080, OWNER 2026-09-06). Nothing in this work reaches it.
