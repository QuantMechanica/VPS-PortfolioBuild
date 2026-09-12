# Q09 sealed-plan hold binder — 2026-09-12

Task: `b982a763-925a-46d1-9414-825f18ab26f8`  
Disposition: **REVIEW**  
Authority: task-scoped repair; no pipeline verdict authority

## Result

The read-only census reproduced all 30 pending `Q10_NEWS` rows with the active
`Q09_AWAITING_SEALED_PLAN` hold. The deterministic binder authenticated an exact
completed Q09 PASS execution anchor, authored and hash-bound an immutable
`q09-news-run-plan/v2`, and used `q09_news_schema.release_plan_bound_hold` for
28 rows. It did not edit any historical row or verdict.

Post-apply verification authenticated every one of the 28 plan/anchor bundles
against the live database and current files. All 28 rows are pending, unclaimed,
`RUNNABLE_BOUND`, `terminal_claimable=true`, and have zero active holds, so they
now enter only through the ordinary worker claim predicate. Two rows remain
held because no defensible execution anchor exists.

Dry-run receipt: `docs/ops/evidence/2026-09-12_q09_pass_anchor_plan.json`  
Apply receipt: `docs/ops/evidence/2026-09-12_q09_pass_anchor_apply.json`

## Cause table and affected IDs

| Recorded group | Count | Reproduced root cause | Disposition |
|---|---:|---|---|
| `Q09_AUTOSEAL_DERIVE_LINEAGE_FAILED` | 16 | The Q10 row retained the exact Q09 PASS parent, but legacy autoseal tried to derive Q08/Q07 lineage from a Q10 grid/ablation setfile and rejected the different dependency setfile identity. | 16 bound to their exact Q09 PASS parents. |
| `Q09_AUTOSEAL_VALIDATE_Q08_VINTAGE_FAILED` | 6 | Retained Q08 provenance was incomplete or no longer satisfied the current Q07/vintage closure. The exact completed Q09 PASS run still authenticated current EX5, exact setfile, period, and history. | 6 bound to exact Q09 PASS execution anchors. |
| `Q09_AUTOSEAL_BIND_PLAN_FAILED` | 8 | Six rows had usable exact Q09 PASS evidence despite missing legacy Q07 binding; one basket row required the authenticated logical-symbol/host-symbol distinction; two lacked internally consistent evidence. | 6 bound; 2 remain held. |

`Q09_AUTOSEAL_DERIVE_LINEAGE_FAILED` (16):

`70171429-8d84-49bd-8082-7034c924dbf4`, `e8ec3223-886a-400b-ba1b-096a82cebd9f`,
`cec67ad5-2ca5-4d84-b347-a0c370415329`, `58ae0036-5bc4-4711-8bfa-eb3465af298b`,
`9f691044-d481-4f69-8823-267d80fff89d`, `9b69d492-82df-4703-9350-fea30afac98f`,
`f3f1cedc-c0d6-4485-917c-7f3b98957453`, `15e7deca-13e8-4760-9e8e-5918040f948d`,
`42c8debd-ca2a-4618-8aaf-b9c3ee379f61`, `a8e36fba-36e7-419a-9d2b-5b3116cbdde2`,
`120d68ff-bf61-4b16-abf8-1867aee53bb3`, `60ce66e6-8c40-493a-aa8f-40c8714a3e85`,
`bd840961-23a1-4fea-99ce-2e24d0f1ca78`, `9d3f470e-5071-4398-86c7-7de4be979c3d`,
`d3312a9e-038a-4ab8-b392-0dbdfa2728e0`, `1d9a2d26-4407-4554-acbb-4e4c258f0b04`.

`Q09_AUTOSEAL_VALIDATE_Q08_VINTAGE_FAILED` (6):

`d81d9ea8-b802-4c38-8fc9-8bdbab6ef75c`, `0f7f63e4-9244-4c60-8610-ea068c5fc64e`,
`fb127697-b89e-4d52-9bd5-0d92d95e9125`, `10449264-8fa1-47f5-a3d7-adb28cee934d`,
`83826f05-3d85-4cac-8177-e3f7cd25c7e8`, `b6bdac29-b608-4016-9394-2be6f34cc9a3`.

`Q09_AUTOSEAL_BIND_PLAN_FAILED` (8):

`08fe4173-07d9-47e1-97e9-a76b1159ad94`, `84608819-5253-4df0-871c-6eb4750c3435`,
`72992810-aaf1-4fa8-9c12-c778bda0ae87`, `2641d5cf-6e1c-43d1-92b2-05c9d6f54d82`,
`9a85fb74-4c31-4a74-8e8c-c332cf1b802e`, `bb02b701-0d7c-4de7-82b2-87d917f8dd1b`,
`8b233bbf-4ed6-4c27-a3d2-5e940c9248ab`, `e0cbdd1a-1cfe-4bbe-8ebe-a4b4c26d151f`.

## Preserved holds

- `08fe4173-07d9-47e1-97e9-a76b1159ad94` (`QM5_11476`, `USDJPY.DWX`): no exact
  completed Q09 PASS source exists. Manufacturing a substitute would weaken the claim gate.
- `8b233bbf-4ed6-4c27-a3d2-5e940c9248ab` (`QM5_10148`, `EURNZD.DWX`): the Q09
  database verdict is PASS while its bound summary result is FAIL. The binder fails closed on
  this evidence contradiction.

The basket row `84608819-5253-4df0-871c-6eb4750c3435` is not an exception to
identity checking: both rows bind logical symbol `QM5_12831_XTI_AUDUSD_BRK_D1`,
the same basket manifest and ordered members, and host/execution symbol
`XTIUSD.DWX`. The anchor records both logical and execution symbols and the
runtime validator checks each in its proper domain.

## Verification

- Dry run: 30 total / 28 ready / 2 held / 0 applied.
- Apply: 28 applied / 28 hold releases / 1,120 planned Model-4 cells.
- Post-apply: 28 authenticated; 28 pending and unclaimed; zero active holds.
- Focused suite: **117 passed** (`test_q09_pass_anchor_binder`, scoped-anchor,
  farmctl integration, Q09 contract/runner/schema, and autoseal census tests).
- The binder is read-only unless `--apply` is explicit and uses one immediate
  transaction per row. Historical evidence and verdicts are immutable inputs.

