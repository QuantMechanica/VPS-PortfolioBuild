# QUA-1541 Heartbeat Evidence - 2026-05-15T0513_CONSOLIDATED.md

## Scope
- Issue: `QUA-1541` (MT5 multi-EA saturation scheduler)
- Action: consolidated readiness snapshot (code diff + runtime health)

## Runtime Snapshot
Scheduler command:
```powershell
python C:\QM\paperclip\tools\ops\multi_ea_scheduler.py --once --recover-orphan-dispatched --orphan-dispatched-minutes 30
```
Result:
- `scheduler_summary.status=ok`
- `mt5_active_count_process=1`
- `live_terminals_from_process=["T1"]`
- `orphan_recovery.candidate_count=0`
- `orphan_recovery.recovered_count=0`
- `queue_counts_before={"dispatched":1}`
- `queue_counts_after={"dispatched":1}`

Queue snapshot:
```powershell
python C:\QM\repo\framework\scripts\mt5_queue_status.py --sqlite D:\QM\reports\pipeline\mt5_queue.db --limit 5
```
Result:
- `counts={"dispatched":1}`
- top dispatched row: `id=1 ea_id=QM5_1003 phase=P2 symbol=EURUSD.DWX assigned_terminal=T1 dispatch_decision=scheduled`

## Production Wiring Confirmation
`cron/hourly_status.bat` includes:
- `python multi_ea_scheduler.py --once --recover-orphan-dispatched --orphan-dispatched-minutes 30`
- `python C:\QM\repo\framework\scripts\mt5_queue_status.py --sqlite D:\QM\reports\pipeline\mt5_queue.db --limit 5`

Done-line now includes:
- `multi_ea_scheduler=<rc>` and `mt5_queue_status=<rc>`

## Next Action
- Move issue to review with this evidence chain unless additional acceptance criteria are requested.
