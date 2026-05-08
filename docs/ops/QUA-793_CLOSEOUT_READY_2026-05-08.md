# QUA-793 Closeout Ready (2026-05-08)

Issue: `QUA-793`  
Title: Regression: matrix execution worker absent after cap recovery (QUA-509 QM5_1002 P2)

## Final verification snapshot

- Verification time (UTC): `2026-05-08T07:11:47Z`
- `QM5_1002` P2 key state:
  - total keys: `14`
  - open (non-complete): `0`
- Consumer process:
  - PID `75408`
  - command line includes:
    - `...python.exe .../framework/scripts/full_baseline_scan.py --poll-sec 20 --max-jobs 1 --timeout-sec 300`
- Aggregator guard telemetry (refreshed with one-shot run):
  - `consumer_guard = {'scheduled_p2': 0, 'consumer_pids': [75408], 'action': 'none'}`

## Required fix checklist status

1. Restore canonical queue consumer from dispatch_state -> terminal runs + artifacts: **MET**
   - Worker added and running: `framework/scripts/full_baseline_scan.py`
2. Post PID + command line + first new report timestamp: **MET**
   - PID/command captured in evidence
   - first fresh artifact timestamp captured:
     - `2026-05-08T07:05:58Z`
     - `D:\QM\reports\pipeline\QM5_1002\P2\QM5_1002\20260508_070244\summary.json`
3. Confirm at least one QM5_1002 P2 key transitions to complete: **MET**
   - observed progression to full drain: `14/14 complete`

## Recurrence prevention

- Guard added to `scripts/aggregator/standalone_aggregator_loop.py`:
  - detects scheduled P2 + missing consumer
  - auto-launches `full_baseline_scan.py`
  - reports `consumer_guard` telemetry in `last_check_state.json`
- Launch branch validated via simulation:
  - `consumer_guard.action = launched`

## Recommendation

`QUA-793` is ready to transition from `in_progress` to `done`.
