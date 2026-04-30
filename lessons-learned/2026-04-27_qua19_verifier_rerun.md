# 2026-04-27 - QUA-19 verifier re-run after DEVOPS-006 unblock

Issue: `QUA-19` (DEVOPS-004)  
Run date: 2026-04-27  
Command:

```powershell
python D:\QM\mt5\T1\dwx_import\verify_import.py
```

Evidence log:
- `infra/smoke/verify_import_run_2026-04-27_qua19.log`

## Summary

- Verifier exit code: `1` (failures present).
- Unique symbols observed in output: `35`.
- `OK` symbols: `0`.
- `FAIL` symbols: `35`.
- Failure signature is systemic, not isolated to one symbol family:
  - `bars expected=.../got=0` across all observed symbols.
  - Tail sample shortfall around `~7,140s` on many symbols.
  - Several symbols show `tail got=0` and `mid_ticks_5min=0`.

## Required six-symbol re-check (from QUA-19)

| symbol | verdict | tail shortfall | mid ticks (5m) | bars expected | bars got |
| --- | --- | --- | ---: | ---: | ---: |
| `USDJPY.DWX` | `FAIL_tail_mid_bars` | `7141.322s` | 0 | 446,627 | 0 |
| `WS30.DWX` | `FAIL_tail_bars` | `7143.924s` | 1561 | 445,870 | 0 |
| `XAGUSD.DWX` | `FAIL_tail_bars` | `7140.626s` | 255 | 446,113 | 0 |
| `XAUUSD.DWX` | `FAIL_tail_mid_bars` | n/a (`tail got=0`) | 0 | 446,753 | 0 |
| `XNGUSD.DWX` | `FAIL_tail_mid_bars` | n/a (`tail got=0`) | 0 | 383,654 | 0 |
| `XTIUSD.DWX` | `FAIL_tail_bars` | `7141.322s` | 997 | 443,430 | 0 |

## Child investigations opened

- `QUA-90` - USDJPY.DWX
- `QUA-91` - WS30.DWX
- `QUA-92` - XAGUSD.DWX
- `QUA-93` - XAUUSD.DWX
- `QUA-94` - XNGUSD.DWX
- `QUA-95` - XTIUSD.DWX

Each child records per-symbol observed values, likely cause, and recommendation.
