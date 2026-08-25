# e9944090 stale COMPILE_EA rollout reconciliation

Task: `e9944090-1e0f-4dea-af90-e74f8079d1c8`  
Evidence time: 2026-08-25 21:11 UTC  
Result: **PASS — all 107 historical rollout holds have canonical successors and zero active rollout holds; no historical status or verdict was changed.**

## Bound census

The immutable initial census is
[`2026-08-25_e9944090_compile_rollout_initial_census.csv`](2026-08-25_e9944090_compile_rollout_initial_census.csv).
It contains exactly 107 rows that had an active
`COMPILE_EA_WORKER_ROLLOUT_PENDING` hold:

- 26 rows already had a later successor bound to the current MQ5 hash.
- 81 predecessor rows had no later current-source successor. Those 81 rows
  represented 76 unique EA labels, recorded in
  [`2026-08-25_e9944090_compile_rollout_successor_labels.csv`](2026-08-25_e9944090_compile_rollout_successor_labels.csv).
- A hash-only test would have called 20 of the 107 rows source-current. They
  were nevertheless historical predecessors because a later current-source
  compile row existed. Successor chronology therefore takes precedence over
  the predecessor's own hash.

The machine-readable classification plan is
[`2026-08-25_e9944090_compile_rollout_initial_plan.json`](2026-08-25_e9944090_compile_rollout_initial_plan.json).

## Append-only action

1. Enqueued 76 governed `COMPILE_EA` successors, one per missing EA label,
   under the exact authority
   `router_ops_issue:e9944090-1e0f-4dea-af90-e74f8079d1c8`.
2. Bound every new row to the then-current MQ5 SHA-256 and to
   `RISK_FIXED=1000`, `RISK_PERCENT=0`. All 76 carry `no_gate_verdict=true`.
3. Recorded 107 canonical `work_item_supersedes` edges. They point to 102
   unique successor rows: 26 pre-existing and 76 newly enqueued. The complete
   predecessor-to-successor map is
   [`2026-08-25_e9944090_compile_rollout_supersessions.csv`](2026-08-25_e9944090_compile_rollout_supersessions.csv).
4. Closed only the exact 107 stale activation holds. Work-item status,
   verdict, payload, and evidence fields were not rewritten. Reconciliation
   backup:
   `D:\QM\strategy_farm\state\backups\farm_state_before_compile_rollout_reconcile_20260825T205406Z_93c6dd55.sqlite`
   (`c0fb11aa62903c064374ff6a934401f360d32611034c74622f6dc9ec33a69f23`).
5. Released the 76 source-fresh successors through the ordinary guarded
   release tool in bounded waves `10+10+10+10+10+10+10+6`. No force option was
   used. Full backup receipts are in
   [`2026-08-25_e9944090_compile_rollout_wave_receipts.csv`](2026-08-25_e9944090_compile_rollout_wave_receipts.csv).

The release operation only removed activation holds. Resident workers retain
the canonical selector, ownership CAS, terminal lease, CPU/RAM/commit admission,
and compile-evidence path. At 21:11 UTC the 76-row successor cohort was 75
`pending` and one evidence-backed `failed/COMPILE_FAIL`; zero cohort rows were
held. The compile failure is work-item
`19918515-e8f4-460f-b9b8-136be81d5b13` (`QM5_1538`) with evidence at
`D:\QM\reports\work_items\19918515-e8f4-460f-b9b8-136be81d5b13\QM5_1538\COMPILE_EA\compile_evidence.json`.
It was produced by the compile worker and was not an operator verdict.

## Stale-daemon safety

The canonical selector now excludes every row present in
`work_item_supersedes`. Because resident workers can outlive a code rollout,
the same invariant is also installed as the SQLite trigger
`trg_work_items_superseded_no_activate`. A transaction probe against a real
superseded pending row returned `rowcount=0` and left its status and owner
unchanged. Schema-install backup:
`D:\QM\strategy_farm\state\backups\farm_state_before_compile_rollout_reconcile_20260825T210524Z_b66eaf38.sqlite`
(`3b6dcd3c24c9ce8d1b2d9f106d7b6337f8f4f46428a56b1f00b6a273659da4de`).

## Focused verification

Post-release database and filesystem verification at 21:11 UTC returned:

| Check | Result |
|---|---:|
| Initial census rows found | 107 / 107 |
| Initial status/verdict mismatches | 0 |
| Initial active rollout holds | 0 |
| Canonical supersession edges | 107 |
| Unique edge targets | 102 |
| Newly enqueued successors | 76 |
| New successors targeted by an edge | 76 / 76 |
| New successor active rollout holds | 0 |
| Invalid fixed-risk contracts | 0 |
| Missing `no_gate_verdict` flags | 0 |
| New successor MQ5 hash mismatches | 0 |
| Any successor-target MQ5 hash mismatches | 0 |
| Durable activation trigger present | yes |

Focused tests:

- `test_pending_superseded_claim_filter.py`
- `test_reconcile_compile_rollout_holds.py`
- `test_compile_work_items.py`
- Result after the durable-trigger addition: **25 passed**.
- Earlier selector/compile/news regression set: **85 passed**; post-
  classification correction set: **56 passed**.

Relevant commits on `agents/board-advisor`:

- `3b9feccec` — reconcile stale compile rollout holds
- `52a6bcdbe` — classify predecessors before source freshness
- `c533d5f7c` — gate superseded rows at the SQLite boundary
- `8285f5d05`, `1944b80f0` — corrected census and supersession evidence

No `--allow-force`, deletion, historical verdict rewrite, gate promotion,
T_Live action, AutoTrading action, terminal launch, merge, or main-worktree
operation occurred.
