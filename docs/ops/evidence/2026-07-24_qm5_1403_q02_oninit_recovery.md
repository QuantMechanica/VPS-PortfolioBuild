# QM5_1403 Q02 ONINIT recovery

Date: 2026-07-24  
Branch: `agents/board-advisor`  
Scope: non-live Q02 infrastructure recovery only

## Selection

The paced-fleet backlog had no faithful unclaimed diversity build:

- `QM5_1459_as-lumber-gold` requires lumber and Treasury inputs that are absent
  from the approved DWX matrix.
- `QM5_1457_as-predict-bonds` is already blocked on unavailable rates inputs.
- The remaining fresh build is an index sleeve, which does not address the
  mission's instrument-diversity constraint.

`QM5_1403_harmonic-5-0-pattern-h4` was therefore selected from priority 2. Its
USDJPY Q02 work item `899c92f1-1c2b-44e5-a1ad-78fb5670dc2f` ended
`INFRA_FAIL` with `run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`, and the farm
had no later PASS or pending/active replacement for this EA.

## Diagnosis and repair

The failed item was bound to the old June 2026 artifact generation. The current
EA directory already contains the corrected full-input setfile generation, so
the recovery refreshed all 13 registered backtest setfiles with
`gen_setfile.ps1`, rebuilt the current resolver binary, and verified the EA
under the strict build gate. Strategy mechanics were not changed.

USDJPY recovery artifacts:

- MQ5 SHA-256:
  `7a4aab26f6c2c49c775551c0bf5c6b92a0ac205694993a2ea6266ed7adcfb8b7`
- EX5 SHA-256:
  `8b7945c297b8ce461a71e0197d35ce5c4bce5269e2d8adc84591a01d42d65b20`
- Setfile SHA-256:
  `0d389d7e163a18099627e87d0e66029a21b2889512e78afa967fd82daaa0f8e9`
- Compile log:
  `framework/build/compile/20260724_004719/QM5_1403_harmonic-5-0-pattern-h4.compile.log`
- Compile result: PASS, 0 errors, 0 warnings
- Strict build result: PASS
- Risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`

## Farm handoff

Exactly one replacement Q02 prescreen was enqueued for `USDJPY.DWX` H4:

- New work item: `9b57123a-dc93-4a7a-8793-e6abb83d9b7a`
- Status at handoff: `pending`
- Source failed item:
  `899c92f1-1c2b-44e5-a1ad-78fb5670dc2f`
- Evidence binding records the MQ5, EX5, and setfile hashes above.

No backtest was run in this unit. No T_Live, AutoTrading, portfolio gate, or
live manifest state was touched.
