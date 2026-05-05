# QUA-747 / QM-00061 Secondary Fix (2026-05-05)

## Symptom

`p2_baseline.py` rows failed with `INVALID no_summary_json:rc=1` immediately after dispatch scheduling.

## Root Cause

`run_smoke.ps1` still enforced terminal-running guard even when `-Terminal any` was used:
- dispatch resolved terminal successfully,
- then pre-launch guard threw `Terminal instance is already running...`,
- script exited before writing `run_smoke.summary=...`.

## Fix

File: `framework/scripts/run_smoke.ps1`

- Changed running-terminal pre-launch guard to apply only for pinned terminals.
- `Terminal=any` now relies on dispatcher capacity control instead of local hard-abort.

## Evidence

Repro command:

`python framework/scripts/p2_baseline.py --ea QM5_1004 --symbols AUDCAD.DWX --year 2024 --runs 2 --min-trades 20 --timeout 60`

Before fix:
- immediate `no_summary_json:rc=1` with stderr `Terminal instance is already running...`

After fix:
- no pre-launch abort; run enters execution and returns `[TIMEOUT] ... exceeded 60s` with normal P2 summary write.

This confirms QM-00061 failure mode (pre-summary abort) is removed.