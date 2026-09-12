# Pending artifact binding drift — governed disposition

Date: 2026-09-12  
Router task: `5a6eea33-0cfc-430a-9f2f-33c446beb9ad`  
Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

## Result

The read-only census checked 518 hash-bound pending rows and found 63
`CONTENT_CHANGED` bindings on 33 preserved rows across 23 EAs. Every row now
has an exact disposition: 10 are canonically superseded and 27 have an active
hold with a concrete release condition; four rows are in both audit-preserving
categories. One current-identity successor was created. The QM5_10269 source
row is one of the 10 superseded rows and its successor is runnable.

No work-item status, verdict, or verdict evidence was overwritten. No terminal
was launched or interrupted, and no live or FTMO surface was touched.

The machine-readable row-level census is
`docs/ops/evidence/2026-09-12_pending_artifact_binding_census.json`.

## Dry-run and apply

All candidate Q02 rows were first evaluated with the default-read-only
`farmctl requalify-q02` path. Only `0be0a1d1` (QM5_10269) passed the complete
gate: current MQ5/EX5, COMPILE_EA receipt `3a92321c`, source-repair authority,
recoverable predecessor set bytes, parameter diff, and `RISK_FIXED=1000` /
`RISK_PERCENT=0`. Apply then atomically appended successor `127aab04`, wrote
the supersession edge, and emitted receipt:

`D:/QM/strategy_farm/artifacts/receipts/q02_post_binding_requalification/0be0a1d1-6aa2-4d1b-ae24-50a6c21b93a9_127aab04-5d60-4200-a573-3d3fb7287be6.json`

Receipt SHA-256: `e8a851e5f7f6af83927920928d67b22909fb18afdb4f34f831d1335fa9301060`.

The nine previously claimable rows were each planned with
`governed_work_item_hold.py plan` before apply. Apply used exact ID/symbol/EA/
phase predicates, a database backup per transaction, non-restart holds, and
readback proving `claimable=false`.

## Per-EA disposition

| EA | Rows / phase | Drift | Build decision | Durable disposition |
|---|---|---|---|---|
| QM5_10203 | `8abafefb` Q02 | mq5 | No current final compile receipt | Existing `ARTIFACT_BINDING_CONTENT_CHANGED` hold retained |
| QM5_20181 | `824ca951`, `a0d6400a` Q02 | mq5 + set | FTMO-only historical identities | Already superseded by `407f23c8`; FTMO hold retained; no FTMO action |
| QM5_10593 | `8084f025` Q04 | mq5 + set | COMPILE_OK exists, but changed build must restart at Q02 | Existing content-changed hold retained; no stale Q04 continuation |
| QM5_10649 | `c2ce418a` Q04 | ex5 + mq5 + set | No current final compile receipt | Existing content-changed hold retained |
| QM5_1443 | `48f156eb` Q04 | mq5 | No current final compile receipt | Existing content-changed hold retained |
| QM5_33007 | `8322d8c7` Q02 | ex5 + mq5 + set | Latest compile not COMPILE_OK; review failed | Existing `REVIEW_FAIL_PIPELINE_ENTRY_BLOCKED` hold retained |
| QM5_35004 | `869ea74a`, `87cbb87c`, `8d9f6d2a` Q02 | mq5 + set | Review not completed; no admitted final build | Existing review holds retained |
| QM5_35005 | `61f887b7`, `62156a75`, `ee0914f4` Q02 | mq5 + set | Compile exists but review not completed | Existing review holds retained |
| QM5_20096 | `256846e2` Q02 | ex5 + set | Economically retired identity | Already superseded by terminal `41a774ad` |
| QM5_10717 | `7dd70134` Q02 | ex5 + mq5 + set | Newer governed build exists | Already canonically superseded by prior operator record |
| QM5_10718 | `c65a8b39` Q03 | ex5 + mq5 + set | Current final compile; old Q02 chain invalid | Added `ARTIFACT_BINDING_Q02_REQUALIFICATION_REQUIRED` |
| QM5_10269 | `0be0a1d1` Q02 | ex5 + mq5 + set | Final governed build authenticated | Appended runnable Q02 `127aab04`; old row superseded |
| QM5_20143 | `8be76d81` Q02 | mq5 | COMPILE_EA `4144f8f2` still pending | Added `ARTIFACT_BINDING_REBUILD_IN_PROGRESS` |
| QM5_11421 | `f81a14df` Q14; `19761d0c`, `03392b1f`, `0840d7a5` Q12 | mq5 | Latest compile failed / matrix rollout incomplete | Q14 already superseded; rollout hold retained; rebuild holds added to two unheld Q12 rows |
| QM5_20202 | `cbfb5a62` Q03 | ex5 + mq5 + set | Current final compile; old Q02 chain invalid | Added `ARTIFACT_BINDING_Q02_REQUALIFICATION_REQUIRED` |
| QM5_20275 | `c5ff6aa2` Q03 | ex5 + mq5 + set | Current final compile; old Q02 chain invalid | Added `ARTIFACT_BINDING_Q02_REQUALIFICATION_REQUIRED` |
| QM5_10700 | `3815515b` Q07 | ex5 + mq5 + set | OWNER recompile decision outstanding | Existing `AWAITING_OWNER_RECOMPILE_DECISION` hold retained |
| QM5_10116 | `90f77b53`, `83ac79f0` Q02 | mq5 | Compile pending after magic-registry repair | Existing `COMPILED_MAGIC_REGISTRY_STALE` holds retained |
| QM5_41359 | `00cf2ac1` Q02 | ex5 + set | Final successor already created | Already superseded by `12184077` |
| QM5_41360 | `8f4c4610` Q02 | ex5 + set | Final successor already created | Already superseded by `bf0b4f12` |
| QM5_41361 | `ecc8e269` Q02 | ex5 + set | Final successor already created | Already superseded by `d56450a8` |
| QM5_41362 | `a126c45e` Q02 | ex5 + set | Compile exists, but source set bytes are unrecoverable | Added `ARTIFACT_BINDING_SOURCE_SET_UNRECOVERABLE` |
| QM5_10706 | `6d307198`, `cb81c67c` Q12 | set | No phase-specific current-identity matrix successor | Added `ARTIFACT_BINDING_SETFILE_SUCCESSOR_REQUIRED` |

## Verification

- Refreshed census: 518 checked, 33 preserved drift rows, 63 bindings, all
  `CONTENT_CHANGED`; 27 rows expose active holds directly in the census.
- Direct database readback: 9/9 newly protected targets have active holds and
  are unclaimable; `0be0a1d1 -> 127aab04` is recorded in
  `work_item_supersedes`.
- The 6 remaining rows without an active hold are all canonical
  supersessions. The health check intentionally continues to count preserved
  pending history because it does not filter `work_item_supersedes`; this
  artifact supplies the required complete reason classification without
  deleting or rewriting history.
