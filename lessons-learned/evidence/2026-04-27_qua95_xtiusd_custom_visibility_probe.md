# 2026-04-27 - QUA-95 custom-symbol visibility probe (automated)

Issue: `QUA-95`  
Target: `XTIUSD.DWX`

## Command

```powershell
python C:\QM\repo\infra\scripts\probe_custom_symbol_visibility.py --target XTIUSD.DWX --json-out C:\QM\repo\lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe.json
```

## Output

```text
target=XTIUSD.DWX source=XTIUSD isolated_custom_bars_visibility_failure=True
target bars(range/pos)=0/0 source bars(range/pos)=260/10
```

## Interpretation

- The probe classifies this as an isolated custom-symbol bars visibility failure.
- In the same runtime session, source bars are available while custom bars are not.
- This confirms `QUA-95` should remain blocked on custom-symbol/runtime recovery, not broker feed availability.
