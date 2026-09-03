# DL-089 governed queue-order tool + recommended slot plan (2026-09-03)

Implements item 2 of `OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903`
(`docs/ops/evidence/2026-09-03_owner_dec_pre0803_recompile_slot_order_amendment_b.md`):
order the governed DL-089 program queue so that "adds a pair to the counter first" wins —
Q11-contiguous pairs ahead of second passes of pairs that already count.

## 1. Mechanism (unchanged code, new operator path)

`dl089_matrix_service._queue_order(row, payload)` returns
`(str(payload["queue_order_at"] or row["created_at"]), str(row["id"]))`
(`tools/strategy_farm/dl089_matrix_service.py:709`) and both
`service_pending` (`:1241`) and `refill_existing_frontiers` (`:976`) sort candidates by
that key **ascending**; the first `dl089_scheduling.program_slots()` rows own a program
slot, the rest are deferred with `PROGRAM_SLOT_WAIT:K=<k>` (`:1361`).
`DL089_PROGRAM_SLOTS` is a machine environment variable currently set to `8`
(`reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
/v DL089_PROGRAM_SLOTS` → `REG_SZ 8`), matching `program_slots_configured: 8` in
`D:\QM\strategy_farm\logs\pump_task_20260903T014301Z.log`.

New tool: `tools/strategy_farm/set_dl089_queue_order.py`
(`plan` / `apply` / `list`, JSON out, schema `qm.dl089-queue-order/v1`), modelled on
`tools/strategy_farm/governed_work_item_hold.py`:

* exact `WORK_ITEM_ID=SYMBOL` targets, plus an `--ea-id` set that must match the targets
  exactly; revalidated inside the write transaction against `status='pending'`,
  `verdict IS NULL`, `claimed_by IS NULL`, `phase='Q12'` and
  `dl089_matrix_service._is_dl089_pattern` (role `PATTERN` + `routing_revision`
  `dl089-annual-wf-cells-v1` + a `pattern_filter_sweep` object);
* apply: SQLite backup (`farm_state_before_dl089_queue_order_<stamp>.sqlite`, path +
  sha256 recorded in every event) → `BEGIN IMMEDIATE` → per-row `UPDATE … WHERE
  payload_json=<exact previous bytes> AND …` compare-and-set → one
  `dl089_queue_order_set` event carrying `previous_queue_order_at` /
  `previous_sort_key` / `rank_before` / `rank_after` → pre-commit re-read that the value
  is set and that no other payload key drifted → commit; `retry_sqlite_busy` reopens the
  whole transaction on SQLITE_BUSY (short-timeout doctrine);
* the only column written is `work_items.payload_json`, and the only payload key written
  is `queue_order_at` (rewrite via `json.dumps(payload, sort_keys=True)`). Status,
  verdict, `claimed_by`, `updated_at` and `work_item_holds` are never touched, so the
  already-measured cells of a demoted program stay and resume when a slot frees;
* re-applying the same value is a no-op (`updated: 0`, `already_set: n`, no new event);
* `--list` is read-only (`mode=ro` URI) and prints rank, slot / `PROGRAM_SLOT_WAIT:K=…`,
  `queue_order_at` vs `created_at`, and the OPT_CENSUS cell counts per program.

### Ordering trap, guarded

`_queue_order` sorts ascending, so writing "now" pushes a row **behind** every row that
keeps its (past) `created_at`. `--front` still defaults to now (operator contract), but a
directional guard refuses any write whose projected rank does not actually improve
(`front_does_not_advance:<id>:rank_before=…:rank_after=…`); `--defer` is guarded the
other way. Real fronting needs an explicit `--queue-order-at` earlier than the current
queue head (that is exactly how `1a92b33e` got `2026-08-26T03:37:39` while its
`created_at` is `2026-08-26T11:25:34`).

## 2. Measured current state (read-only, live DB)

`set_dl089_queue_order.py list` against
`D:\QM\strategy_farm\state\farm_state.sqlite` (mode=ro) returns 27 pending governed Q12
pattern rows. The listed rank is an **upper bound**: `service_pending` additionally drops
rows whose measurement Q02 sibling is not `done/PASS` and rows refused by
`_program_binding_guard`. The 01:43Z pump run
(`D:\QM\strategy_farm\logs\pump_task_20260903T014301Z.log`, `slot_owners` +
`deferred` + `q02_prerequisites`) proves 13 of the 27 are not candidates:

| reason | work items |
| --- | --- |
| `expected one approved _opt sibling …, found 0` | `2ea9cd64` 13213/USDJPY, `1165f546` 20086/NDX, `5dec5753` 11294/XAUUSD, `264c5715` 21502/XAUUSD, `96239586` 10911/GDAXI, `fb54cd4e` 20086/EURUSD, `9102ff97` 11708/EURUSD |
| `PROGRAM_Q12_REBIND_REFUSED` | `2dad5730` 10706/GBPUSD, `f364ed13` 11422/USDCAD, `19761d0c` 11421/EURUSD |
| measurement Q02 sibling still `active`/`pending` | `559ec02f` 10403/XAUUSD, `5183df54` 11660/NDX, `65b0f691` 21501/USDJPY |

The remaining 14 candidates, in `_queue_order` order, reproduce the live
`slot_owners` 1–8 of that pump run exactly — independent confirmation of the model.

## 3. Recommended plan

Defer both second-pass programs of pairs that already count:

* `1a92b33e-e34f-532e-80b3-e0144f3b3755` — QM5_10706/GBPUSD.DWX (rank 1 → 13)
* `f9e1f7fc-f92e-5399-9f7d-c7e83e940ce5` — QM5_11422/USDCAD.DWX (rank 2 → 14)

Resulting slot order (`artifacts/dl089_queue_order_plan_20260903.json`,
`order_after`):

| slot | work item | pair | change |
| --- | --- | --- | --- |
| 1 | `c41e2606-3af1-5766-9bb7-18de8a763a18` | QM5_1537/XAGUSD.DWX | was 3 |
| 2 | `99e7e9db-d9a7-514c-b78d-c14e98ebec5d` | QM5_21507/XAUUSD.DWX | was 4 |
| 3 | `d824e8cb-8397-5aa3-b6fa-fec9b0c375eb` | QM5_11881/GBPUSD.DWX | was 5 |
| 4 | `d8739ae2-1ce4-553a-9b59-1335e582614c` | QM5_20266/XTIUSD.DWX | was 6 |
| 5 | `5a109261-f52c-5ed8-9dd3-9edec460697a` | QM5_10145/XAUUSD.DWX | was 7 |
| 6 | `1c4e28c2-63b0-527d-8ebc-cee9529c89ef` | QM5_10513/XAUUSD.DWX | was 8 |
| 7 | `5a6d1b1c-7c40-5414-abc8-b59421eabf82` | QM5_20048/XTIUSD.DWX | **enters** (was `PROGRAM_SLOT_WAIT:K=8`) |
| 8 | `540eadc0-4a99-5f0f-b69b-1601de434ab6` | QM5_21505/XAGUSD.DWX | **enters** (was `PROGRAM_SLOT_WAIT:K=8`) |

Still waiting, in the order they would enter as slots free:
`a8b2dd82` QM5_12855/XTIUSD → `a593158d` QM5_9641/WS30 → `5c1085ce` QM5_12849/XTIUSD →
`f9ed7f92` QM5_13013/NDX → then the two deferred programs (`1a92b33e`, `f9e1f7fc`).
Slot 1 (`c41e2606`, QM5_1537/XAGUSD) has 1085 done / 1 pending cell and should free
first, letting QM5_12855 in without any further intervention.

## 4. Verification

* `python -m pytest tools/strategy_farm/tests/test_set_dl089_queue_order.py -q` → 16 passed.
* Plan against a scratch mirror of the 14 live candidate rows:
  `artifacts/dl089_queue_order_plan_20260903.json` (`status: ok`, `would_update: 2`).
* Apply rehearsal on a copy of that mirror: `updated: 2`, one
  `dl089_queue_order_set` event per row carrying `previous_queue_order_at`
  (`2026-08-26T03:37:39.134570+00:00` / `null`), and a byte-level diff against the live
  payloads showed the remaining 23 resp. 22 payload keys identical and
  `status/verdict/claimed_by/updated_at` unchanged.
* Nothing in this work wrote to `D:\QM\strategy_farm\state\farm_state.sqlite`.
