# QUA-95 Direct Verifier Rerun Proof (2026-04-27)

Issue: QUA-95  
Symbol: XTIUSD.DWX

## Command

```powershell
python D:\QM\mt5\T1\dwx_import\verify_import.py --symbol XTIUSD.DWX --tail-basis source --tail-tol-ms 1000
```

## Result

- exit code: 1
- verdict: FAIL_spec
- tail delta ms: -323
- tail shortfall seconds: 0.323
- mid ticks (5m): 997
- bars one-shot: 0
- bars chunked: 99911
- bars expected accessible: 100000
- bars drift: -89
- raw log: C:\QM\repo\infra\smoke\verify_import_direct_2026-04-27_151718_qua95.log
- captured at: 2026-04-27T15:17:19+02:00

## Disposition

Acceptance remains met; state stays clear/clear.
