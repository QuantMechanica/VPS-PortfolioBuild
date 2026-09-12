# Q08 trailing-7d INVALID cause audit and claim preflight

- Router task: `c955da7f-b83e-4e31-a9bd-17ca6bcf8450`
- Observation cutoff: `2026-09-05T05:27:34Z`
- Authoritative DB: `D:/QM/strategy_farm/state/farm_state.sqlite`
- Branch: `agents/board-advisor`
- Scope: Q08 evidence/dispatch only. No stored verdict, pipeline evidence,
  terminal process, `T_Live`, FTMO, AutoTrading, or running backtest changed.

## Result

The live window advanced from the ticket's 25/53 snapshot to 26/54 while this
audit ran. All 26 aggregate files exist and are readable; this is not a missing
aggregate-publication incident. The dominant systemic cause is that Q08 was
allowed to claim and run after the claim-time DSR V2 producer had explicitly
recorded `dsr_context_status=UNAVAILABLE`. That affected 24/26 rows and spent a
real-tick slot even though sub-gate 8.2 could only return
`DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT`.

The fix adds a default-OFF claim preflight in
`tools/strategy_farm/terminal_worker.py`. When both `QM_DSR_V2=1` and
`QM_Q08_DSR_CONTEXT_PREFLIGHT=1` are present, a Q08 candidate is claimable only
after `dsr_cohort.attach()` returns a hash-bound `SEALED` context. An
unavailable candidate remains pending and is reconsidered by the ordinary
claim predicate. No hold is inserted or hand-released, so a later approved
card/ledger repair makes the row claimable without state surgery. Running
workers remain unchanged; only the orchestrator may activate the flag through
an idle-only staggered reload.

## Cause census

Classes overlap because one aggregate can contain several INVALID sub-gates.

| Cause | Rows | Disposition |
|---|---:|---|
| DSR context unavailable at claim | 24 | Dispatch defect fixed forward-only by the default-OFF preflight. The underlying missing declaration/card/ledger remains fail-closed and requires its ordinary governed source repair. |
| Historical baseline set has zero `strategy_*` assignments | 9 | Deterministic set-generation artifact defect, not transient infra. Producer guard was already fixed in `e3e1329445`; rerun only with an approved replacement set and otherwise-valid DSR context. |
| Authenticated neighborhood run has zero valid perturbations because all variants ended `ONINIT_FAILED/BARS_ZERO` | 7 | The artifact is present and bound. This is a strategy/parameter-support could-not-compute result, not transport infra; no automatic rerun. |
| DSR single-config EA label mismatch | 1 | Code defect already fixed by `866e3f2d78`/`a430c1aeda`; append-only successor `89ea5894` completed Q08 `FAIL_SOFT`. |
| Insufficient trade sample at another Q08 sub-gate | 2 | Merit-adjacent could-not-compute, not infra; no automatic rerun. |

## Row inventory

`verdict_reason` is copied from the work-item payload. Every evidence path was
read during classification.

| Work item | EA / symbol | `verdict_reason` | DSR context producer reason | Evidence path |
|---|---|---|---|---|
| `b280892a-18ec-4375-841e-eb360aba5ee1` | QM5_11196 / XAUUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:baseline_setfile_defect:empty_strategy_params` | none (pre-DSR attach) | `D:/QM/reports/work_items/b280892a-18ec-4375-841e-eb360aba5ee1/QM5_11196/Q08/XAUUSD_DWX/aggregate.json` |
| `60f98a58-5f06-4862-8908-16a8efe8332e` | QM5_11015 / EURUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:baseline_setfile_defect:empty_strategy_params` | none (pre-DSR attach) | `D:/QM/reports/work_items/60f98a58-5f06-4862-8908-16a8efe8332e/QM5_11015/Q08/EURUSD_DWX/aggregate.json` |
| `d7ab61ae-c7eb-400c-81d3-94b30a1a74e2` | QM5_11167 / XAUUSD.DWX | `q08_8.2_dsr_mc_fdr:DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT` | `SEALED_SEARCH_LEDGER_UNAVAILABLE` | `D:/QM/reports/work_items/d7ab61ae-c7eb-400c-81d3-94b30a1a74e2/QM5_11167/Q08/XAUUSD_DWX/aggregate.json` |
| `8bc2062b-fc1c-4b89-9bb6-f6130f5e7377` | QM5_12935 / XAUUSD.DWX | `q08_8.2_dsr_mc_fdr:DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT` | `SINGLE_CONFIGURATION_UNAVAILABLE:EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` | `D:/QM/reports/work_items/8bc2062b-fc1c-4b89-9bb6-f6130f5e7377/QM5_12935/Q08/XAUUSD_DWX/aggregate.json` |
| `906b7644-c9ce-4b4c-925a-a11054a95226` | QM5_11179 / XAUUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:baseline_setfile_defect:empty_strategy_params` | `CANDIDATE_WINDOW_UNAVAILABLE` | `D:/QM/reports/work_items/906b7644-c9ce-4b4c-925a-a11054a95226/QM5_11179/Q08/XAUUSD_DWX/aggregate.json` |
| `045bed75-f005-4787-bde2-05a00b658054` | QM5_11167 / XAUUSD.DWX | `q08_8.2_dsr_mc_fdr:DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT` | `CANDIDATE_WINDOW_UNAVAILABLE` | `D:/QM/reports/work_items/045bed75-f005-4787-bde2-05a00b658054/QM5_11167/Q08/XAUUSD_DWX/aggregate.json` |
| `a79887e3-7f60-40f6-a2a8-0d7785acf400` | QM5_11196 / XAUUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:baseline_setfile_defect:empty_strategy_params` | `CANDIDATE_WINDOW_UNAVAILABLE` | `D:/QM/reports/work_items/a79887e3-7f60-40f6-a2a8-0d7785acf400/QM5_11196/Q08/XAUUSD_DWX/aggregate.json` |
| `19c9df13-f81e-473e-9ebc-dc045b03dd1b` | QM5_11167 / XAUUSD.DWX | `q08_8.2_dsr_mc_fdr:DSR_V2_SINGLE_CONFIG_CANDIDATE_MISMATCH` | sealed; evaluator identity mismatch | `D:/QM/reports/work_items/19c9df13-f81e-473e-9ebc-dc045b03dd1b/QM5_11167/Q08/XAUUSD_DWX/aggregate.json` |
| `2cdb6a16-de65-4ef8-91aa-e45ba4d0704a` | QM5_10928 / XAUUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:baseline_setfile_defect:empty_strategy_params` | `SINGLE_CONFIGURATION_UNAVAILABLE:EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` | `D:/QM/reports/work_items/2cdb6a16-de65-4ef8-91aa-e45ba4d0704a/QM5_10928/Q08/XAUUSD_DWX/aggregate.json` |
| `d8abafc0-67ea-43dc-998e-d5cca4503692` | QM5_20072 / EURJPY.DWX | `q08_8.2_dsr_mc_fdr:DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT` | `SINGLE_CONFIGURATION_UNAVAILABLE:EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` | `D:/QM/reports/work_items/d8abafc0-67ea-43dc-998e-d5cca4503692/QM5_20072/Q08/EURJPY_DWX/aggregate.json` |
| `9a4cbb43-9eb0-43b1-94b6-311a5ce9dcf6` | QM5_41115 / XTIUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:evidence_status_missing_or_invalid` | approved card missing | `D:/QM/reports/work_items/9a4cbb43-9eb0-43b1-94b6-311a5ce9dcf6/QM5_41115/Q08/XTIUSD_DWX/aggregate.json` |
| `ba9aaa36-ff00-4099-be42-2c5473325926` | QM5_10163 / USDJPY.DWX | `q08_8.2_dsr_mc_fdr:DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT` | `SINGLE_CONFIGURATION_UNAVAILABLE:EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` | `D:/QM/reports/work_items/ba9aaa36-ff00-4099-be42-2c5473325926/QM5_10163/Q08/USDJPY_DWX/aggregate.json` |
| `ed38c5b7-cf11-4591-897f-e2aec1e6a1d8` | QM5_41158 / XTIUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:evidence_status_missing_or_invalid` | approved card missing | `D:/QM/reports/work_items/ed38c5b7-cf11-4591-897f-e2aec1e6a1d8/QM5_41158/Q08/XTIUSD_DWX/aggregate.json` |
| `f9d5b1ec-c350-4214-9a7c-be1a43a0d993` | QM5_41380 / XTIUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:evidence_status_missing_or_invalid` | approved card missing | `D:/QM/reports/work_items/f9d5b1ec-c350-4214-9a7c-be1a43a0d993/QM5_41380/Q08/XTIUSD_DWX/aggregate.json` |
| `68ef5618-7fba-47d7-a6ce-509429abbdee` | QM5_12925 / USDJPY.DWX | `q08_8.2_dsr_mc_fdr:DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT` | `SINGLE_CONFIGURATION_UNAVAILABLE:EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` | `D:/QM/reports/work_items/68ef5618-7fba-47d7-a6ce-509429abbdee/QM5_12925/Q08/USDJPY_DWX/aggregate.json` |
| `07d14cb3-d786-410b-97b3-9bd5d6da1e2e` | QM5_41176 / XTIUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:evidence_status_missing_or_invalid` | approved card missing | `D:/QM/reports/work_items/07d14cb3-d786-410b-97b3-9bd5d6da1e2e/QM5_41176/Q08/XTIUSD_DWX/aggregate.json` |
| `3fa17615-6fac-4c8b-a958-b02d111c9e4b` | QM5_41131 / XTIUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:evidence_status_missing_or_invalid` | approved card missing | `D:/QM/reports/work_items/3fa17615-6fac-4c8b-a958-b02d111c9e4b/QM5_41131/Q08/XTIUSD_DWX/aggregate.json` |
| `48c5d851-995d-4f86-99c8-fd720a8356af` | QM5_41381 / XTIUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:evidence_status_missing_or_invalid` | approved card missing | `D:/QM/reports/work_items/48c5d851-995d-4f86-99c8-fd720a8356af/QM5_41381/Q08/XTIUSD_DWX/aggregate.json` |
| `bea72ee4-cdfb-41d8-9200-aabcbe1e4aab` | QM5_41423 / XTIUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:evidence_status_missing_or_invalid` | approved card missing | `D:/QM/reports/work_items/bea72ee4-cdfb-41d8-9200-aabcbe1e4aab/QM5_41423/Q08/XTIUSD_DWX/aggregate.json` |
| `9ece92de-94e0-4e34-88a5-b36819283406` | QM5_9724 / XAUUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:baseline_setfile_defect:empty_strategy_params` | `SINGLE_CONFIGURATION_UNAVAILABLE:EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` | `D:/QM/reports/work_items/9ece92de-94e0-4e34-88a5-b36819283406/QM5_9724/Q08/XAUUSD_DWX/aggregate.json` |
| `712f20d3-15fa-42b4-abd4-b59498a1fd83` | QM5_11179 / XAUUSD.DWX | `q08_8.2_dsr_mc_fdr:DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT` | `SINGLE_CONFIGURATION_UNAVAILABLE:EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` | `D:/QM/reports/work_items/712f20d3-15fa-42b4-abd4-b59498a1fd83/QM5_11179/Q08/XAUUSD_DWX/aggregate.json` |
| `94a492b2-7093-428a-98b0-0d495b1eccba` | QM5_10928 / XAUUSD.DWX | `q08_8.2_dsr_mc_fdr:DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT` | `SINGLE_CONFIGURATION_UNAVAILABLE:EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` | `D:/QM/reports/work_items/94a492b2-7093-428a-98b0-0d495b1eccba/QM5_10928/Q08/XAUUSD_DWX/aggregate.json` |
| `d412ee43-32cb-4ce4-86cd-2d3c346e439b` | QM5_12548 / XAUUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:baseline_setfile_defect:empty_strategy_params` | `SINGLE_CONFIGURATION_UNAVAILABLE:EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` | `D:/QM/reports/work_items/d412ee43-32cb-4ce4-86cd-2d3c346e439b/QM5_12548/Q08/XAUUSD_DWX/aggregate.json` |
| `bae7cf06-c75b-4a7c-85f1-8903c985c686` | QM5_10163 / USDJPY.DWX | `q08_8.2_dsr_mc_fdr:DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT` | `SINGLE_CONFIGURATION_UNAVAILABLE:EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` | `D:/QM/reports/work_items/bae7cf06-c75b-4a7c-85f1-8903c985c686/QM5_10163/Q08/USDJPY_DWX/aggregate.json` |
| `910ecfea-c90c-4cc3-b957-6e6e2164e8a7` | QM5_12115 / XAUUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:baseline_setfile_defect:empty_strategy_params` | approved card missing | `D:/QM/reports/work_items/910ecfea-c90c-4cc3-b957-6e6e2164e8a7/QM5_12115/Q08/XAUUSD_DWX/aggregate.json` |
| `ed1799b2-2a6f-4a56-9f4d-4ad7b2aa2be8` | QM5_10412 / XAUUSD.DWX | `q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:baseline_setfile_defect:empty_strategy_params` | `SINGLE_CONFIGURATION_UNAVAILABLE:EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` | `D:/QM/reports/work_items/ed1799b2-2a6f-4a56-9f4d-4ad7b2aa2be8/QM5_10412/Q08/XAUUSD_DWX/aggregate.json` |

## Append-only rerun decision

The read-only successor census found one genuine code/evidence-contract row:
`19c9df13` (numeric-versus-`QM5_` identity). It already has the append-only
successor `89ea5894-2ce5-4c11-80db-a841baef9e7b`, which completed Q08
`FAIL_SOFT` after the identity fix. Creating another row would be a duplicate.

No new rerun was enqueued:

- unavailable DSR contexts need their named declaration/card/ledger repair;
- zero-parameter baselines need a governed replacement set and a sealable DSR
  context;
- the seven neighborhood artifacts record real attempted perturbations and
  deterministic initialization failures; and
- the two thin samples cannot be repaired by retrying identical inputs.

This is an append-only count of `created=0`, `already_repaired=1`,
`governance_or_artifact_blocked=18`, and `authenticated_noninfra=7`. Historical
INVALID evidence remains untouched.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q`
  -> `102 passed`.
- `python -m pytest tools/strategy_farm/tests/test_dsr_single_configuration.py tools/strategy_farm/tests/test_dsr_v2.py tools/strategy_farm/tests/test_dsr_cohort.py -q`
  -> `63 passed`.
- `python -m py_compile tools/strategy_farm/terminal_worker.py` -> PASS.
- Scoped `git diff --check` -> PASS (line-ending warnings only).
