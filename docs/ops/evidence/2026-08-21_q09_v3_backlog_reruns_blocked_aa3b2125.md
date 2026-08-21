# Q09_NEWS backlog reruns — fail-closed prerequisite check

Date: 2026-08-21  
Router task: `aa3b2125-6d7d-442d-a570-dc42e4f0d83a`  
Disposition: **BLOCKED BEFORE EXECUTION; no backlog row or work item was mutated**

## Required prerequisite

The routed authority explicitly gates the 40-row append-only rerun wave until Q09_NEWS
Contract v3 is active. Running the 24 `cell_execution_failed`, 9
`cell_receipt_invalid`, and 7 `expanded_7x4_matrix_required` rows under v2 would require
the prohibited 33x40 plus 7x105 tester-cell workload.

That prerequisite is not satisfied:

- Upstream implementation task `855a9098-b28b-404f-8a91-30485684930a` is in `REVIEW`,
  not accepted/active. Its verdict states that it stopped before code changes because of
  live file collisions and requires re-dispatch for implementation.
- Its artifact, `docs/ops/evidence/2026-08-21_q09_acceleration_contract_v3.md`, states
  explicitly: "No code was written" and lists every implementation step as not done.
- The production code still identifies only v2 contracts:
  `q09_news_runner.py` declares `PLAN_SCHEMA = "q09-news-run-plan/v2"`, while
  `q09_news_contract.py` declares `SCHEMA_VERSION = "q09-news-evidence/v2"` and the
  five-seed set `(42, 17, 99, 7, 2026)`. There is no active v3 schema or v3 runner path.

## Decision

No v2 plan was sealed, no Q09_NEWS row was enqueued or rebound, no tester cell was
started, and no prior evidence was overwritten. This is the only fail-closed result
consistent with both the task's prerequisite and the instruction not to invent work
outside the deterministic router.

The orchestrator must first re-dispatch and accept the separate Contract-v3
implementation task. Only after production v3 code and its verdict-identity tests are
active may this exact 40-row rerun task be re-routed for execution.
