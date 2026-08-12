# QM5_11147 USDJPY Q02 Binary Refresh

## Outcome

`QM5_11147_clenow-vam-rot` was repaired and re-enqueued as one logical
`USDJPY.DWX` D1 Q02 work item:

- work item: `9bf3f663-f920-4e7b-a004-9cea683a4c0f`
- farm claim: `e541771d-4650-4182-aceb-6f608fd864ad`
- queue status at handoff: `pending`
- setfile risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`

## Diagnosis

The preceding USDJPY repair row
`742fe85c-0180-433e-9cae-ac6963eef504` exhausted retries as
`summary_missing`. Its runner recorded exit code 0, but neither a summary nor
the referenced work-item log survived. There was no pending or active
QM5_11147 Q02/Q03 row when this repair was claimed.

The canonical source remained registry-clean. A fresh strict compile completed
with zero errors and zero warnings and refreshed the `.ex5`, removing a stale
or incompletely distributed binary as a variable before the retry.

## Evidence binding

- MQ5 SHA-256:
  `c94da604a397b605374c6ed7ea8d0603c959918f1c61a1568e7db569dfaa45c9`
- EX5 SHA-256:
  `48371f5611e36a10440c798a758cf79b86a1a730ba54cfa8a4fb53594561af21`
- strict compile result: `PASS`
- compile log:
  `framework/build/compile/20260724_013120/QM5_11147_clenow-vam-rot.compile.log`

The new farm row binds both hashes and requires evidence binding. No strategy
mechanics, portfolio gate, T_Live artifact, or AutoTrading state was changed.
