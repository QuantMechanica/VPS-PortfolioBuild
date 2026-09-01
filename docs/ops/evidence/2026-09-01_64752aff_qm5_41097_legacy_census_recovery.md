# QM5_41097 legacy DL-089 census recovery — REVIEW handoff

- Task: `64752aff-f026-45c0-961a-5cc618a01ceb`
- OWNER subject line: `QM5_13213` / `USDJPY.DWX`
- Measurement EA: `QM5_41097_balke-gmt3-range-breakout-opt`
- Program: `DL089_QM5_41097_USDJPY_DWX_2019_2025`
- Applied: `2026-09-01T17:36:40.685968+00:00`
- Verdict: **PASS — the exact legacy universe is Q12-bound and all 599 untouched cells are governed/claimable; 486 completed measurements are valid and unchanged. Q12 remains held for independent review, so no selection/driver advance has run.**

## What was missing and what was added

The eight already sealed DL-089 programs carry a Q12 PATTERN work item, a SHA-bound `pattern_filter_sweep` declaration, a sealed ledger below `artifacts/opt_census`, and a matrix-runner registration/driver path. The pre-enforcement QM5_41097 program had none of those: its source ledger had `q12_work_item_id=None`, no declaration hash, no runner revision, and no driver. Consequently `_is_governed_dl089_census_payload` rejected all remaining cells.

The recovery appended:

- Q12 work item `2ea9cd64-2f17-5444-bcff-ad50f4481831`, subject `QM5_13213`, role `PATTERN`, current gate manifest `v4`;
- declaration SHA-256 `0396ccf089d8d7b38b1c76eec082bdef46632b4cf872c778296b18f111b9638d`;
- sealed ledger `D:\QM\strategy_farm\artifacts\opt_census\DL089_QM5_41097_USDJPY_DWX_2019_2025\ledger.json`, SHA-256 `a5e2cdb88456f75b66233a183380be2b6a107bb865273c57bbf94935c8e40329`;
- runner registration SHA-256 `00cc3f4895ca04dd030fa95e726a780f680b8052dbfd6e8e95753f109f745b55`;
- initialized driver state `ENQUEUED`, with zero transitions;
- an active `Q12_LEGACY_CENSUS_RECOVERY_REVIEW_PENDING` hold.

The Q12 row uses the current `v4` gate-manifest storage contract while the sealed economic rule remains the DL-089 V3 decision/plan. Existing census rows retain their immutable `gate_contract_version=legacy`; the live append-only trigger correctly forbids relabeling historical storage provenance. Governance comes from the new Q12/declaration bindings in each still-open payload.

## Candidate-universe and source-ledger preservation

The source ledger remains at:

`D:\QM\strategy_farm\opt_census\QM5_41097_USDJPY\ledger.json`

Its before/after SHA-256 is unchanged:

`eb4a981fc42f60f53947024fd591dea0ef6813ca50cc95e0eb17a03ae01c7943`

An exact-byte evidence copy with the same SHA is stored as `legacy_source_ledger.json` under the sealed program directory. The generated declaration was compared field-for-field against all 1,085 legacy cells (`work_item_id`, `cell_key`, year/window, arm, direction, predicate). No UUID, candidate, year, selection threshold, or gate criterion changed.

The recovered neutral base setfile was derived from the existing 2019 baseline cell, not from a new economic configuration. It is SHA-bound as `c42828e18475249a221d66665c4c39f12bcfb5dfefdf9fab0b742804efb470eb`; it has all six pattern inputs at zero, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and no news-staleness ceiling above 336.

## Completed-cell validity assessment

All **486/486** completed rows passed the adoption audit:

- row scope, setfile path, annual dates, source SHA `8e5cfdbf6f513bdbfd5fdcd25357907cad124497123b8a1abe133c9f2d1d6329`, EX5 SHA `e077660cc9ac5d74a6edc8896b72249f221fb030279bbd022f7e9d7756bb3a2e`, and per-cell setfile SHA match;
- every summary binds stable source/binary/setfile execution identity and contains at least one successful real-tick MT5 attempt;
- news evidence is `OK` with `max_age_hours <= 336`, and no summary reports a log bomb;
- 481 summaries succeeded on one attempt; five contain one invalid harness attempt followed by a valid real-tick attempt;
- 87 early payloads predate the payload-level `artifact_identity` object, but their immutable storage columns and native summaries provide the same exact binding.

No completed row required re-enqueue. Append-only re-enqueue cost: **0 backtests**.

The completed-row digest, including status, verdict, payload, evidence path, provenance columns, and timestamp, was identical across the transaction:

`84fca9a845127b78c8bb830b0e2458a1071893d8126831be7af17a3e86c2bcba`

The adoption manifest is `legacy_done_adoption.json`, SHA-256 `9ebf508f069007e7a06e76f279f94ea5ad8db5f1717e1808d1a5e1f9a915d3c6`.

## Pending-only guarded repair

One `BEGIN IMMEDIATE` transaction repaired exactly **599** rows. Every update required:

`status='pending' AND claimed_by IS NULL AND verdict IS NULL AND parent_task_id IS NULL AND payload_json=<byte-identical preimage>`

Results:

- `pending_rows_repaired=599`
- `governed_pending_rows=599`
- `verdict_rows_touched=0`
- `q12_rows_inserted=1`
- `review_holds_inserted=1`

Each open row now binds the Q12 ID, declaration SHA, sealed ledger, runner revision, source/EX5/setfile hashes, symbol, H1 period, and exact annual dates. A production lane preflight on frontier cell `dd25453f-6792-591f-97f2-6589a68e61de` returned `status=checked`, `candidate_pending=true`, program/arm `DL089_QM5_41097_USDJPY_DWX_2019_2025/baseline`, and a valid predecessor fingerprint. At the checkpoint there were 155 authenticated pending arm frontiers and all 599 payloads satisfied `_is_governed_dl089_census_payload`.

No MT5 process was launched by this ticket. No active T1–T10 run was stopped or modified. The active Q12 review hold blocks the full matrix service/selector; annual workers may consume governed frontiers, but selector advance requires a separate reviewed hold-release ceremony.

## Q04 diagnosis

Q04 row `dba6365b-14cf-49d2-a0e1-af534baf4b17` is not technically stuck:

- pending, unclaimed, null verdict;
- no active hold, supersede, same-EA run, or same-symbol run;
- custom-symbol history is claimable on every policy terminal T1–T10;
- present in the canonical pending selector at position `7158 / 7941` during the sealed receipt snapshot.

Root cause: **ordinary Q04 queue tail**, behind 5,700+ priority OPT_CENSUS rows and roughly 1,400 earlier Q04 rows. The recovery made no synthetic priority or gate change to Q04. This satisfies the task's root-cause alternative without inventing a new queue rule.

## Verification and fail-closed event

Focused verification:

```text
python -m pytest tools/strategy_farm/tests/test_recover_legacy_opt_census.py tools/strategy_farm/tests/test_opt_census_select.py -q
25 passed in 1.66s

python -m py_compile tools/strategy_farm/recover_legacy_opt_census.py tools/strategy_farm/tests/test_recover_legacy_opt_census.py
PASS

git diff --check -- tools/strategy_farm/recover_legacy_opt_census.py tools/strategy_farm/tests/test_recover_legacy_opt_census.py
PASS
```

The first apply attempt tried to update the old rows' storage `gate_contract_version`. The append-only database trigger refused it with `work_item gate_contract_version is append-only`; the entire SQLite transaction rolled back. A readback proved Q12 count `0` and governed legacy pending count `0`. The ceremony was corrected to retain the immutable legacy column, tests reran green, and only then was the successful transaction applied.

Code bindings:

- `recover_legacy_opt_census.py`: `1e5e01d534fec1ed97136d7dc6219a7162eacd14775922850398fb56b999dcad`
- `test_recover_legacy_opt_census.py`: `3eedaa5dcd3f1a5f2bda300dfeae959e982ca9b9284805ee7e4c419dcb55cb95`
- runtime recovery receipt: `D:\QM\strategy_farm\artifacts\opt_census\DL089_QM5_41097_USDJPY_DWX_2019_2025\recovery_receipt.json`, SHA-256 `21a80dd6cdc6644e95ad3636d7b2765b2898def0f02d078eb63d35848352e3c2`

## Review disposition

Leave this artifact and Q12 in **REVIEW**. The independent reviewer should verify the declaration/adoption hashes and the pending-only digest, then use a separate exact-row ceremony to release `Q12_LEGACY_CENSUS_RECOVERY_REVIEW_PENDING`. Do not run selection or advance the driver from this implementation ticket.
