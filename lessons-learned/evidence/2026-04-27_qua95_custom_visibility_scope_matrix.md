# 2026-04-27 - QUA-95 custom visibility scope matrix

Issue: `QUA-95`  
Probe tool: `infra/scripts/probe_custom_symbol_visibility.py`

## Command

```powershell
$symbols = @('XTIUSD.DWX','XNGUSD.DWX','XAUUSD.DWX','XAGUSD.DWX','WS30.DWX','EURUSD.DWX')
foreach($s in $symbols){
  python C:\QM\repo\infra\scripts\probe_custom_symbol_visibility.py --target $s --json-out C:\QM\repo\lessons-learned\evidence\tmp_probe_$($s.Replace('.','_')).json
}
```

Machine-readable output:
- `lessons-learned/evidence/2026-04-27_qua95_custom_visibility_scope_matrix.json`

## Results

| Symbol | Source | Isolated custom bars visibility failure | Target bars range/pos | Source bars range/pos |
|---|---|---:|---:|---:|
| `XTIUSD.DWX` | `XTIUSD` | `True` | `0 / 0` | `262 / 10` |
| `XNGUSD.DWX` | `XNGUSD` | `True` | `0 / 0` | `145 / 10` |
| `XAUUSD.DWX` | `XAUUSD` | `True` | `0 / 0` | `261 / 10` |
| `XAGUSD.DWX` | `XAGUSD` | `True` | `0 / 0` | `262 / 10` |
| `WS30.DWX` | `WS30` | `False` | `0 / 10` | `262 / 10` |
| `EURUSD.DWX` | `EURUSD` | `True` | `0 / 0` | `314 / 10` |

## Interpretation

- Failure class is broader than energies: multiple FX/metals/energy custom symbols have bars API visibility failure while source bars are healthy.
- `WS30.DWX` is a notable partial-exception where `copy_rates_from_pos` returns bars.
- This supports a runtime/custom-symbol visibility issue class with symbol-family variance, not broker feed outage.
