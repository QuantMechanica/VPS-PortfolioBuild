# QUA-95 Custom Visibility Probe Rerun (2026-04-27)

Issue: QUA-95  
Target: XTIUSD.DWX

## Command

```powershell
python C:\QM\repo\infra\scripts\probe_custom_symbol_visibility.py --target XTIUSD.DWX --json-out C:\QM\repo\lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json
```

## Result

- probe exit code: 1
- isolated custom bars visibility failure: True
- target bars (range/pos): 0/0
- source bars (range/pos): 557/10
- target ticks: 0
- source ticks: 200
- evidence json: C:\QM\repo\lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json
- captured at: 2026-04-27T14:35:34+02:00

## Disposition

Acceptance remains unmet; state stays blocked/defer.
