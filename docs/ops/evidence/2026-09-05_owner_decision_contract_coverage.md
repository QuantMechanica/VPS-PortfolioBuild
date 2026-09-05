# Owner decision contract coverage

Task 030e09d9-df7d-480f-9488-c625fe7e1eda. Result: PASS; review required. Measured at 2026-09-05T08:30:53.550202+00:00.

The old equality assertion incorrectly rejected contract growth beyond the seven bootstrap decisions. The test now requires the seed ids to be a subset and checks the ready YES/NO plans for **every contract entry**. Fixture coverage rejects OPEN and DEFERRED cards without a plan, excludes terminal DECIDED cards, rejects an invalid one-choice contract, and proves the inputs remain unchanged.

The optional `owner_decision_execution.py --coverage` path reads the feed and one validated contract snapshot, prints missing plans and exits 2 on missing/invalid coverage. It rejects --apply and never opens the router database or creates tasks. No execution contract content changed.

Validation: all four owner-decision test files (execution, store, service, browser_e2e) passed: **18 passed in 9.47 seconds**. git diff --check passed. The read-only live coverage check against the canonical contract found 18 contract entries and 2 active cards, all 2 ready, no missing plans. The adjacent JSON binds canonical feed/contract hashes at observation time; this is a snapshot rather than a permanent guarantee.

Code commit `e0dfeb6e875ea73aee2ab35d429eb89e883387a2` is isolated on `agents/codex-owner-coverage-20260905` because the existing agents/codex checkout is divergent and has an unrelated include edit. The adjacent patch is the handoff; evidence is committed only on canonical agents/board-advisor. No deployment or main integration was performed.

Read-only command after integration:

```powershell
python C:/QM/repo/tools/strategy_farm/owner_decision_execution.py --coverage
```

Patch SHA-256: `46dc9dfec884ea51972b7fbc81ed147c2d2e314a5b3a7141a0eee496e6cc2295`.
