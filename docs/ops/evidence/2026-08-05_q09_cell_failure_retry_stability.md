# Q09 cell-failure retry stability

Date: 2026-08-05  
Router task: `5d8420ef-4060-4cc5-84e5-1b11e2d090a0`  
Canonical checkout: `C:/QM/repo` (`agents/board-advisor`)  
Code commit: `d22dfee9e54b45be7663a8bef270681442a2677e`

## Outcome

Q09 cell-failure recording is now retry-stable and remains fail-closed on
identity drift. The first failure remains immutable as `cell_failure.json`. A
later failure for the same authenticated cell is recorded append-only as
`cell_failure_2.json`, then `cell_failure_3.json`, and so on. Divergent error
text or artifact manifests do not contradict the original failure and cannot
crash the whole resumed attempt.

Receipt precedence is unchanged. When an authenticated `cell_receipt.json`
coexists with stale failure sidecars, collection uses the receipt and treats the
cell as successfully resumed.

## Read-only production evidence

The active row was not mutated or re-enqueued. Diagnosis used only the task's
existing evidence:

- Work item: `4984cca7-e1a3-49a8-a066-066ac51eb063`.
- Worker log:
  `D:/QM/strategy_farm/logs/work_item_4984cca7-e1a3-49a8-a066-066ac51eb063.log`.
  The retained traceback shows a transient Q09 `run_smoke` failure reaching
  `_write_cell_failure`, followed by `_write_immutable` raising
  `existing planned artifact contradicts immutable content` for the existing
  `policy_on__m2__c1__s7/cell_failure.json`.
- The same cell currently contains both the original failure sidecar and the
  later receipt. Their stable run identity is
  `f38277bb87e8eeda14d1a54f0b7ec9fd5af85d97116b302eab9c36d6077a876b`;
  their paired-base identity is
  `916bade05141af56d7d24330d68e25bb7a55740b39fcb1f3383b8a45fecb95c7`.
- Original failure SHA-256:
  `317f40807e6696bdde7be3b2aeecc7e1977e617d818b974785066f87cf052d73`.
- Resumed receipt SHA-256:
  `4716a95c01520a1f3cb50110f926439a7be98c6f069b309c73fb8ab1c451a79c`.

## Implementation

`tools/strategy_farm/q09_news_runner.py` now defines and authenticates exactly
these stable failure fields:

1. `schema_version`
2. `work_item_id`
3. `run_identity_sha256`
4. `paired_base_identity_sha256`
5. `arm`
6. `temporal_mode`
7. `compliance_mode`
8. `seed`

When the original sidecar exists, `_write_cell_failure` reads it and compares
only those fields. A mismatch still raises `RunnerError`. A match advances to
the first unused numbered sidecar; any existing numbered sidecar is also
stable-identity checked before advancing. Error text and artifact rows remain
durable evidence in each occurrence but are deliberately excluded from the
identity comparison.

Failure sidecars are excluded from subsequent failure artifact manifests, so
the append-only occurrence chain does not recursively hash itself. The writer
returns the path of the new occurrence, preserving the existing top-level
execution-failure pointer and SHA behavior. The collector's existing
receipt-first branch was not changed.

## Verification

Focused regression command:

```text
python -m unittest tools.strategy_farm.tests.test_q09_news_runner_v2.Q09NewsRunnerV2Tests.test_failure_retries_append_and_receipt_precedes_stale_sidecars tools.strategy_farm.tests.test_q09_news_runner_v2.Q09NewsRunnerV2Tests.test_failure_retry_keeps_stable_identity_mismatch_fail_closed -v
```

Result: `2/2 PASS` in 2.689 seconds.

Complete runner regression command:

```text
python -m unittest tools.strategy_farm.tests.test_q09_news_runner_v2 -v
```

Result: `19/19 PASS` in 23.462 seconds.

The new regression proves in one fixture that:

- failure two has different error text and a larger artifact set;
- failure two writes `cell_failure_2.json` without changing one byte of
  `cell_failure.json`;
- failure sidecars do not enter later artifact manifests;
- all eight stable fields remain equal across occurrences;
- after receipts are written, all 40 cells authenticate, zero cells are failed,
  and the Q09 result remains `CONFIG_LOCKED` despite both stale sidecars; and
- stable identity tampering still fails closed and does not write a numbered
  occurrence.

`git diff --cached --check` also passed before the code commit.

## Guardrails

No Q09 work item was enqueued, re-enqueued, cancelled, or updated. The active
row `4984cca7-e1a3-49a8-a066-066ac51eb063` and its live files were read only.
No terminal was started, stopped, or interrupted; `T_Live`, AutoTrading, and
factory state were untouched. No pipeline verdict is asserted by this repair.
