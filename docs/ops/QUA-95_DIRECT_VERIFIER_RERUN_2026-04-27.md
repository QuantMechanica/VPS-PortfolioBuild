# QUA-95 Direct Verifier Rerun Proof (2026-04-27)

Issue: QUA-95  
Symbol: XTIUSD.DWX

## Command

```powershell
python D:\QM\mt5\T1\dwx_import\verify_import.py --symbol XTIUSD.DWX
```

## Result

- exit code: 1
- verdict: FAIL_tail_mid_bars_spec
- tail delta ms: 
- tail shortfall seconds: 
- mid ticks (5m): 0
- bars one-shot: 0
- bars chunked: 0
- bars expected accessible: 100000
- bars drift: -100
- raw log: C:\QM\repo\infra\smoke\verify_import_direct_2026-04-27_145219_qua95.log
- captured at: 2026-04-27T14:52:19+02:00

## Disposition

Acceptance remains unmet; state stays blocked/defer.
