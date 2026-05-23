# P2 Real-Tick Pre-Screen Timeout Policy - 2026-05-22

Task: `a6a0679b-f4c3-4f7e-906c-9147673ff058`

## Verdict

Implemented farm-wide P2 timeout policy without changing the tester model or gate verdict semantics.

## Changes

- `tools/strategy_farm/farmctl.py`
  - Keeps P2 `Model=4` every real tick.
  - Adds a P2 pre-screen stage for canonical P2 work items:
    - one run
    - most recent six months inside the available P2 window (`YYYY.07.01` to `YYYY.12.31`)
    - 30-minute per-run timeout
  - If the pre-screen fails or is invalid, the work item records that result directly and does not launch the full run.
  - If the pre-screen passes, the work item is requeued for the canonical full P2 run.
  - Full P2 remains the canonical 2017-2022 range with two deterministic runs.
  - Full-run timeout is sized from the pre-screen runtime with deterministic-run and headroom multipliers, bounded to 7200-14400 seconds per tester run.
  - P2 active-row timeout is raised to 360 minutes so the dispatcher does not kill legitimate long real-tick full runs before the tester timeout can produce evidence.

- `framework/registry/tester_defaults.json`
  - Documents the P2 real-tick policy: Model 4, six-month pre-screen, canonical full-run window, and full-run timeout bounds.

- `tools/strategy_farm/tests/test_p2_prescreen_policy.py`
  - Covers the six-month pre-screen date window and full-timeout sizing bounds.

## Verification

- `python -m py_compile tools/strategy_farm/farmctl.py`
- `python -m json.tool framework/registry/tester_defaults.json`
- `python -m unittest tools.strategy_farm.tests.test_p2_prescreen_policy`

All focused checks passed.

## Notes

- No `T_Live` or AutoTrading changes.
- No manual `terminal64.exe` launch.
- Existing active T1-T10 backtests were not interrupted.
- Existing queued work items keep their current payloads; on next claim, canonical P2 rows without `p2_prescreen_done` will run the pre-screen first.
