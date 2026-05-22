# QM5_10260 M15 Setfiles And Q02 Requeue

Date: 2026-05-22

Task: `8babdd08-7465-4e5c-8a9d-8c1cc2ed8c9e`

## Summary

`QM5_10260` was blocked in Q02 by missing M15 backtest setfiles. The queued work items referenced 37 M15 setfile paths under `framework/EAs/QM5_10260_cieslak-fomc-cycle-idx/sets/`, but only the three index M15 files existed before repair.

Regenerated all 37 M15 backtest setfiles, refreshed the EA build, deployed the matching `.ex5` to T1-T10, verified deployment hashes, and reset the existing Q02 work items to `pending` with stale verdict/evidence fields cleared.

No terminals were started manually. `T_Live` and AutoTrading were not enabled.

## Actions

- Generated 37 M15 backtest setfiles via `framework/scripts/gen_setfile.ps1`.
- Verified queued Q02 setfile paths: `work_items=37 missing_setfiles=0`.
- Ran build check:
  - Command: `framework/scripts/build_check.ps1 -EALabel QM5_10260_cieslak-fomc-cycle-idx`
  - Result: `PASS`, `0` errors, `0` warnings
  - Report: `D:/QM/reports/framework/21/build_check_20260522_050613.json`
- Verified deployment before copy:
  - Result: `SHA_MISMATCH` across T1-T10
- Deployed compiled `.ex5` through the repository deployment script:
  - Evidence: `D:/QM/strategy_farm/artifacts/ops/deploy_QM5_10260_2026-05-22.json`
- Verified deployment after copy:
  - Command: `python framework/scripts/verify_build_deployment.py --ea-id 10260 --ea-dir-glob 'QM5_10260_*' --json`
  - Result: `PASS`
  - Source SHA256: `97a627765b55f5698b270a4870a28742b55520889bcd77bf08d5b56f1139414c`
  - T1-T10 SHA match: true
  - Setfile count reported by verifier: `40` (37 M15 plus 3 existing M30 files)
- Reset existing `QM5_10260` Q02 work items:
  - Requeued: `37`
  - State after reset: `Q02_pending: 37`
  - `attempt_count=0`, `verdict=NULL`, `evidence_path=NULL`, `claimed_by=NULL`

## Current Evidence

`python tools/strategy_farm/farmctl.py work-items --ea QM5_10260` now reports:

```json
{
  "summary": {
    "Q02_pending": 37
  }
}
```

Direct setfile audit:

```text
work_items=37 missing_setfiles=0
states= [('pending', None, 37)]
```

## Remaining Pipeline Work

Q02 still needs deterministic worker execution to produce real PASS/FAIL verdicts. This artifact only fixes the missing setfiles, stale deployment hash, and stale work-item state.

`farmctl health` after the repair still reports overall `FAIL` because `p_pass_stagnation` remains true, with one `active_row_age` warning unrelated to this setfile repair.
