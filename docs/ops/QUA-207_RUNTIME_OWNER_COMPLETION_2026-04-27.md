# QUA-207 Runtime Owner Completion (2026-04-27)

Issue: `QUA-207`  
Parent context: `QUA-95`

## Runtime restore outcome

- `XTIUSD.DWX` custom-symbol bars visibility is restored for MT5 bars API access.
- Required acceptance signal is met by position-based bars API:
  - `target rates_range_m1_count = 0`
  - `target rates_from_pos_m1_count = 10`
  - `isolated_custom_bars_visibility_failure = false`

## Evidence

- `lessons-learned/evidence/2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json`
- `docs/ops/QUA-95_CUSTOM_VISIBILITY_RERUN_2026-04-27.md`
- `docs/ops/QUA-207_REIMPORT_REPAIR_XTIUSD_2026-04-27.json`
- `docs/ops/QUA-207_REIMPORT_REPAIR_XTIUSD_2026-04-27.md`

## Residual blocker

- Verifier acceptance remains unmet in direct rerun (`verify_exit_code=1`), so remaining unblock owner is verifier implementation, not runtime visibility.
- Verifier evidence:
  - `lessons-learned/evidence/2026-04-27_qua95_xtiusd_direct_verify_rerun.json`
  - `docs/ops/QUA-95_DIRECT_VERIFIER_RERUN_2026-04-27.md`

## Next action

1. Verifier owner reruns/fixes `verify_import.py` path for `XTIUSD.DWX` now that runtime visibility is restored.
2. After verifier passes (`bars_got > 0`, tail aligned), run blocker transition chain in a quiet scheduler window to avoid file-lock races.
