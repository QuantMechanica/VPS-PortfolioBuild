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

The repair adds three fail-closed boundaries:

1. Generic claim SQL excludes governed analytic declarations and every `dl089-annual-wf-cells-v1` row. A targeted generic claim also returns `governed_analytic_dispatch_required` without mutating the row.
2. `dl089_matrix_service.py` validates the sealed declaration hashes and exact UUIDs, discovers the unique approved instrumented `_opt` sibling, binds current source/binary/compile evidence, writes an immutable neutral fixed-risk measurement set, seeds its Q02 prerequisite, and materializes the exact 1,085 declared annual cells. It services only one EA/symbol pair at once and keeps exactly eight pending cells priority-tracked.
3. Q12 can close only after all materialized cells have `done / MEASURED` evidence and the sealed walk-forward selector reaches a terminal pattern state. The runner never converts a smoke summary into a Q12 verdict.

The neutral measurement set is generated under `D:/QM/strategy_farm/artifacts/opt_census/`; it forces all six `opt_pp_*` inputs to `0` without editing concurrently owned EA setfiles. It enforces `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and rejects `qm_news_stale_max_hours > 336`.

The original protection hold on pending row `f9e1f7fc-f92e-5399-9f7d-c7e83e940ce5` is converted in place to `release_on_restart=1`. This preserves its one-slot hold history while ensuring old resident workers cannot claim it. After a normal governed worker restart loads the hard claim guard, the hold may release safely; the row remains fail-closed behind the current `QM5_41163` compile prerequisite. No worker or terminal was restarted manually.

## Compile binding

The initial `QM5_41161` and `QM5_41162` compile receipts predated the final normalized source bytes. Two append-only, source-hash-bound compile successors were admitted under the exact router-task/EA allowlist:

| Measurement EA | Governed compile successor |
|---|---|
| `QM5_41161_tv-mon-ls-opt` | `c29b6c89-45d3-4139-912e-2e2e49f1a470` |
| `QM5_41162_ohlc-daily-squeeze-reversal-d1-opt` | `2e4ce023-1eaf-4a95-8952-1a47820c5c25` |

The authority is exact-label-bound to those two EAs and grants no backtest or gate authority. `QM5_41163` remains under its separate router task and is not included.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q` — 70 passed.
- `python -m pytest tools/strategy_farm/tests/test_opt_census_dispatch.py tools/strategy_farm/tests/test_opt_census_select.py tools/strategy_farm/tests/test_optimization_fork_driver.py -q` — 42 passed.
- `python -m pytest tools/strategy_farm/tests/test_dl089_matrix_service.py -q` — 2 passed; verifies exact 1,085-cell materialization, eight-cell window, declaration binding, and immutable successor behavior.
- Exact compile-authority tests — passed for both the DL-089 dispatch repair and the independent `QM5_41163` repair authority.
- Python syntax compilation and `git diff --check` — passed.

Operational successor, Q02, registration, and first-cell receipts are recorded below after the controlled apply.

## Operational receipts

Pending controlled apply.

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
