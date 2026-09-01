# QM5_41272 review-first handoff evidence

- Date: 2026-09-01
- Authority task: `2e0bc944-0f47-47e2-b6c2-e7b83db89147`
- EA: `QM5_41272_turn-of-month-index-long-restart-r1`
- Verdict: `READY_FOR_INDEPENDENT_REVIEW; Q02_NOT_RELEASED`
- Branch: `agents/board-advisor`

## Outcome

QM5_41272 now has an exact, fail-closed exception that requires independent EA review and Orchestrator closure before any Q02 seed can be appended. The corrected build record is `done`, its independent review task is `pending`, and the Q02 row count remains exactly zero.

The exception is deliberately narrow. It applies only when all of the following values match the sealed recovery authority:

- authority task: `2e0bc944-0f47-47e2-b6c2-e7b83db89147`
- approved card SHA-256: `f506d65e0d2542244e8130b6be70586cde4e8b84d44addcb921c69629f786952`
- compile evidence SHA-256: `3210bc7225d8e1b1087418d3d7573014685e1b11fcf3de25f5d75052db6263e9`
- EA identity: `QM5_41272`
- source identity: `fx_edge_army_A3_2026-07-16_restart_recovery_9a55`
- parent runtime identity: `QM5_20004`

Any mismatch fails closed and does not seed Q02.

## Durable implementation

- `17b8bc04b1` — `fix(farm): gate QM5_41272 Q02 on review`
  - adds the exact hash-bound review-first decision to `tools/strategy_farm/farmctl.py`
  - suppresses generic Q02 fanout only when every sealed binding validates
  - binds the generated independent-review prompt to the recorded build-result path
  - adds focused regression coverage in `tools/strategy_farm/tests/test_owner_review_first_q02.py`
- `ca11f38730` — `fix(qm5_41272): complete review-ready spec binding`
  - completes the mandatory `SPEC.md` sections without changing mechanics
  - records the corrected absolute EA directory and sealed artifact hashes

Build artifact bindings:

- MQ5 SHA-256: `47579844c327c1aee22986fef9c3170a1fcc973926c9908ec0c91d27b5d5d442`
- EX5 SHA-256: `2845820d099232713c053266e0b6204ef904e872f5cd6fad2efbcc6441ef4fe9`
- setfile SHA-256: `6474359fd97c4fb7625d159deaf6fcbd186c5bdf14f70fffcabad2d8e40b9e16`
- `SPEC.md` SHA-256: `46a338092b4d6a0a457feb66b95435cd2c26976998d0b8925c9838e04a6eae65`
- build-result SHA-256: `2e287d40a41044b4584e52c4355050f3ba7f885a1c74437dba644fc265461c65`

## Controller state

- corrected build task: `214e1966-5711-481f-9450-cbe636f7e157` — `done`
- independent EA-review task: `6ccfaf57-5d5c-4d5c-ab5c-efe77bb71418` — `pending`
- review prompt: `D:\QM\strategy_farm\queue\claude_review_6ccfaf57-5d5c-4d5c-ab5c-efe77bb71418.md`
- review-prompt SHA-256: `98169117901e1a98890786e1c3aba9aebfec2cb12ad2641e6e15e4a752ccea09`
- verdict target: `D:\QM\strategy_farm\artifacts\verdicts\review_6ccfaf57-5d5c-4d5c-ab5c-efe77bb71418.json`
- Q02 rows for `QM5_41272`: `0`

The first record-build attempt, task `28ba8397-3400-4f5b-a545-0d5ba7278200`, failed closed because the initial SPEC/path binding was incomplete. It created no Q02 row. After the corrected append-only build task was recorded, that failed attempt was CAS-tombstoned as `blocked` with both `superseded_by` and `duplicate_of_task_id` pointing to `214e1966-5711-481f-9450-cbe636f7e157`. This prevents the bounded retry loop from reopening a duplicate build.

During that containment race, the scheduler archived the shared build-result file once as `.attempt_0.json`. The canonical committed filename was restored byte-for-byte; both the database binding and restored file hash to `2e287d40a41044b4584e52c4355050f3ba7f885a1c74437dba644fc265461c65`. The tombstone prevents another archive pass.

## Verification

Focused test command:

```text
python -m pytest -q tools/strategy_farm/tests/test_basket_work_items.py tools/strategy_farm/tests/test_factory_off_build_interlock.py tools/strategy_farm/tests/test_levelup_cohort0.py tools/strategy_farm/tests/test_mnt012_build_guards.py tools/strategy_farm/tests/test_owner_review_first_q02.py
```

Result: `48 passed in 10.25s`.

SPEC validation command:

```text
python framework/scripts/validate_spec_doc.py framework/EAs/QM5_41272_turn-of-month-index-long-restart-r1
```

Result: `1 PASS, 0 FAIL`.

Post-containment database assertions:

- failed attempt status: `blocked`
- replacement build status: `done`
- independent review status: `pending`
- Q02 rows before containment: `0`
- Q02 rows after containment: `0`

No live-trading setting, AutoTrading setting, terminal process, or active backtest was changed.

## Required next checkpoint

The independent reviewer must review the exact artifacts above. Orchestrator must then close that review. Only an approved, generation-matched review may authorize the append-only Q02 seed; this evidence does not itself authorize Q02.
