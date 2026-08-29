# PATH-TO-25 governed `_opt` sibling build evidence — 2026-08-29

Router task: `b91f5ffa-9a29-40a0-bfff-4000660560ef`  
Lane: Codex / board-advisor  
Outcome: **REVIEW — implementation and registry work complete; compile activation safely deferred**

## Scope

Create approved D1 pattern-permission siblings for the five DL-089 source rows selected by the routed task. This evidence records build facts only. It does not assert a pipeline verdict or authorize live use.

## Durable implementation

| Parent | Governed sibling | Target | Active magic | Build task |
|---|---|---|---:|---|
| `QM5_13054_brent-tom-mom` | `QM5_41194_brent-tom-mom-opt` | XTIUSD | 411940000 | `ec602ee9-27c3-41b3-b395-9a1eab845fef` |
| `QM5_1537_aa-vol-sma10` | `QM5_41195_aa-vol-sma10-opt` | XAGUSD | 411950000 | `5f813a36-e205-47ac-b3d2-fa21851f5cf7` |
| `QM5_21507_qs-kama-trend-xau` | `QM5_41196_qs-kama-trend-xau-opt` | XAUUSD | 411960000 | `70a134ea-144f-420f-9585-ad6d4c588320` |
| `QM5_11881_connors-rsi2-mean-reversion` | `QM5_41197_connors-rsi2-mean-reversion-opt` | GBPUSD | 411970000 | `ce702ad7-9cf9-4c1d-b3f7-1f30510d4114` |
| `QM5_20266_collins-66mom` | `QM5_41198_collins-66mom-opt` | XTIUSD | 411980000 | `084ae29d-4ecb-4dcf-829f-2ccfaec060a3` |

Atomic identity reservations are in commit `f696a7fce`. The five sources, D1 set files, active magic rows, resolver rows, and allocator receipts are in commit `eae4326c1`. Runtime approved cards are under `D:/QM/strategy_farm/artifacts/cards_approved/`; their `g0_authority` is this deterministic router task.

Each sibling retains the parent's mechanical signal and adds the standard EA-managed pattern-permission layer: six `opt_pp_*` inputs, `QM_PatternPermission.mqh`, D1 profile evaluation, initialization validation, and a fail-closed permission conjunction immediately before order submission. No ML, grid, martingale, HFT, or live-trading behavior was introduced.

## Verification completed

- `validate_build_guardrails.py` passed all five sources with zero findings. The news-staleness ceiling remains `336` hours.
- All five set files use `RISK_FIXED=1000` and `RISK_PERCENT=0` and contain the six neutral pattern inputs.
- DL-089 static pattern-measurement readiness classified all five siblings as `READY`, with no blockers.
- Governed magic allocation applied five of five rows; collision validation reported zero collisions and strict resolver generation retained the new rows.
- The atomic registry, magic allocation, and resolver evidence are committed. Detailed allocator receipts:
  - `docs/ops/evidence/2026-08-29_b91f5ffa_dl089_sibling_allocator_dry_run.json`
  - `docs/ops/evidence/2026-08-29_b91f5ffa_dl089_sibling_allocator_apply.json`

## Compile-control state

Compile enrollment was intentionally serialized. `QM5_41194_brent-tom-mom-opt` was enrolled as work item `518916d5-ff50-4724-8583-6a21d7b9ebe2` and remains `pending` under `COMPILE_EA_WORKER_ROLLOUT_PENDING`. The exact-item governed release dry-run passed and is preserved in `2026-08-29_b91f5ffa_QM5_41194_compile_release_dry_run.json`.

The apply invocation entered the required pre-mutation SQLite backup at 14:21:39 Europe/Berlin and made no progress for more than ten minutes while the scheduled farm pump/health and an active Q09 worker were using the control plane. Only that locally launched release process was stopped. The hold remains intact; no database mutation, worker interruption, terminal launch, gate bypass, or manual compile occurred.

To avoid multiplying held work while the writer/backup path was contended, `QM5_41195` through `QM5_41198` were not compile-enrolled. Consequently:

- none of the five may yet be described as `COMPILE_OK`;
- no `.ex5` acceptance claim is made;
- DL-089 matrices were not materialized and no Q-phase verdict is claimed;
- the build tasks and sources remain available for the normal governed compile/review continuation.

## Review disposition

The implementation portion is complete and reproducible, but the task's compiled-binary and pending-matrix acceptance criteria are not yet met. Resume through the canonical compile rollout writer when contention clears, serially verify all five `COMPILE_OK` receipts and guarded `.ex5` files, then allow the governed DL-089 service to materialize the five matrices. Do not bypass the activation hold or self-approve the resulting review work.
