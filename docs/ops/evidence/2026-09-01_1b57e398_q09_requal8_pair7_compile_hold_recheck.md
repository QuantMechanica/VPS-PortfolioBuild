# Q09 REQUAL-8 pair 7 governed compile hold recheck

- Recorded: `2026-09-01T14:04Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Branch: `agents/board-advisor`
- Predecessor checkpoint: `docs/ops/evidence/2026-09-01_1b57e398_q09_requal8_pair7_source_compile_handoff.md`
- Checkpoint: `PAIR7_COMPILE_ACTIVATION_HELD`

## Outcome

The governed pair-7 compile has not run. Canonical `farmctl.py compile-status` reports one requested item, one pending item, zero active, zero compiled, zero failed, and one activation-held item. The precise hold is `COMPILE_EA_WORKER_ROLLOUT_PENDING`.

The hold was not bypassed. No local compiler, MetaEditor, terminal, smoke, review, Q02 seed, pipeline command, or manifest-hold release was invoked. Because no governed EX5 or build result exists, build review and every downstream action remain forbidden.

## Governed queue and build-task state

- Compile work item: `26d03ef4-cfae-4d31-9202-040d29a1e14b`
- Phase/status: `COMPILE_EA / pending`
- Claimed by: none
- Attempt count: `0`
- Evidence path: none
- EX5 SHA-256: none
- Bound build task: `0f36f1bb-924b-4126-b682-c30ba1edfa41`
- Build task kind/status: `build_ea / pending`
- Build task card: `QM5_41221`
- Queue activation state: `AWAITING_REVIEWED_WORKER_ROLLOUT`
- Queue activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`
- Utility/no-gate marker: `true`
- Bound symbol/timeframe: `EURUSD.DWX / D1`
- Bound risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`

Canonical read-back:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py compile-status QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8
counts: activation_held=1, active=0, compiled=0, failed=0, pending=1
status: pending
activation_hold: COMPILE_EA_WORKER_ROLLOUT_PENDING
work_item_id: 26d03ef4-cfae-4d31-9202-040d29a1e14b
```

## Sealed-input integrity

The exact inputs are unchanged from the source-seal checkpoint:

- MQ5 SHA-256: `ede8570a029563fadecdfb99b829331903dffa0d2e46a3bb64c6e3cf8af8e91f`
- SPEC SHA-256: `ecd2934dfdb42576f01d5ade15f481603df6a2ba8278832ac62d2ceea770490b`
- Backtest-set SHA-256: `30d264d6f8533d9f40c9833f9ed69a69d7b914a20adf0db458cd7a01b40e59cb`
- Queue-bound MQ5 SHA-256: `ede8570a029563fadecdfb99b829331903dffa0d2e46a3bb64c6e3cf8af8e91f`
- Expected EX5 path exists: `false`
- Scoped `git diff --check`: PASS
- Registry/generated paths changed by this build: zero

The MQ5, SPEC, and set remain untracked pending the governed compile/build-record boundary. They were not committed as a completed build because no EX5 exists.

## Protected parent program

No build operation targeted, dispatched, stopped, or modified the protected `QM5_41162` census. The program advanced through its own ordinary workers while other assigned operations were handled and is now naturally quiescent:

- Program: `DL089_QM5_11421_EURUSD_DWX_2019_2025`
- Rows: `1,159`
- Active: `0`
- `done/MEASURED`: `235`
- `done/SKIPPED_EXCLUDED`: `924`
- Read-only snapshot SHA-256 at this checkpoint: `ac78f3f340f7f05f0f214dd12189cda61076a0d45a298c4767904017175509e2`

The changed snapshot relative to the predecessor checkpoint is expected ordinary census progress, not a pair-7 build mutation.

## Verdict and continuation boundary

`PAIR7_COMPILE_ACTIVATION_HELD`: sealed inputs still match the queued binding, but the controller-owned worker-rollout hold prevents governed compilation. The next legal action is to observe the existing work item after the reviewed compile-worker rollout releases it. Only a successful governed compile may be recorded as the build checkpoint; only then may pair-7 review, append-only Q02 seeding, and manifest-hold release proceed.

This artifact remains in REVIEW. No self-approval or main-worktree integration was performed.
