# QM5_20143 stale-EX5 recovery handoff

Date: 2026-09-10 (Europe/Berlin)  
Branch: `agents/board-advisor`  
Outcome: source repaired; exact governed compile successor queued and held for
worker rollout; no backtest or live action performed.

## Selection and coordination

The higher-priority approved build backlog had no unclaimed, genuinely unbuilt
high-diversity candidate. QM5_20143 was selected from the Q02/Q03 infrastructure
cohort because both approved major-FX cells still lack an economic verdict and
the current source is newer than the surviving binary.

- Infra-repair claim: `1d1f0dd8-64b9-4011-befb-0b96df513147`
- Claim backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20143_stale_ex5_claim_20260909T223411Z.sqlite`
- Failed EURUSD Q02 row: `6f32d1f9-680f-4e35-a684-fe4c1ddd80b5`
  (`compile_gate:COMPILE_FAILED`)
- Stale pending GBPUSD Q02 row: `8be76d81-2983-4acb-a733-0b653b244be2`
- Earlier terminal signatures: `ONINIT_FAILED` and `NO_HISTORY`

## Diagnosis and repair

The canonical `.ex5` SHA-256
`32be593045e544aa1c462993af5aae97e55a98c12b1a26a717719d85c5ccb470`
predates the committed indicator-warmup source repair. The pre-turn `.mq5`
SHA-256 was
`38d9ed0f54c3f9baf0f0447448db8748ef9a23b3bb014ea7fe2f18921bd7db4d`.
The remaining Q02 retry therefore failed closed at its compile gate.

This turn made three conformance-only changes:

1. corrected the default `qm_ea_id` from placeholder `9999` to registered ID
   `20143`;
2. bound both OnInit Bollinger self-test loops to the verified dynamic-array
   size; and
3. normalized `SPEC.md` to the required seven-section documentation contract.

No strategy parameter or strategy mechanic changed. The repaired source
SHA-256 is
`6d15f3be593bfefa572122808cdd5a925aa867fe0a74f28a1a0221728dfe6b16`.
The source is marked `-text` in `.gitattributes` so the authority remains
byte-stable under Windows checkout.

## Guard and validation evidence

- Required PACER pin audit immediately before enqueue: PASS,
  `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.
- SPEC validation: PASS (`1 PASS, 0 FAIL`).
- Focused compile-authority tests: PASS (`2 passed, 82 deselected`).
- Diff whitespace check: PASS.
- Local `build_check.ps1`: intentionally refused with
  `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because tester terminals were alive;
  no retry or ad-hoc compile was attempted.

The immutable authority receipt is
`docs/ops/evidence/2026-09-10_qm5_20143_stale_ex5_rebuild_authority.json`
(SHA-256
`9a0e1e83a4034c7c0a57eaffc41e2380b8ca83c247f984078863e8deec0726ce`).

## Governed queue result

The source-hash-bound compile authority
`router_q02_infra_repair:1d1f0dd8-64b9-4011-befb-0b96df513147:QM5_20143`
created exactly one append-only COMPILE_EA work item:

- work item: `4144f8f2-796f-40bf-b376-04f3b7f37ac2`
- state: `pending`
- hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`
- compile and gate verdict: none

The hold is retained: the resident worker must first run code that knows the
new exact authority. Q02 was not enqueued because no current-source `.ex5`
exists yet. After a reviewed worker rollout, the governed continuation is to
release only this compile row, require `COMPILE_OK`, and append a current-
identity Q02 successor (the stale pending GBPUSD row must fail closed or be
handled by the normal governed successor path).

## Capacity and safety

A five-sample CPU check after enqueue measured 70.74% average and 87.01%
maximum, below the 97% tester-admission ceiling. Four pipeline tester terminals
were active. No tester was started by this turn.

`T_Live` and AutoTrading were untouched. No portfolio gate, live manifest,
deployment, or live-readiness action was authorized or performed.
