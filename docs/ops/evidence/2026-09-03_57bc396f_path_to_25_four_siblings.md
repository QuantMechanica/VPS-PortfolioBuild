# PATH-TO-25 four-sibling governed build evidence — 2026-09-03

- Router task: `57bc396f-5ac3-4469-aec5-c47d3737b1fd`
- Lane: Codex / `agents/board-advisor`
- Disposition: **REVIEW — four fresh siblings are COMPILE_OK**
- Scope: Q01 build facts only. This document does not assert a Q-phase,
  economic, portfolio, deployment, or live-trading verdict.

## Outcome

Four OWNER-approved DL-089 `_opt` measurement siblings were reserved, built,
registered, compiled through the governed resident-worker path, and committed.
Every successful row has compiler `0 errors / 0 warnings`, build-check `PASS`,
and an EX5 whose bytes are bound to that row's receipt.

| Parent / carrier | Fresh sibling | Target / TF | Active magic | Build task opened | Successful compile row |
|---|---|---|---:|---|---|
| `QM5_13013_grimes-trendday-v2` | `QM5_41321_grimes-trendday-v2-opt` | `NDX.DWX / M15` | 413210000 | `1208ad50-495e-45cc-ae02-8a36de8d664e` | `aa5723c4-2c43-46ea-a948-cc887b7c8308` |
| `QM5_10403_et-turtle20x` | `QM5_41322_et-turtle20x-opt` | `XAUUSD.DWX / D1` | 413220000 | `c915e8d1-ed7d-48d5-bee1-45970a4a2c9c` | `e8747e70-d847-489a-bc07-7ab3bce7f6c2` |
| `QM5_11660_pp-wedge` | `QM5_41323_pp-wedge-opt` | `NDX.DWX / H4` | 413230000 | `386727c4-4a3a-4d40-aada-7be1a9ac7fb5` | `b447c827-f550-4761-86b1-2e83bae768e8` |
| `QM5_21501_balke-gmt3-range-breakout-ppcensus` | `QM5_41324_balke-gmt3-range-breakout-path25-opt` | `USDJPY.DWX / H1` | 413240000 | `1edb9118-6c79-4f83-b0cb-2a4469a8e2ec` | `f221b8aa-39ae-436e-be4e-5ae7da30958d` |

The four `build_ea` rows are durable CEO-review handoffs. At the final audit,
41322–41324 remained `pending`. The canonical service had changed 41321 to
`blocked` with `duplicate_build_task_existing_pipeline_work` after it detected
the already-created executable and one automatically seeded Q02 work item.
That post-build duplicate guard does not invalidate the build row or its
COMPILE_OK successor. No build result or smoke result was fabricated to force
a review transition; Claude retains authority to close `review_ea`.

## Per-pair mechanical diff summary

All four siblings retain their parent's signal, exit, sizing, news, and
Friday-close mechanics. Their common intentional delta is the established
DL-089 corset: exactly six neutral-by-default inputs (`opt_pp_buy1..3` and
`opt_pp_sell1..3`), a closed-D1 permission profile, fail-closed invalid-profile
handling, and `Pattern_AllowsRequest` immediately before every order consumer.

- `QM5_13013 -> QM5_41321`: identity/magic/target changed to the fresh NDX
  sibling; the common permission layer was added at its sole order site. The
  required Q08 MAE sampling call was added first in `OnTick` because the parent
  lacked it. The control-path D1 timestamp uses `QM_ReadBar`.
- `QM5_10403 -> QM5_41322`: identity/magic/target changed to the fresh XAUUSD
  sibling. The parent's hidden inline BUY leg and returned SELL leg are each
  independently permission-gated, preserving zero-default two-leg behavior.
  Framework-only repairs explicitly zero-initialize both requests and prove the
  percentile-buffer index against `ArraySize`; strategy thresholds are unchanged.
- `QM5_11660 -> QM5_41323`: identity/magic and the parent's portable carrier
  mapping were narrowed to the authorized NDX slot 0. The common permission
  layer gates its single order site. Existing bounded structural OHLC reads and
  wedge mechanics are unchanged.
- `QM5_21501 -> QM5_41324`: a fresh USDJPY identity was created rather than
  reusing an older census instrument. The parent's A1-safe, side-effect-free
  straddle plan remains intact, and the common permission function gates both
  BUY and SELL placements separately.

## Compile receipts and hashes

| EA | MQ5 SHA-256 | EX5 SHA-256 | Setfile SHA-256 | Receipt SHA-256 |
|---|---|---|---|---|
| `QM5_41321` | `53d8bec6387e2a904dbbfe68239e0653589878f5bf2b4dc73edd111b398438ba` | `8110960f4bb59b85328e02239e0ad19fd1c644ee87a1c0f9bf4faeb6a9b530ff` | `fa723090b4bd8c1c7ee54449a55db4f6412fe5227c9a147c9f0adc6ce98a4dc4` | `e37e37b9136d914281f0f169cdec74b558d67b9909ae4af5317712b742a58f2d` |
| `QM5_41322` | `2346ee38d37d941c92af85e47b35206896b33c34fc19f72dbac95854e668de61` | `3305f3dca0c4c1c219ed0a10cda4cf7d493fb8e7ddc63ff7f9813dfd6d58c8d7` | `7ecad12fc369692ea4eb83165a0131aa5547221824510093cf3527f9610a25d0` | `2e1d800e8fdc14496173ab774a96998267d5a507f1f96599d313b07c45eda7aa` |
| `QM5_41323` | `9c5972ffe5a22c82400265ab40a4924ccfc25cb4b3799bfe333151c092bddbd4` | `032e7a90a106be66b378c09465804dc556f59b08c0ff84bb84455a904d722897` | `e015af5878f1325cfa93e0bc397e28e5f86b31cdc27c370bed59477f18637562` | `4e27b2cb22db154ba43e6690593dab975918654a70a97597a66912d2db409aa3` |
| `QM5_41324` | `62b2b66500485f7a42d3a3e08fa22347c6a8c6ecdeab71a453f0e64f24e49910` | `1df743b2ece87f7d0dcaefb66c750462224aeeaaf8da6ae70bbc1e080e9a10fa` | `32243fd4a2a4c7c4a84d9f0dc6f1cdae66c95216e62f5f21f9b838b972014884` | `d390a7060350bb216590a44aff754527be9a98959a65861ef62cacae24a53cdb` |

Canonical successful evidence:

- `D:/QM/reports/work_items/aa5723c4-2c43-46ea-a948-cc887b7c8308/QM5_41321/COMPILE_EA/compile_evidence.json`
- `D:/QM/reports/work_items/e8747e70-d847-489a-bc07-7ab3bce7f6c2/QM5_41322/COMPILE_EA/compile_evidence.json`
- `D:/QM/reports/work_items/b447c827-f550-4761-86b1-2e83bae768e8/QM5_41323/COMPILE_EA/compile_evidence.json`
- `D:/QM/reports/work_items/f221b8aa-39ae-436e-be4e-5ae7da30958d/QM5_41324/COMPILE_EA/compile_evidence.json`

The immutable attempt ledger is preserved. 41321 first failed only
`EA_FRAMEWORK_RAW_SERIES_CALL` in row
`fd0f765e-52a4-4b37-9dbe-27330c986e10`; its append-only successor passed.
41322 first failed request-initialization and buffer-bound checks in
`fec74bf1-a98e-42ac-bb0a-325b786db349`, then the scanner required a direct
`ArraySize` expression in `f875d3a6-7ab2-4b48-9e22-e0bf575ee05d`; the next
append-only successor passed. No failed row was rewritten.

## Registry, cards, and verification

- IDs 41321–41324 were atomically reserved in `ae0e6a84d9`.
- Governed magic allocation added four active rows with zero collisions and
  regenerated a strict 18,090-row resolver. Receipts:
  - `docs/ops/evidence/2026-09-03_57bc396f_dl089_sibling_allocator_dry_run.json`
  - `docs/ops/evidence/2026-09-03_57bc396f_dl089_sibling_allocator_apply.json`
- Each EA-local `docs/strategy_card.md` is byte-identical to its approved
  `D:/QM/strategy_farm/artifacts/cards_approved/` copy. All carry
  `g0_status: APPROVED`, `parent_ea_id`, the exact `Target symbols:` line, and
  an inherited expected-trade estimate.
- All four SPEC validators pass.
- `validate_build_guardrails.py` passes all four directories with zero
  findings and a 336-hour news-staleness ceiling.
- `test_pattern_permission_framework_wiring.py`: `5 passed`.
- Every bound backtest set has `RISK_FIXED=1000`, `RISK_PERCENT=0`, the six
  zero-default permission inputs, and the governed build hash added only by
  the compile worker.

Task commits, all made with explicit task pathspecs on
`agents/board-advisor`: `9e8a5db32e`, `5dbf319c11`, `e8492834b3`,
`c10213e1ee`, `9b84ae1426`, `9c0a9d8c37`, `e2331b09b8`, `2dfa50c160`,
`cba3d96cbb`, and `2ec12b176e` (plus registry reservation `ae0e6a84d9`).

## Boundary observations

The scheduled matrix service independently created and completed Q02 row
`95e706ea-531c-504b-ae46-4e16f7d79134` for 41321 while this build cycle was
closing. That observed `PASS` is not produced or interpreted here. No router
selection command, manual terminal launch, backtest start/interruption,
AutoTrading change, T_Live action, or pipeline verdict was performed.
