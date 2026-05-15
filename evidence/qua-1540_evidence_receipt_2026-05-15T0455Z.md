# QUA-1540 Evidence Receipt (2026-05-15T04:55Z)

## Commands
- `python -m unittest framework.scripts.tests.test_mt5_saturation_evidence_once framework.scripts.tests.test_mt5_queue_status framework.scripts.tests.test_mt5_queue_enqueue framework.scripts.tests.test_mt5_saturation_scheduler`
- `python C:/QM/repo/framework/scripts/mt5_saturation_evidence_once.py --sqlite D:/QM/reports/pipeline/mt5_queue.db --dispatch-state D:/QM/Reports/pipeline/dispatch_state.json --out D:/QM/reports/pipeline/mt5_saturation_evidence_once_20260515_0455Z.json`
- `python C:/QM/repo/framework/scripts/mt5_queue_status.py --sqlite D:/QM/reports/pipeline/mt5_queue.db --limit 5`

## Results
- Tests: `Ran 6 tests`, `OK`
- Evidence artifact: `D:/QM/reports/pipeline/mt5_saturation_evidence_once_20260515_0455Z.json` (`status=ok`)
- Queue snapshot: `counts={"dispatched":1}`, `queued_top=[]`, latest dispatched remains `QM5_1003 P2 EURUSD.DWX -> T2`.
