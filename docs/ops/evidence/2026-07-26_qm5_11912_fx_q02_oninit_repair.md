# QM5_11912 FX Q02 ONINIT Repair

Date: 2026-07-26  
Branch: `agents/board-advisor`  
Claim task: `e278d8b3-e5c8-47f4-870a-fa7b4de25e63`

## Scope

One paced-fleet priority-2 repair for the diverse FX EA
`QM5_11912_cheng-triangle-2touch-second-break-h1`. No T_Live, AutoTrading,
portfolio gate, deploy manifest, or manual tester run was touched.

## Source failures

- `6c9ff907-167b-4822-a96c-05ae5f3a2c28`: GBPJPY.DWX Q02,
  `ONINIT_FAILED;INCOMPLETE_RUNS`.
- `511318c1-60c0-4a17-b8a0-20a4483b9744`: AUDUSD.DWX Q02,
  `BARS_ZERO;ONINIT_FAILED;INCOMPLETE_RUNS`.

No pending or active QM5_11912 Q02 row existed when the repair was claimed.
The claim DB backup is
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11912_claim_20260726T131710Z.sqlite`.

## Diagnosis

The `ONINIT_FAILED` surface verdict was not supported by the structured EA
evidence. The GBPJPY logger sample recorded, in order:

- `SYMBOL_GUARD_INIT` for `GBPJPY.DWX`;
- successful news-calendar self-test and load;
- `KILL_SWITCH_INIT` with magic `119120008`; and
- framework `INIT`.

The EA registry contains active slots 0-9, and the generated magic resolver
contains EA 11912. The failure was therefore classified as an incomplete tester
run after successful framework initialization, not a missing magic allocation or
card defect. The tracked EX5 was refreshed against the current framework.

## Validation

- Strict compile: PASS, 0 errors, 0 warnings.
- Compile summary:
  `D:\QM\reports\compile\20260726_131755\summary.csv`.
- Build check: PASS, 0 failures, 0 warnings.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260726_131850.json`.
- MQ5 SHA256:
  `faf7971784b4ad1d39911b00e56d271657025b96e0711fa0b3c27f26a0f0034a`.
- Refreshed EX5 SHA256:
  `296ed464891ec0a1505c00a2b90e3b98acf9b9af4167a7638f15b05ebece5071`.
- GBPJPY RISK_FIXED setfile SHA256:
  `45e4ae4ad025a429b3ad27d45a7c0bb2c7225d39f9b31d1a363a748676dc921a`.

## Q02 handoff

Exactly one GBPJPY.DWX H1 Q02 work item was enqueued:
`6483e565-942d-4a41-ba3c-7a2af9292a67`.

The enqueue collision guard observed 9 active work items (below the 10-terminal
ceiling), rejected duplicate pending/active QM5_11912 Q02 rows, bound all three
artifact hashes, and steered the retry away from T8. The pre-enqueue DB backup is
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11912_q02_requeue_20260726T131931Z.sqlite`.

The work item was left `pending`; no terminal or backtest was launched manually.
