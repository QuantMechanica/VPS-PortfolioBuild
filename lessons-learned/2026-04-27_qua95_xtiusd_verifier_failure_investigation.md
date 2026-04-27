# 2026-04-27 - QUA-95 XTIUSD.DWX verifier failure investigation

Issue: `QUA-95` (DEVOPS-004 child)  
Parent context: `QUA-19` verifier re-run  
Recommended issue state: `blocked` (pending verifier implementation hardening)

## Scope

Determine whether `XTIUSD.DWX` `FAIL_tail_bars` is XTI-only corruption or part of the systemic verifier/runtime bars-read failure class.

## Evidence

Source log (parent rerun): `infra/smoke/verify_import_run_2026-04-27_qua19.log`

Observed `XTIUSD.DWX` row:
- verdict: `FAIL_tail_bars`
- `mid_ticks_5min=997` (non-zero)
- `bars expected=443,430/got=0`
- tail gap: `7141.322s`
- source/contract fields aligned (`custom_tv=10.0`, `broker_tv=10.0`, `rel_err=0.0000`)

Cross-symbol context in the same run:
- Parsed FAIL rows: `56`
- Classifier verdict: `systemic_zero_bars=True`, `systemic_zero_mid_ticks=False`
- FAIL rows across FX, indices, and commodities all show `bars expected>0` with `bars got=0`.
- Mixed `mid_ticks_5min` values (for example `WS30=1561`, `UK100=2834`, `XAGUSD=255`, many symbols `0`) indicate a shared runtime/read-path failure, not XTI-only data damage.

## Rerun Evidence (2026-04-27 09:09 CEST)

Structured rerun command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-VerifyDisposition.ps1 -IssueId QUA-95 -Symbol XTIUSD.DWX
```

Generated artifacts:
- raw log: `infra/smoke/verify_import_run_2026-04-27_090942_qua95.log`
- evidence JSON: `lessons-learned/evidence/2026-04-27_qua95_xtiusd_rerun_evidence.json`
- `verify_exit_code=1`
- classifier: `fail_count=56`, `systemic_zero_bars=true`, `systemic_zero_mid_ticks=false`
- disposition: `defer`

`XTIUSD.DWX` in rerun artifact:
- verdict: `FAIL_tail_bars`
- `mid_ticks_5min=997`
- `bars expected=443,430/got=0`
- `tail_ms expected=1775444399967/got=1775437258645` (shortfall `7141.322s`)

## Conclusion

`XTIUSD.DWX` is not a cleared symbol-level import issue in this heartbeat. It remains within the broader verifier/runtime bars-read failure class.

## Durable change in this heartbeat

- Ran an idempotent verifier rerun + classifier for `QUA-95` via `Invoke-VerifyDisposition.ps1`.
- Added archived evidence artifacts (raw log + structured JSON).
- Added this investigation report for traceable issue-level disposition.

## Final Disposition

- `defer`

## Next action

Unblock owner: verifier implementation owner (`D:\QM\mt5\T1\dwx_import\verify_import.py`).  
Required action: implement runtime hardening (`symbol_select` pre-flight, bars warm-up/retry, chunked fallback for range reads), then rerun until `XTIUSD.DWX` shows `bars_got > 0` with aligned tail.
