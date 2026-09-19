# Q12 DL-089 matrix-service expansion diagnosis — 2026-09-19 (ticket 12582f77)

Scope: diagnose why declared Q12 DL-089 pattern rows are not expanding into `OPT_CENSUS`
cells (0 Q12 completions / 24h at ticket creation, 10:27Z). GRÜN only — no gate/selection-
rule change; DL-089 selection-rule changes are ROT-by-versioning and were not touched.

## Method

Ran `python tools/strategy_farm/farmctl.py service-dl089-matrix` (dry-run, read-only) from
the canonical checkout `C:/QM/repo` against the live `D:/QM/strategy_farm/state/farm_state.sqlite`,
2026-09-19 ~13:00Z. This is the identical classification code path the pump's `apply=True`
stage runs first (`service_dl089_matrix` plans read-only, then writes only the selected
`slot_owners`) — so this dry run reproduces exactly what the live pump sees each cycle.
Cross-checked two categories directly against `work_items`/`work_item_holds` for spot proof.

## Population

- Pending, unclaimed, unverdicted Q12 rows with `role=PATTERN` + the DL-089 routing
  revision: **105** at diagnosis time (up from the ticket's "37 unheld" count at 10:27Z —
  the duplicate-declaration source described below kept minting new rows in the interim;
  confirmed independently via SQL: 83 of the 105 carry no active hold and
  `execution_lane=GOVERNED_ANALYTIC_DISPATCH`, i.e. the ticket's "unheld" framing).
- Distinct `program_id`s represented: **31** (avg ~3 duplicate Q12 rows per program;
  `DL089_QM5_11422_USDCAD_DWX_2019_2025` has 6).

## Evidence table — per-row disposition

| Disposition | Count | Meaning | Correct? |
|---|---|---|---|
| `DL089_DUPLICATE_ADJUDICATED_PROGRAM` | 70 | `program_id` already has a completed `q12_selection_receipt.json` written by a **different, earlier** Q12 row | Yes — correct fail-closed dedup (`_adjudicated_program_receipt`) |
| `PROGRAM_Q12_REBIND_REFUSED` | 15 | `program_id`'s materialized `OPT_CENSUS` cells are already bound (`parent_task_id` + `q12_work_item_id`) to a **different** Q12 row than the one being serviced | Yes — correct ownership guard (`_program_binding_guard`) |
| blocking hold (non-DL089) | 15 | Active hold unrelated to this service: `RAM_WINDOW_44GB` ×3 (QM5_20086/11660/13013 NDX), `ARTIFACT_BINDING_CONTENT_CHANGED`/`_REBUILD_IN_PROGRESS`/`_SETFILE_SUCCESSOR_REQUIRED` ×10 (QM5_10706/13054/21505/11421), `BALKE_PATTERN_REPAIR_REVIEW_PENDING` ×2 (QM5_13213) | Yes — legitimate cross-cutting holds tracked by today's items 2/3 (tickets 23ccce7a, 42877794) |
| missing measurement sibling | 5 | `expected one approved _opt sibling for X/Y, found 0`: QM5_20086/NDX.DWX (×3), QM5_11294/GDAXI.DWX (×2) | Genuine gap — needs a build/approve task, not a matrix-service fix |
| **Total** | **105** | | |

Capacity/slot outcome this cycle: `program_slots_effective=8`, `worker_count=10`,
**`capacity_waits: []`, 0 `slot_owners`, 0 `materialized`, 0 `maintained`, 0 active
`OPT_CENSUS` cells** — not a program-slot or cell-slot ceiling; zero of the 105 candidates
survived past classification to reach materialization.

### Per-EA/symbol breakdown (program_id → disposition counts)

| EA/symbol | DUPLICATE_ADJUDICATED | REBIND_REFUSED | other hold | missing sibling |
|---|---|---|---|---|
| QM5_10145/XAUUSD | 3 | | | |
| QM5_10403/XAUUSD | 3 | | | |
| QM5_10513/XAUUSD | 3 | | | |
| QM5_10700/XAUUSD | 3 | | | |
| QM5_10706/GBPUSD | 2 | | 4 | |
| QM5_10911/GDAXI | 3 | | | |
| QM5_11294/GDAXI | | | | 2 |
| QM5_11294/XAUUSD | | 3 | | |
| QM5_11421/EURUSD | 4 | | 2 | |
| QM5_11422/USDCAD | 6 | | | |
| QM5_11660/NDX | 2 | | 1 | |
| QM5_11708/EURUSD | 3 | | | |
| QM5_11881/GBPUSD | 3 | | | |
| QM5_11910/NZDUSD | 3 | | | |
| QM5_12710/XTIUSD | 3 | | | |
| QM5_12849/XTIUSD | 3 | | | |
| QM5_12855/XTIUSD | 3 | | | |
| QM5_13013/NDX | 2 | | 1 | |
| QM5_13054/XTIUSD | 1 | | 2 | |
| QM5_13213/USDJPY | 1 | | 2 | |
| QM5_1537/XAGUSD | 3 | | | |
| QM5_20048/XTIUSD | 3 | | | |
| QM5_20086/EURUSD | | 3 | | |
| QM5_20086/NDX | | | 1 | 3 |
| QM5_20266/XTIUSD | 3 | | | |
| QM5_21501/USDJPY | 3 | | | |
| QM5_21502/XAUUSD | 3 | | | |
| QM5_21505/XAGUSD | 1 | | 2 | |
| QM5_21507/XAUUSD | 3 | | | |
| QM5_41219/XAUUSD | | 3 | | |
| QM5_41221/EURUSD | | 3 | | |
| QM5_9641/WS30 | | 3 | | |

## Spot verification (DB, direct SQL)

- Program `DL089_QM5_11294_XAUUSD_DWX_2019_2025`: owner Q12 row `5dec5753-feb0-5e6f-97d8-5393f9595eff`
  is `status=done`, `verdict=NO_FILTER_CHANGE`, `updated_at=2026-09-09T05:24:25Z`. Its `OPT_CENSUS`
  cell rows carry `done/MEASURED` and `done/SKIPPED_PRESCREEN` verdicts — real, already-adjudicated
  evidence. The duplicate declaration row `25f11e30-93a7-5c27-a941-90ca81adaf49` (created
  2026-09-09T12:33Z, ~7h **after** the owner had already finished) is a pure re-declaration and was
  correctly refused (`PROGRAM_Q12_REBIND_REFUSED`).
- No historical `DL089_MATRIX_SERVICE_FAILED` occurrence exists in `agent_tasks` or `work_items`
  `payload_json` other than this ticket's own creation payload (verified by full-table `LIKE` scan).
  The pump stage has never crashed; "0 completions/24h" reflects zero valid candidates, not a fault.

## PRESCREEN_SKIPPED / OWNER-DEC-D1-PRESCREEN-20260905 check

Today's item-2 finding cites a farm-wide `PRESCREEN_SKIPPED` hold count of 2,555 rows. None of the
105 Q12 rows examined here carry that hold — it applies to other phases/rows entirely. No Q12 row in
this population is blocked by prescreen.

## Verdict

**The `dl089_matrix_service.py` pass is healthy.** Every one of the 105 currently-pending Q12
declarations is correctly withheld from expansion for an evidenced, legitimate reason (already
adjudicated, real ownership elsewhere, an unrelated cross-cutting hold, or a genuine missing
prerequisite). No gate, selection-rule, or verdict-logic change is needed or was made. Closing per
acceptance criterion 3 ("if the service is healthy ... say so and close").

## Root cause of the pile-up (not fixed here — different component)

Something upstream of `dl089_matrix_service.py` keeps minting new Q12 PATTERN declaration rows for
`program_id`s that already have a finished (`DUPLICATE_ADJUDICATED`, 70 rows) or currently-owned
(`REBIND_REFUSED`, 15 rows) matrix — 85 of 105 rows (81%) are pure re-declarations. Observed
cadence: repeat declarations ~10 minutes apart (2026-09-09T12:33Z, 12:43Z, ...) for programs whose
real owner had already reached a terminal verdict hours earlier. The minting logic lives outside
this ticket's scope (likely `optimization_fork_driver.py` / `optimization_fork_service.py`, the
DL-089 candidate-declaration producers) and was not touched here.

## Follow-up recommendations (not actioned this cycle)

1. **Root-cause the duplicate-declaration minter** so it checks for an existing pending/active/done
   Q12 row on the same `program_id` before inserting a new declaration. Until fixed, this population
   keeps growing (37→83 unheld between 10:27Z and 13:00Z today) even though every row is inert.
2. **Genuine capacity gap**: build + approve `_opt` measurement siblings for QM5_20086/NDX.DWX and
   QM5_11294/GDAXI.DWX — 5 rows are permanently stuck without one.
3. **Optional GRÜN cleanup** (append-only, no verdict/gate change): a bounded janitor pass that
   stamps rows classified `DL089_DUPLICATE_ADJUDICATED_PROGRAM` / `PROGRAM_Q12_REBIND_REFUSED` with
   a non-restart informational hold (mirroring `_ensure_rollout_hold`'s pattern), so farm-health
   counters stop reporting them as "unheld" background noise. Left as a recommendation, not
   executed, to keep this cycle's change surface at zero per the diagnostic-only scope of this
   ticket.

## Evidence

- Command: `python tools/strategy_farm/farmctl.py service-dl089-matrix` (dry-run), run from
  `C:/QM/repo`, 2026-09-19 ~13:00Z, against live `D:/QM/strategy_farm/state/farm_state.sqlite`.
- Direct SQL spot-check of `work_items`/`work_item_holds` for program
  `DL089_QM5_11294_XAUUSD_DWX_2019_2025` and a full-table scan for prior
  `DL089_MATRIX_SERVICE_FAILED` occurrences (none found besides this ticket).
