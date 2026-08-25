# HMA Category-A requalification execution receipt — 2026-08-25

## Scope and authority

- Router task: `c29fddf8-fab7-4909-a506-499f6ab78f37`
- OWNER decision: `OWNER-DEC-HMA-CATA`
- Decision path: `decisions/2026-08-25_owner_hma_requal_ftmo_park_q02_dead16.md`
- Approved census: `docs/ops/evidence/2026-08-24_qm_hma_ea_census.csv`
- Compile-label manifest: `docs/ops/evidence/2026-08-25_c29fddf8_hma_cata_compile_labels.csv`
- Source-repair authority: `router_ops_issue:c29fddf8-fab7-4909-a506-499f6ab78f37`

The scope is exactly the nine census rows with standing PASS evidence. No
Category-B/C EA was admitted. Historical Q02 and later rows were not edited.

## Fail-closed artifact binding

Commit `e2d56709c` adds the exact nine-label authority to the governed
`COMPILE_EA` enqueue path. Enqueue and worker recheck both fail closed unless
the following reviewed bytes remain unchanged:

| Artifact | SHA-256 |
|---|---|
| OWNER decision | `ec484d61c5d7a103522572d91fcee7adb50a899678e34e536087b593428c5bdd` |
| Approved HMA census | `d5393e1b51c6a43e693933142b384dcc88495b5e5dbc8fc611f0bf36df606d87` |
| Fixed `framework/include/QM/QM_Indicators.mqh` | `50d47f901236ed0a827fd9e74e82e781f52c7c9a45ff3097630b2e497686bca4` |

Each compile payload carries those three bindings, `owner_decision_id =
OWNER-DEC-HMA-CATA`, `requalification_scope = QM_HMA_CATEGORY_A`, and
`requalification_new_identity_from_phase = Q02`. It also carries the mandatory
backtest risk contract `RISK_FIXED = 1000.0`, `RISK_PERCENT = 0.0` and
`no_gate_verdict = true`.

Focused unit verification: `python -m pytest
tools/strategy_farm/tests/test_compile_work_items.py -q` → **22 passed**.

## Governed compile successors

Dry run: 9 requested, 9 eligible, 0 refused. Apply: 9 enqueued, all initially
held by `COMPILE_EA_WORKER_ROLLOUT_PENDING`. The reviewed release utility then
released one bounded source-fresh wave of exactly those nine rows; 9 applied,
0 deferred, and 0 active holds remained.

| EA | COMPILE_EA work-item ID | 2026-08-25 21:41Z state |
|---|---|---|
| `QM5_2002_nnfx-qqe-trend` | `b6fef2d3-23a5-4517-aef0-1946608bec51` | pending, unheld |
| `QM5_9998_tv-hull-suite-hma-color-flip` | `fe00c27a-7924-4f49-abf3-33d80e85032b` | pending, unheld |
| `QM5_10251_tv-nova-rev` | `e2a41bd1-87bd-434b-8b5d-b8c1e02b92bc` | pending, unheld |
| `QM5_10593_mql5-adxhull` | `96c09e7e-1586-4140-9dd1-9bbe96fbbbb5` | pending, unheld |
| `QM5_10602_mql5-oshma` | `5140d4a2-756d-4bca-9608-10299dba1748` | pending, unheld |
| `QM5_10833_tv-autobot12` | `c96c55ee-762a-4f47-81de-1b6126a6e4e2` | pending, unheld |
| `QM5_10960_ftmo-hma-rsi` | `b74f3eed-8140-4a79-bd71-cd035696b650` | pending, unheld |
| `QM5_12742_nnfx-configurable-engine` | `a3e70bd6-5123-4b43-9aeb-e40db80f9d8e` | pending, unheld |
| `QM5_12958_nnfx-hma-wae-swing` | `5deb4aa6-defe-4897-9495-62e003f09393` | pending, unheld |

Release receipt:
`D:/QM/reports/state/c29fddf8_hma_cata_compile_release_20260825.json`, SHA-256
`e2307dfa3bd30347e0977ae8b395ef19337aa1b68b1d572cc540fcaf2879b7b3`.
Pre-release database backup:
`D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260825T213515Z_45f8f6bc.sqlite`,
SHA-256 `8680f9c4d46e6d21c58be6c3fb5dcb4e31b37eca708dd5e2039bc4970f2067d9`.

The resident worker lane was not bypassed. At the snapshot, existing T1–T9 Q
work occupied the runnable capacity and free T10 was honoring the CPU admission
pause at approximately 100% load. No terminal process, active backtest,
AutoTrading, or T_Live state was touched.

## Q02 new-identity gate

There are 34 historical Q02 PASS rows in the exact nine-EA scope. These are the
immutable predecessor population for requalification:

| EA | Historical Q02 PASS count | Predecessor work-item IDs |
|---|---:|---|
| `QM5_2002` | 6 | `99386a70-0c1a-47a1-bd4f-ec139422cd17`, `c5422343-39b2-4b58-b05b-5c9ba70d7a77`, `4c976450-3d12-455a-9103-54ac4f072830`, `1ef55765-f263-4802-884a-d96859f9f5e9`, `4cfeae7f-3f1a-46af-9444-cf9e61122427`, `2aaff504-0d0c-4f9b-8133-1811d34a5728` |
| `QM5_9998` | 4 | `6a5bd2d0-eb83-4730-a31f-92c5ab011267`, `0fe95890-8eff-4a36-94eb-8768d3b4bd40`, `ad58fc48-775d-4903-815b-fb271d14807e`, `a16a065f-5aaf-493d-aaf0-73a38afafd02` |
| `QM5_10251` | 2 | `5e3ea8dd-b739-4bfc-a89a-d482d4c4b1f0`, `6d92406f-78eb-4db4-97c5-36a8d8638dea` |
| `QM5_10593` | 1 | `677c9a45-b30b-4e97-a028-987f80430a94` |
| `QM5_10602` | 2 | `d7d923cf-49c5-484f-b525-7f28e9772a78`, `8859d8c8-f205-4dfe-9c53-dad859169123` |
| `QM5_10833` | 1 | `cfd9c511-38cf-4776-8144-3de7ee43a2a2` |
| `QM5_10960` | 4 | `1dff9ba8-6d42-47e4-9144-d81ebfa41c29`, `528eca05-7aa2-4789-853f-9ad79a844e65`, `c8c99df5-265f-49c7-8f4f-2660db4df32b`, `d5786aac-3655-4139-bf2e-341ce1e67aab` |
| `QM5_12742` | 11 | `d23368a2-29d6-4818-9e10-4ac8e336e0b9`, `f4ece2d8-9da4-4633-866c-fe3fac56b072`, `353ac86c-033f-4e25-a71b-b3746da24196`, `b787a6eb-76a2-4aa9-b2fc-a4c5f4a5448f`, `5b1e3d7d-c6e8-4f95-a25a-d099a10abf29`, `1d0727df-1c62-4738-8db1-9980af323ca5`, `080e89f2-3d31-4c14-aebd-d5179c9b2151`, `9bcfe5cb-7a54-45ab-93e8-4fbc1b09ddf5`, `b75d01bf-2f09-4882-a40d-af43fbd11d34`, `f8f1926f-970d-42c2-a692-4d245aac69e3`, `8f0c3f26-d0d9-499b-b6c2-6c8c62d6dcd7` |
| `QM5_12958` | 3 | `4778c39a-5e41-46d7-9cd3-b7b5755b26c0`, `1777fa57-5bf5-4b39-98fb-4b442217426b`, `fead128a-781f-40eb-8f28-9af2858b4dfd` |

Q02 successor work-item IDs at the evidence snapshot: **none**. This is the
required fail-closed result because the compile snapshot contained 0
`COMPILE_OK` rows. A database query confirmed that no Q02/P2 row for these EAs
was created after the compile enqueue time. For each EA that later reaches an
evidence-backed `COMPILE_OK`, its applicable historical PASS rows must be
requeued through the exact-row append-only `farmctl enqueue-backtest` contract,
with the rebuilt current EX5 SHA-256 supplied as
`--expected-current-ex5-sha256`. Compile failure does not authorize Q02.

## Verification verdict

- SQLite `PRAGMA quick_check`: `ok`.
- Exact-authority compile rows: 9/9.
- Current MQ5 hash equals each queued payload hash: 9/9.
- OWNER/census/fixed-include bindings present and exact: 9/9.
- Fixed-risk contract present: 9/9.
- Active compile rollout holds: 0.
- Compile evidence verdicts at snapshot: 0 (all nine safely pending).
- New Q02 identity rows at snapshot: 0 (correctly gated on `COMPILE_OK`).
- Historical PASS verdicts rewritten: 0.
- Pipeline or promotion verdicts written: 0.

This receipt records a correctly admitted asynchronous rebuild wave, not a
pipeline verdict. Review must keep the Q02 continuation closed until the
individual compile evidence exists.
