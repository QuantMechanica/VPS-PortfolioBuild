# Timeout derivation cross-review and Q04 requalification

Date: 2026-08-16  
Router task: `ba8f9d65-6859-4c5e-88ff-0223a84ab7c2` (priority 76)  
Branch: `agents/board-advisor`  
Implementation commit: `a9ea3d20c` (`farm: derive Q04 timeout budgets`)

## Verdict

**REVIEW — implementation and focused verification PASS; 21 timeout-affected Q04 rows received current-EX5-bound, append-only successors. No pipeline verdict is asserted.**

The reviewed Q02 timeout work composes correctly, remains Q02-only, and does not shrink a larger budget. The Q04 runner now receives a per-fold timeout derived from predecessor workload evidence instead of relying on its flat 1,800-second default. Historical Q04 rows were preserved.

## Independent review findings

### Claude lane `c51bacc47`

- `BASKET_Q02_ACTIVE_TIMEOUT_MIN=450` is applied only by the Q02 guard. A non-Q02 phase returns without changing the payload.
- Every covered Q02 creation/recovery path uses `max(existing, 450)`, so a larger operator or workload budget is retained.
- The worker watchdog already consumes the payload using a maximum with its default; the enqueue-side floor therefore does not double-count or shrink the worker allowance.
- The sweep subprocess regression was retained and its child timeout was raised from 60 to 180 seconds rather than skipped.

### Claude commit `57e60130b`

- `_payload_timeout_floor_seconds()` converts a positive `timeout_min` into seconds and caps it at 25,200 seconds.
- Both basket smoke branches take the maximum of the existing computed smoke budget and the payload floor, then retain the 25,200-second ceiling.
- Consequently, `timeout_min=450` budgets both the worker watchdog and smoke layer at the governed cap without reducing a larger pre-cap computation.

### Q04 completion `a9ea3d20c`

- A new Q04 row derives its per-fold child allowance as the maximum of:
  - the historical 1,800-second floor;
  - the predecessor payload timeout floor; and
  - `ceil(1.5 * observed Q02 full-run seconds)`.
- The per-fold result is capped at 25,200 seconds.
- The outer Q04 watchdog is derived from the per-fold allowance times the budgeted fold count plus 900 seconds of phase headroom. It is floored by the existing Q04/default payload allowance, so it never shrinks a larger budget, and is capped at 1,440 minutes.
- The dispatcher passes the bound value explicitly to `q04_walkforward.py` as `--timeout-sec`.
- The helper follows Q03 lineage back to its Q02 source and rejects corrupt lifecycle spans over seven days rather than manufacturing an excessive timeout.

## Exact 21-row scope

The reproducible scope is 15 terminal Q04 aggregate reports whose metric reason contains `timeout`/`FOLD_TIMEOUT`, plus six terminal Q04 watchdog timeout rows. A seventh historical watchdog timeout, `cffc4c97-4062-486e-8b37-0a548caa7929` (`QM5_20007`, GDAXI), was not part of the 21 because the same exact lane later produced economic Q04 result `463815b5-...` (`FAIL`). Requalifying that lane would not be an infrastructure-only recovery.

All UUIDs in the ledger below are unique eight-character prefixes of the full IDs stored in `farm_state.sqlite`. Each successor payload contains the full source UUID in `append_only_rerun_of_work_item` and the full predecessor UUID in `promoted_from_work_item`.

| Timeout row | EA / symbol | PASS predecessor | Append-only successor | Fold sec | Outer min |
|---|---|---:|---:|---:|---:|
| `ba1ea93b` | QM5_11063 / USDJPY.DWX | `86efcc45` | `b992af25` | 1,800 | 105 |
| `5f483663` | QM5_11063 / USDJPY.DWX | `53e9d462` | `ee68af94` | 1,800 | 105 |
| `2475c388` | QM5_11063 / USDJPY.DWX | `fbfd58e7` | `ba8108ee` | 1,800 | 105 |
| `d243a0a0` | QM5_1238 / XAUUSD.DWX | `3c85e41c` | `7bf0e9ee` | 4,991 | 265 |
| `3a44a91f` | QM5_9993 / XAUUSD.DWX | `a6453e12` | `01ff7a74` | 3,054 | 168 |
| `878f9a19` | QM5_10590 / EURUSD.DWX | `5b93ebb7` | `f1243e72` | 1,800 | 105 |
| `51bb9afc` | QM5_10242 / GDAXI.DWX | `2f4b08b0` | `20ae8fa6` | 1,800 | 105 |
| `40c7cd31` | QM5_11028 / USDJPY.DWX | `7b54f466` | `1a5134c6` | 1,800 | 105 |
| `35ec82a1` | QM5_11063 / EURJPY.DWX | `cd0aeefd` | `832bb1fb` | 1,800 | 105 |
| `b8549322` | QM5_11063 / EURJPY.DWX | `5292219b` | `7657f9da` | 1,800 | 105 |
| `9a966b83` | QM5_20161 / logical XAU-XAG | `99ce65cf` | `8a0a2e52` | 1,800 | 105 |
| `6fb49151` | QM5_9940 / SP500.DWX | `5512d166` | `5097abf4` | 2,700 | 150 |
| `e31925ae` | QM5_10593 / XAUUSD.DWX | `127140d6` | `8084f025` | 25,200 | 1,275 |
| `a9e94a4a` | QM5_10649 / XAUUSD.DWX | `7e0747d8` | `c2ce418a` | 3,758 | 203 |
| `72fff543` | QM5_1287 / XAUUSD.DWX | `f4d8d96a` | `ab9e8806` | 1,800 | 105 |
| `4efead68` | QM5_11502 / EURUSD.DWX | `d6b8ff19` | `871e6ffb` | 1,800 | 105 |
| `b89b9621` | QM5_9642 / NDX.DWX | `b6b43f81` | `215317c3` | 1,800 | 105 |
| `1be8a4dc` | QM5_11030 / EURJPY.DWX | `c26f42a6` | `f6ed8527` | 1,800 | 105 |
| `1d52b123` | QM5_1443 / EURUSD.DWX | `d0d79d5a` | `48f156eb` | 1,800 | 105 |
| `f33bef87` | QM5_10252 / XAUUSD.DWX | `8a626a92` | `ede15218` | 1,800 | 105 |
| `e077674d` | QM5_11078 / USDJPY.DWX | `a9af8567` | `4477e7f2` | 6,204 | 326 |

For the specifically requested QM5_11078 row, the successor is bound to current EX5 SHA-256 `9afea2a339a2c380a82dadb54cc40e6c23011599e30c53d3a679b0822330485d`; its recorded Q02 runtime is 4,136 seconds, producing `ceil(1.5 * 4136) = 6204` seconds per fold.

## Admission and append-only checks

- 21/21 referenced setfiles exist and satisfy `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- 21/21 successors were created by `farmctl enqueue-backtest --phase Q04` with an exact PASS predecessor, exact terminal rerun target, rerun reason, and `--expected-current-ex5-sha256`.
- 21/21 successor payloads match the current canonical EX5 hash at verification time.
- 21/21 retain full append-only lineage; no historical work item, verdict, report, or metric was mutated.
- At the post-enqueue snapshot, all 21 successors were `pending`; no terminal was launched manually and no active tester was interrupted.
- Fold budgets span 1,800–25,200 seconds and all carry `q04_timeout_basis=q02_runtime_and_payload_timeout`.

## Focused verification

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_q04_latest_full_year_payload.py \
  tools/strategy_farm/tests/test_smoke_timeout_override.py \
  tools/strategy_farm/tests/test_basket_work_items.py \
  tools/strategy_farm/tests/test_candidate_repair_enqueue.py \
  tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py

69 passed in 44.59s
```

Additional checks:

```text
python -m py_compile tools/strategy_farm/farmctl.py
PASS

git diff --check a9ea3d20c^ a9ea3d20c
PASS
```

This is implementation and queue-admission evidence only. The 21 successors remain subject to normal factory execution and pipeline classification; no Q04 or broader pipeline PASS/FAIL verdict is inferred here.
