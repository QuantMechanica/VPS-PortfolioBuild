# QUA-662 D2 staging blocker (2026-05-01T11:43Z)

## What I executed

- Ran `dwx_hourly_check.py` directly.
- Result: exits in Phase A because WS30 sentinel files are missing from staging.

Console evidence:
- `WS30 tick CSV: missing`
- `WS30 m1 CSV: missing`
- `Phase A: WS30 not stable yet -- exiting`

## Staging coverage audit

- Audit file: `docs/ops/QUA-662_D2_STAGING_COVERAGE_AUDIT_2026-05-01T1142Z.json`
- Canonical matrix source: `.scratch/qua662_done_symbols.txt` (36 symbols)
- Current staging symbols detected: `4`
- Missing from staging vs canonical: `36`
- Extra not in canonical: `4` (includes `XBRUSD` path family)

Interpretation:
- Current staging feed is not aligned with the canonical 36-symbol DWX cohort.
- D2 repair cannot complete from this staging state because the hourly importer gate exits before verify/import phases.

## Unblock owner/action

- owner: CTO + Pipeline-Operator
- action:
1. Restore canonical 36-symbol CSV/M1 staging set at `D:\QM\reports\setup\tick-data-timezone`.
2. Remove/segregate non-canonical staging artifacts (e.g. XBRUSD family).
3. Re-run hourly check and then re-run `verify_import.py` cohort until 21/21 repaired symbols pass.
