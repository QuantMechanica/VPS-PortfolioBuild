# DL-089 Q12 matrix-dispatch integrity repair

- Router task: `78f6404a-cfc5-43da-befb-1d0b6fa58376`
- Authority: `router_ops_issue:78f6404a-cfc5-43da-befb-1d0b6fa58376`
- Date: 2026-08-26
- Branch: `agents/board-advisor`
- Scope: dispatch integrity and append-only recovery; no pipeline verdict and no live authority

## Finding

The two Q12 rows were declarations of 1,085 annual cells plus four sealed walk-forward cells, but the generic terminal claimant treated each declaration as one ordinary setfile run. `optimization_fork_driver.py` emitted `kind=analytic`, `execution_lane=GOVERNED_ANALYTIC_DISPATCH`, and `routing_revision=dl089-annual-wf-cells-v1`; however, `farmctl.pending_claim_order_sql()` did not exclude that control-plane shape. `terminal_worker.py` consequently fell through to the generic smoke runner. `opt_census.py` existed, but no service consumed the declaration and materialized its cell ledger.

The resulting evidence is real MT5 smoke evidence, but it is not evidence for the declared matrix. Both summaries have schema `run_smoke/v2`, requested two repeated 2024 runs, and contain no declared-cell receipts:

| Immutable source row | Subject | Source status/verdict | Summary SHA-256 | Declared annual/WF cells | Actual evidence shape |
|---|---|---|---|---:|---|
| `dfca24fa-28df-5f5e-818f-8dcf53611822` | `QM5_10706 / GBPUSD.DWX` | `done / PASS` | `a5210a2d5fdccc8ea910f5026b949aa94c1d93d4c5ae187a12a769200812cefb` | 1,085 / 4 | two identical 2024 smoke runs |
| `d0e53004-659c-563c-8314-c24ad4ab2a68` | `QM5_11421 / EURUSD.DWX` | `done / PASS` | `a0199e16b0477af10394acaba3923839a16feb2f2af99731ff788dbab72174ae` | 1,085 / 4 | two identical 2024 smoke runs |

The source rows, their verdicts, and their evidence paths are preserved unchanged. Recovery uses deterministic append-only successors:

| Source row | Recovery successor | Declaration SHA-256 |
|---|---|---|
| `dfca24fa-28df-5f5e-818f-8dcf53611822` | `1a92b33e-e34f-532e-80b3-e0144f3b3755` | `6dd542a2302ec5ee866c3c12e2509e200b15c6904f1e1d196c5451685c2bc49b` |
| `d0e53004-659c-563c-8314-c24ad4ab2a68` | `c4bc189b-372d-54c9-be45-046ac77b245b` | `40db534ec0c022eb8a5f98ccc5372abf5189511479b30ef176568d866a5fe7cb` |

## Repair

The repair adds four fail-closed boundaries:

1. Generic claim SQL excludes governed analytic declarations and every `dl089-annual-wf-cells-v1` row. A targeted generic claim also returns `governed_analytic_dispatch_required` without mutating the row.
2. `dl089_matrix_service.py` validates the sealed declaration hashes and exact UUIDs, discovers the unique approved instrumented `_opt` sibling, binds current source/binary/compile evidence, writes an immutable neutral fixed-risk measurement set, seeds its Q02 prerequisite, and materializes the exact 1,085 declared annual cells. It services only one EA/symbol pair at once and keeps exactly eight pending cells priority-tracked.
3. The census fixture gate now treats `83b89730-bb86-4c18-955a-efefe3039cc5` as the historical root/anchor and resolves its newest `done / HARNESS_OK` successor, matching the existing Q12 declaration contract. An explicitly supplied non-root harness ID remains exact and fail-closed. This closes the apply-time mismatch where the original root's `INFRA_FAIL` masked later governed green runs.
4. Q12 can close only after all materialized cells have `done / MEASURED` evidence and the sealed walk-forward selector reaches a terminal pattern state. The runner never converts a smoke summary into a Q12 verdict.

The neutral measurement set is generated under `D:/QM/strategy_farm/artifacts/opt_census/`; it forces all six `opt_pp_*` inputs to `0` without editing concurrently owned EA setfiles. It enforces `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and rejects `qm_news_stale_max_hours > 336`.

The original protection hold on pending row `f9e1f7fc-f92e-5399-9f7d-c7e83e940ce5` is converted in place to `release_on_restart=1`. This preserves its one-slot hold history while ensuring old resident workers cannot claim it. After a normal governed worker restart loads the hard claim guard, the hold may release safely; the row remains fail-closed behind the current `QM5_41163` compile prerequisite. No worker or terminal was restarted manually.

## Compile binding

The initial `QM5_41161` and `QM5_41162` compile receipts predated the final normalized source bytes. Two append-only, source-hash-bound compile successors were admitted under the exact router-task/EA allowlist:

| Measurement EA | Governed compile successor | Binary SHA-256 | Compile-evidence SHA-256 |
|---|---|---|---|
| `QM5_41161_tv-mon-ls-opt` | `c29b6c89-45d3-4139-912e-2e2e49f1a470` | `d96c7435d66cd16bb8ad778f53abcbb51e81a37628dd29a925208ce4550417d5` | `c911b762a97f355b2aad69a2ae474fff94d50f0a8f74efe61618d59cb4652a50` |
| `QM5_41162_ohlc-daily-squeeze-reversal-d1-opt` | `2e4ce023-1eaf-4a95-8952-1a47820c5c25` | `32ac75db71c957ea78fd65f34a3468f9241f91bc4a8ca05c1526b3b1fdcc1ccc` | `4f8b1b73d2ec4f028c3fc6481150e6bb96e61275d658b8e0ae985714c21265ae` |

The authority is exact-label-bound to those two EAs and grants no backtest or gate authority. `QM5_41163` remains under its separate router task and is not included.

## Verification

- Consolidated focused regression: `test_compile_work_items.py`, `test_dl089_matrix_service.py`, `test_terminal_worker_atomic_claim.py`, `test_opt_census.py`, `test_opt_census_select.py`, and `test_optimization_fork_driver.py` — **134 passed**.
- The matrix-service suite includes exact 1,085-cell materialization, the bounded eight-cell window, declaration binding, append-only recovery, released-hold lifecycle, and the failed-root/green-harness-successor case.
- Exact compile-authority tests passed for both the DL-089 dispatch repair and the independent `QM5_41163` repair authority; this task's authority remains limited to `QM5_41161` and `QM5_41162`.
- Python syntax compilation and `git diff --check` passed.

## Operational receipts

The controlled service apply produced the following durable state without invoking a router run, manually starting a terminal, or interrupting another backtest:

- Green fixture successor: `2dbc9f85-badd-4bf9-b607-e2655e9944b1`, `done / HARNESS_OK`; current 527-PASS fixture CSV SHA-256 `67ef8038e62e21c61b53452a20a53b3d05e661c8dc04682fc1f659529b0c3bfe`.
- GBPUSD Q02 prerequisite: `7cd3787a-39df-5ac2-8e7d-c2e29bd258bc`, `done / PASS`; summary SHA-256 `44f5317af20b664529dff59363ace55899f254481e4ecc2094ee4bd0f8f5446a`.
- EURUSD Q02 prerequisite: `77544e3e-93b8-5690-9cf9-a174b7db2091`, `done / PASS`; summary SHA-256 `6707903fa4d25dc0e0dd7b51d3ef6e0ba45acf478b3f9278d4060495db9a74cb`.
- GBPUSD runner registration: `D:/QM/strategy_farm/artifacts/opt_census/DL089_QM5_10706_GBPUSD_DWX_2019_2025/runner_registration.json`, SHA-256 `b6c887049231578e613a133f06e942a999a0bd27ce6924821c23eb9f54a30400`.
- GBPUSD sealed ledger: `D:/QM/strategy_farm/artifacts/opt_census/DL089_QM5_10706_GBPUSD_DWX_2019_2025/ledger.json`, SHA-256 at enqueue `3f3d666c5196eb244474bdfe5aa9c82505f50b84fdc2399ffd273f37764af145`; `inserted=1085`, `existing=0`, `priority_window=8`.
- Measurement binding: `QM5_41161`, binary SHA-256 `d96c7435d66cd16bb8ad778f53abcbb51e81a37628dd29a925208ce4550417d5`, source SHA-256 `59b67eb93b490c6c4a4614da7abd021830cff8d911e08c11913beb06fd31bdb4`, neutral base-set SHA-256 `f53bbda887c3be7118c83ee6292934984b37e97266aed6e8ebac300e76efa32d`.

The first genuine matrix measurements completed through the ordinary scheduled worker path:

| Cell work item | Cell key | Status/verdict | Exact window | Trades / PF / net / max DD | Summary SHA-256 | Cell-receipt SHA-256 |
|---|---|---|---|---|---|---|
| `066dd96a-0c3e-5626-a66f-8ad8799350a6` | `2019:baseline` | `done / MEASURED` | `2019.01.01–2019.12.31` | `37 / 1.14 / 3360.56 / 10001.29` | `45335c1e29e25b5bc14e99c7c767155a0eebe7dbdaec6bfab0fded9de361570e` | `68eddf9f6938c5585fb6fe6d2e1034290968ba1172d3ca854e0a380f4c54d763` |
| `8d194d9c-bb08-5031-80e2-d429a61c2aab` | `2019:buy_003` | `done / MEASURED` | `2019.01.01–2019.12.31` | `36 / 1.19 / 4386.55 / 8975.30` | `d14dccd7b9ae90a141082c53f286348a26fd703070c58818fa61243714568cb7` | `f41b5c5fdf507d2e669fa1e1b4e641d554b9050e81c7747ecabc1e02ad828c81` |

Both cell receipts reconcile their native closed trades. Their native report SHA-256 values are `96037368e95f035661f5795881be659bfcfda02abe45bf4de262da2cecaef00f` and `3d03da364d7653aed0763e055e1d1105e92f185680d10f671ae36e699d2fed4e`. The generated sets have `RISK_FIXED=1000`, `RISK_PERCENT=0`, exactly the declared pattern input selected for each arm, and the EA's fail-closed news maximum remains 336 hours. After each completion the rolling service replenished one slot, leaving exactly eight priority-tracked pending/active cells; the matrix snapshot was `measured=2`, `pending=1083`, `infra=0`.

Pair serialization remains active: EURUSD successor `c4bc189b-372d-54c9-be45-046ac77b245b` waits behind GBPUSD. Protected USDCAD row `f9e1f7fc-f92e-5399-9f7d-c7e83e940ce5` remains pending and unclaimed because `QM5_41163` has no `COMPILE_OK` receipt. Its original `Q12_DL089_RUNNER_MISMATCH_GUARD` hold is preserved, active, and converted to `release_on_restart=1`; no manual restart or unsafe release occurred.

The two invalid-for-matrix source receipts remain byte- and row-preserved as `done / PASS`, with their original evidence paths and `updated_at` values (`2026-08-26T10:27:49Z` and `2026-08-26T10:30:18Z`). No pipeline verdict was inferred from this recovery.

Implementation commits: `5475aed8e` (governed dispatch and recovery), `b50e32a13` (restart-hold lifecycle), and `0fada3647` (green harness-successor resolution).

## OWNER disposition-only template

This section is a template, not an executed action. Agents must not alter the two source rows or reinterpret their PASS verdicts.

```yaml
decision_type: DL089_INVALID_EXECUTION_RECEIPT_DISPOSITION
authority: OWNER_ONLY
source_work_item_ids:
  - dfca24fa-28df-5f5e-818f-8dcf53611822
  - d0e53004-659c-563c-8314-c24ad4ab2a68
finding: >-
  Each PASS proves only a repeated 2024 run_smoke/v2 execution and proves zero
  cells of the declared 1,085 annual + 4 walk-forward Q12 experiment.
recommended_disposition: ACKNOWLEDGE_INVALID_FOR_DECLARED_Q12
source_row_mutation: NONE
source_evidence_mutation: NONE
authorized_successors:
  - 1a92b33e-e34f-532e-80b3-e0144f3b3755
  - c4bc189b-372d-54c9-be45-046ac77b245b
owner_name: <OWNER>
owner_signed_at_utc: <timestamp>
owner_note: <optional>
```

No pipeline PASS, live deployment, T_Live, AutoTrading, or terminal-control action is authorized by this evidence.
