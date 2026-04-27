# QUA-95 Direct Verifier Rerun Proof (2026-04-27)

Issue: QUA-95  
Symbol: XTIUSD.DWX

## Command

```powershell
python D:\QM\mt5\T1\dwx_import\verify_import.py --symbol XTIUSD.DWX
```

## Result

- exit code: 1
- verdict: FAIL_tail_bars
- tail delta ms: -7141322
- tail shortfall seconds: 7141.322
- mid ticks (5m): 997
- bars one-shot: 0
- bars chunked: 0
- bars expected accessible: 100000
- bars drift: -100
- raw log: C:\QM\repo\infra\smoke\verify_import_direct_2026-04-27_130536_qua95.log
- captured at: 2026-04-27T13:05:37+02:00

## Disposition

Acceptance remains unmet; state stays blocked/defer.
