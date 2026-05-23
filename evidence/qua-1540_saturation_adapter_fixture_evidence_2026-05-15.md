# QUA-1540 Saturation Adapter Evidence (2026-05-15)

## Scope
Deterministic run-liveness proof for active adapter path `tools/ops/multi_ea_scheduler.py` using a controlled SQLite queue fixture.

## Command
`python C:/QM/paperclip/tools/ops/multi_ea_scheduler.py --once --sqlite C:/QM/repo/.scratch/qua1540/mt5_queue_fixture.db --dispatch-state C:/QM/repo/.scratch/qua1540/dispatch_state_fixture.json --state C:/QM/repo/.scratch/qua1540/scheduler_state_tick.json --evidence-out C:/QM/repo/.scratch/qua1540/mt5_saturation_scheduler_summary_fixture_live.json`

## Result
- scheduler_summary.status=`ok`
- scheduler_summary.dry_run=`false`
- queued_scanned=`2`
- scheduled=`2`
- queue_delta: `queued=-2`, `dispatched=+2`
- assigned terminals: `T1`, `T3`

## Artifacts
- `C:/QM/repo/.scratch/qua1540/mt5_saturation_scheduler_summary_fixture_live.json`
- `C:/QM/repo/.scratch/qua1540/mt5_queue_fixture.db`
- `C:/QM/repo/.scratch/qua1540/dispatch_state_fixture.json`
