# QUA-1540 Evidence Receipt (2026-05-15T04:54Z)

## Commands
- `python C:/QM/repo/framework/scripts/mt5_saturation_evidence_once.py --sqlite D:/QM/reports/pipeline/mt5_queue.db --dispatch-state D:/QM/Reports/pipeline/dispatch_state.json --out D:/QM/reports/pipeline/mt5_saturation_evidence_once_20260515_0454Z.json`
- `python C:/QM/repo/framework/scripts/mt5_queue_status.py --sqlite D:/QM/reports/pipeline/mt5_queue.db --limit 5`

## Results
- Evidence bundle status: `ok`
- Evidence artifact: `D:/QM/reports/pipeline/mt5_saturation_evidence_once_20260515_0454Z.json`
- Queue snapshot: `counts={"dispatched":1}`, `queued_top=[]`, latest dispatched row remains `QM5_1003 P2 EURUSD.DWX -> T2`.
