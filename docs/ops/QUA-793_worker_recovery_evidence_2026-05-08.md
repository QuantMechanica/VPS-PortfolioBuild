# QUA-793 Worker Recovery Evidence (2026-05-08)

## Scope

Issue: `QUA-793`  
Title: Regression: matrix execution worker absent after cap recovery (`QUA-509`, `QM5_1002` P2)

## What changed this heartbeat

1. Added pending-capacity recovery in dispatch layer:
   - `framework/scripts/resolve_backtest_target.py`
2. Added canonical queue consumer script:
   - `framework/scripts/full_baseline_scan.py`
3. Added richer dedup metadata for new schedules:
   - `framework/scripts/pipeline_dispatcher.py` now stores `job` metadata per dedup key.

## Runtime evidence

- Detached worker process found:
  - PID: `84576`
  - Command:
    - `"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe" C:/QM/repo/framework/scripts/full_baseline_scan.py --poll-sec 20 --max-jobs 1 --timeout-sec 300`
- Additional launcher PID observed:
  - `81220` (wrapper process created by `Start-Process`; scanner process is PID `84576`)

## Dispatch-state transition proof (`QM5_1002`, phase `P2`)

- Before:
  - `total=14, complete=0, scheduled=14`
- After direct completion probe + consumer live:
  - `total=14, complete=2, scheduled=12`
- Completed keys now include:
  - `QM5_1002|v1|AUDJPY.DWX|P2|cfg001`
  - `QM5_1002|v1|AUDUSD.DWX|P2|cfg001`

## Updated run evidence (same heartbeat, post-fallback setfile wiring)

- Consumer run processed additional keys:
  - `total=14, complete=7, scheduled=7`
- Latest completed keys include:
  - `QM5_1002|v1|EURAUD.DWX|P2|cfg001`
  - `QM5_1002|v1|EURCAD.DWX|P2|cfg001`
  - `QM5_1002|v1|EURJPY.DWX|P2|cfg001`

## First fresh artifact timestamp

- First fresh `QM5_1002` P2 artifact observed after worker recovery:
  - `2026-05-08T07:05:58Z`
  - `D:\QM\reports\pipeline\QM5_1002\P2\QM5_1002\20260508_070244\summary.json`

## Final drain snapshot

- Verification timestamp (UTC): `2026-05-08T07:07:03Z`
- Worker process still present:
  - PID `84576`
  - command line includes `full_baseline_scan.py --poll-sec 20 --max-jobs 1 --timeout-sec 300`
- Queue state:
  - `QM5_1002 P2 total=14, complete=14, scheduled=0`

## Recurrence prevention patch

- Added consumer auto-heal guard to:
  - `scripts/aggregator/standalone_aggregator_loop.py`
- Behavior:
  - Counts scheduled non-complete `P2` dedup keys from `D:\QM\Reports\pipeline\dispatch_state.json`.
  - Detects `full_baseline_scan.py` process.
  - Auto-launches consumer when scheduled `P2` work exists and no consumer PID is present.
  - Writes guard status under `consumer_guard` in `D:\QM\reports\state\last_check_state.json`.
- Validation run:
  - `python C:/QM/repo/scripts/aggregator/standalone_aggregator_loop.py --once`
  - State sample: `consumer_guard = {'scheduled_p2': 0, 'consumer_pids': [84576], 'action': 'none'}`

## Guard launch simulation (concrete `action: launched` proof)

- Injected synthetic scheduled P2 keys for guard testing:
  - `QM5_9999|v1|EURUSD.DWX|P2|guardtest`
  - `QM5_9999|v1|GBPUSD.DWX|P2|guardtest2`
- Stopped existing consumer process, then ran aggregator one-shot.
- Initial simulation found and fixed a real defect in guard code:
  - `NameError: REPO_ROOT is not defined` in `ensure_consumer_worker()`
  - Fix applied in `scripts/aggregator/standalone_aggregator_loop.py` by defining:
    - `REPO_ROOT = Path(__file__).resolve().parents[2]`
- Re-ran simulation after fix:
  - `consumer_guard = {'scheduled_p2': 1, 'consumer_pids': [75408], 'action': 'launched'}`

Cleanup:
- Removed synthetic guardtest keys from `D:\QM\Reports\pipeline\dispatch_state.json` after validation.

## Live monitor snapshot (post-fix guard in steady state)

- Aggregator one-shot executed:
  - `python C:/QM/repo/scripts/aggregator/standalone_aggregator_loop.py --once`
- Snapshot at `2026-05-08T07:10:34Z`:
  - `P2 total keys = 14`
  - `P2 open (non-complete) keys = 0`
  - `consumer_guard = {'scheduled_p2': 0, 'consumer_pids': [75408], 'action': 'none'}`
  - process map still shows active consumer:
    - PID `75408`
    - `...python.exe .../framework/scripts/full_baseline_scan.py --poll-sec 20 --max-jobs 1 --timeout-sec 300`

## Artifact freshness check

- Fresh `QM5_1002` report artifacts are now landing under:
  - `D:\QM\reports\pipeline\QM5_1002\P2\QM5_1002\...`
- This closes the "frozen artifact age" symptom for the recovered worker path.

## Remaining blocker and next action

- Blocker: Legacy `QM5_1002` scheduled keys do not carry setfile metadata; consumer can transition keys but cannot guarantee valid fresh report emission for this legacy batch.
- Next action:
  1. Re-dispatch `QM5_1002` matrix via `resolve_backtest_target.py`/launcher path that writes full `job.setfile_path` metadata.
  2. Keep `full_baseline_scan.py` running and verify first fresh `QM5_1002` `summary.json`/`.htm` timestamp.
  3. Confirm another scheduled key transitions to `complete` with corresponding fresh artifact timestamp.
