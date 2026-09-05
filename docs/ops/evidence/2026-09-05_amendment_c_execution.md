# Amendment C execution — 2026-09-05

## Result

**PARTIAL / DEPENDENCY HOLD.** The deterministic Q12 owner rows already existed
and were bound to each pair's latest Q11 `PASS`. Amendment C queue order was
applied to all twelve exact rows. The three NDX rows were placed behind the
nine FX/metal/oil rows and carry active, non-restart `RAM_WINDOW_44GB` holds.

Three programs with existing approved measurement siblings were materialized
by the scheduled matrix service after the queue-order change. Six of the first
nine cannot materialize because no approved `_opt` measurement sibling exists.
The missing sibling builds are outside this execution ticket, so the claim that
all nine ledgers exist would be false. No direct SQL write was used.

## Dry run before mutation

The governed Q12 minting command is:

```text
python tools/strategy_farm/farmctl.py advance-optimization-fork --ea <EA> --symbol <SYMBOL> --apply
```

It selects the latest Q11 `PASS`, hash-binds its evidence, EX5, MQ5 and setfile,
and creates the deterministic Q12 owner. A dry run for 11708 returned no action
because its correct owner already existed. Read-only inspection confirmed the
same state for all twelve rows. Each owner payload names its exact Q11 parent;
none has `priority_track`.

The per-row queue-order plans were written before apply under:

`D:/QM/reports/portfolio/amendment_c_20260905/plan_final_*.json`

The prior governed tail ended at `2026-08-29T08:04:00+00:00`. The final plans
therefore allocate one-minute increments from 08:05, preserving the existing
tail and the decided order. `set_dl089_queue_order.py plan` revalidated each
exact pending Q12 row and projected K=8 ranks before mutation.

## Applied queue order

| Order | Pair | Q12 owner | Q11 parent | Program | `queue_order_at` |
|---:|---|---|---|---|---|
| 1 | 11708/EURUSD | `9102ff97` | `83ea8b70` | `DL089_QM5_11708_EURUSD_DWX_2019_2025` | `2026-08-29T08:05:00+00:00` |
| 2 | 12849/XTIUSD | `5c1085ce` | `db5fc5cd` | `DL089_QM5_12849_XTIUSD_DWX_2019_2025` | `2026-08-29T08:06:00+00:00` |
| 3 | 12855/XTIUSD | `a8b2dd82` | `8f073949` | `DL089_QM5_12855_XTIUSD_DWX_2019_2025` | `2026-08-29T08:07:00+00:00` |
| 4 | 20086/EURUSD | `fb54cd4e` | `274ba468` | `DL089_QM5_20086_EURUSD_DWX_2019_2025` | `2026-08-29T08:08:00+00:00` |
| 5 | 21501/USDJPY | `65b0f691` | `9aaee2a9` | `DL089_QM5_21501_USDJPY_DWX_2019_2025` | `2026-08-29T08:09:00+00:00` |
| 6 | 41221/EURUSD | `e0ab6e2a` | `01bf3a9a` | `DL089_QM5_41221_EURUSD_DWX_2019_2025` | `2026-08-29T08:10:00+00:00` |
| 7 | 21502/XAUUSD | `264c5715` | `79a62c27` | `DL089_QM5_21502_XAUUSD_DWX_2019_2025` | `2026-08-29T08:11:00+00:00` |
| 8 | 41219/XAUUSD | `b8729132` | `cc50783d` | `DL089_QM5_41219_XAUUSD_DWX_2019_2025` | `2026-08-29T08:12:00+00:00` |
| 9 | 11294/XAUUSD | `5dec5753` | `2c5558d5` | `DL089_QM5_11294_XAUUSD_DWX_2019_2025` | `2026-08-29T08:13:00+00:00` |
| 10 | 11660/NDX | `5183df54` | `736a56d3` | `DL089_QM5_11660_NDX_DWX_2019_2025` | `2026-08-29T08:14:00+00:00` |
| 11 | 13013/NDX | `f9ed7f92` | `04923040` | `DL089_QM5_13013_NDX_DWX_2019_2025` | `2026-08-29T08:15:00+00:00` |
| 12 | 20086/NDX | `1165f546` | `2d3729cc` | `DL089_QM5_20086_NDX_DWX_2019_2025` | `2026-08-29T08:16:00+00:00` |

Apply receipts are under
`D:/QM/reports/portfolio/amendment_c_20260905/apply_final_*.json`. Each was
written by the governed tool after SQLite backup, `BEGIN IMMEDIATE`, exact-row
CAS, append-only event insertion and readback. The post-apply inventory is
`D:/QM/reports/portfolio/amendment_c_20260905/queue_after.json`.

The post-apply modeled ranks are 7 through 18. Rows 11708 and 12849 occupy the
two currently open modeled positions within K=8; the list command documents
that its rank is an upper bound because the service independently drops rows
without a ready measurement sibling. No running program was displaced.

## Materialization and binding verification

The scheduled service materialized the three ready programs after order apply:

| Pair | Sibling | Ledger owner binding | Cells | First declared cell |
|---|---|---|---:|---|
| 12849/XTIUSD | QM5_41307 | Q12 `5c1085ce…`, declaration `04c06df4…` | 1,085 | `2b47e185…`, pending, unclaimed, no hold |
| 12855/XTIUSD | QM5_41305 | Q12 `a8b2dd82…`, declaration `1473398b…` | 1,085 | `e7ebd427…`, pending, unclaimed, no hold |
| 21501/USDJPY | QM5_41324 | Q12 `65b0f691…`, declaration `28d1a1f6…` | 1,085 | `8178faa6…`, pending, unclaimed, no hold |

`farmctl service-dl089-matrix` dry-runs classified these owners as maintained,
which invokes the poison-program guard: ledger Q12 id, declaration SHA and the
complete deterministic cell-id set must all match before maintenance. Owner
rows have no `priority_track`; matrix cells retain the service's normal census
priority metadata. The first declared cell in each materialized program is
structurally claimable (`pending`, `claimed_by=NULL`, no active hold).

The same dry-run returned the exact fail-closed dependency for the other six:

```text
expected one approved _opt sibling for QM5_11708/EURUSD.DWX, found 0
expected one approved _opt sibling for QM5_20086/EURUSD.DWX, found 0
expected one approved _opt sibling for QM5_41221/EURUSD.DWX, found 0
expected one approved _opt sibling for QM5_21502/XAUUSD.DWX, found 0
expected one approved _opt sibling for QM5_41219/XAUUSD.DWX, found 0
expected one approved _opt sibling for QM5_11294/XAUUSD.DWX, found 0
```

No synthetic ledger or ungoverned sibling was created to conceal this gap.

## NDX hold verification

`governed_work_item_hold.py plan` first found the three owner rows' transitional
`Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING` holds. Apply superseded those exact
hold slots in place with:

```text
hold_code=RAM_WINDOW_44GB
active=1
release_on_restart=0
reason=OWNER Amendment C: NDX census may run only in a 44 GB single_index_tick window
release_condition=OWNER/CEO verifies a 44 GB single_index_tick admission window and releases this exact hold
```

Plan/apply receipts are
`D:/QM/reports/portfolio/amendment_c_20260905/hold_{plan,apply}_*.json`.
The NDX rows remain pending and unclaimable. No terminal was started or stopped.

## OPEN_ITEMS-ready disposition

- Queue-order portion: **APPLIED and verified** for 12/12 exact owner rows.
- NDX RAM control: **APPLIED and verified** for 3/3 rows.
- Ledgers: **3/9 first-wave programs materialized and bound**; 6/9 wait on
  separately authorized measurement-sibling builds.
- D1 shortening caveat: these three ledgers were materialized with the existing
  1,085-cell declaration. The separate B2/B5 implementation must preserve
  already-enqueued years, as its OWNER contract requires; this artifact does
  not rewrite cells or verdicts.
- Rollback: queue rows can be moved with another governed
  `set_dl089_queue_order.py apply`; NDX holds can only be released with the
  exact governed `farmctl release-hold` path after the 44-GB condition is met.
