# QM5_11533 FX compile-infrastructure recovery

Date: 2026-09-12

Branch: `agents/board-advisor`

EA: `QM5_11533_carter-t-h1-ema3-5-13-21-80-rsi21`

Scope: paced-fleet priority 2; EURUSD.DWX H1; compile infrastructure only

## Collision-free claim

- Farm task: `26226e74-14de-4a39-b8ac-7bfa4bac1e10`
- Task kind: `infra_repair`
- Claimed by: `codex:agents/board-advisor`
- Failed Q02 predecessor: `676f9094-fd94-4573-ac7d-88b165221f04`
- Predecessor verdict/failure: `INFRA_FAIL`, `compile_gate:COMPILE_FAILED`
- Claim backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11533_compile_infra_claim_20260912T163423Z.sqlite`

No open work item or open task existed for this EA when the claim was made.

## Root cause and bounded repair

The durable compile result at
`D:\QM\reports\compile\QM5_11533_carter-t-h1-ema3-5-13-21-80-rsi21\result.json`
records:

- verdict: `COMPILE_FAILED`
- reason: `compile_one.ps1 reason_class=INCLUDE_MIRROR_REFUSED errors=-1 warnings=-1`
- compile exit code: `1`
- timestamp: `2026-09-12T06:59:19+00:00`

The Q02 compile gate used a legacy, unbound invocation while live factory
terminals existed. The governed COMPILE_EA worker supplies both
`CompileWorkItemId` and `ClaimedTerminal`, which is the include-mirror contract.
No EA source or strategy mechanics were changed.

The compile admission change binds only this EA label to the claimed farm task:

`router_q02_infra_repair:26226e74-14de-4a39-b8ac-7bfa4bac1e10`

It permits one append-only, current-source-hash-bound COMPILE_EA row. It grants
no strategy, backtest, gate-verdict, cross-EA, portfolio, or live authority.

## Validation and enqueue receipt

Current MQ5 SHA-256:
`5c166352f721da90aecb8d702065d4953443a340def98f60f91dbd7d39953e14`

The binding PACER audit was run immediately before enqueue:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_11533_carter-t-h1-ema3-5-13-21-80-rsi21/QM5_11533_carter-t-h1-ema3-5-13-21-80-rsi21.mq5"
ok=true predicate=EA_FRAMEWORK_INPUT_PINNED source_count=1 hit_count=0 hits=[]
```

Other checks:

- `build_gate_hardening.py`: PASS, zero failures and warnings
- `validate_build_guardrails.py`: PASS, no findings
- `validate_spec_doc.py`: PASS
- exact authority regression tests: 2 passed
- full `test_compile_work_items.py`: 91 passed, 1 unrelated existing SH-3
  fixture-schema failure in
  `test_compile_profile_stdlib_failure_is_persisted_as_infra_not_compile_fail`

Governed compile work item:
`cd4e4ae3-03f7-420d-9a35-ebaad85fcc6a`

The row is pending under `COMPILE_EA_WORKER_ROLLOUT_PENDING`. Its release dry run
passed with an exact expected/actual source-hash match. Release was not applied:

1. The first apply lost a farm-mutation-lock race and made no change.
2. The bounded retry failed closed after the 60-second backup deadline:
   `COMPILE_WAVE_BACKUP_TIMEOUT:elapsed_seconds=60.015:remaining_pages=228718:total_pages=309102`.

Five CPU samples during the attempt were 99.51%, 94.83%, 89.28%, 91.03%, and
93.27%. Because the paced-fleet CPU/backup ceiling was reached, the compile row
remains activation-held and no Q02 successor was enqueued. Resumption must
release only `cd4e4ae3-03f7-420d-9a35-ebaad85fcc6a` through
`release_compile_wave.py`, wait for `COMPILE_OK`, verify the fresh EX5 receipt,
then append the Q02 requalification successor to predecessor
`676f9094-fd94-4573-ac7d-88b165221f04` if capacity permits.

## Safety boundary

No T_Live files, AutoTrading state, portfolio gate, or T_Live manifest were
changed. No tester process was started or stopped. No Q-phase verdict was
created.
