# T12 research-seat identity retry — runtime guard refusal

Date: 2026-09-12 05:59–06:09 UTC
Router task: `2c3cb09e-d98e-4eae-80db-3bd16bcfeb1a`

## Result

The T12 inputs were staged hash-identical to the fleet reference and the isolated
Model-4 dry-run passed. The consequential identity smoke was then admitted, but the
controller's first runtime resource window observed **99.6%** five-sample CPU versus
the task-authorized `QM_CANARY_CPU_LIMIT=99` ceiling. It aborted only its bound T12
job and recorded `REFUSED`; no report or economic metrics were accepted.

The required identity equality (net 2941.71 / PF 1.03 / 208 trades) is therefore
**not proven**. A concurrent T11+T12 pilot was not launched because it would have
violated the same headroom condition and because T12 identity remains a prerequisite.
This task does not meet its PASS acceptance and is handed to REVIEW with exact retry
conditions, not a fabricated success claim.

## Bound inputs and receipts

| Item | Result |
|---|---|
| EX5 SHA-256 | `68d37d3a6b6d5d4354e5a9aa494488d8d2809b1f662ff75fbb26440658137c01` (fleet-identical) |
| Setfile SHA-256 | `afa42711867677bd7d5641f93e52a104f31c86a181f835579241b214f35bf47c` (2021 s3_l3 fleet-identical) |
| Staging | `D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2021_T12_IDENTITY/staging/20260912_055905_c0145e7a_receipt.json` |
| Dry run | `D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2021_T12_IDENTITY/20260912_055912_cf8645ec/receipt.json`: `DRY_RUN_PASS`, Model 4, 108 signed history files, 0 T12 agents, 37,214,162,944 free bytes, CPU mean 85.7%, isolation unchanged |
| Actual attempt | `D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2021_T12_IDENTITY/20260912_060425_28f75cea/receipt.json`: `REFUSED`, runtime CPU 99.6% > 99%; isolation unchanged; no report |

## Safety and retry condition

- Research seat T12 only; no factory row or fleet claim path was used.
- No T_Live/FTMO or AutoTrading action.
- The kill-on-close job boundary stopped only the spawned T12 process.
- T11 was not launched; no concurrent load was added after the refusal.
- Retry only in a demonstrably quieter window where both admission and runtime
  five-sample CPU remain at or below the declared ceiling. Only after T12 produces
  a report matching 2941.71 / 1.03 / 208 may one-run-per-seat concurrency be tested.

## Review disposition

`REVIEW — ACCEPT SAFETY REFUSAL, NOT IDENTITY PASS.` The task should be reissued for
a quiet window; this cycle establishes correct input identity and fail-closed runtime
behavior but does not authorize T12 capacity.
