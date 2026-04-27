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

## Follow-up probe evidence (same heartbeat)

Additional targeted probes were executed for `XTIUSD.DWX`:

```powershell
python C:\QM\repo\infra\scripts\verify_import_preflight_probe.py --symbol XTIUSD.DWX
python C:\QM\repo\infra\scripts\verify_import_chunked_probe.py --symbol XTIUSD.DWX --chunk-days 1 --json-out C:\QM\repo\lessons-learned\evidence\2026-04-27_qua95_xtiusd_chunked_probe.json
```

Observed:
- Preflight probe recovered expected tail via `copy_ticks_from(...)` (`tail_got_ms=1775444399967`) but still returned `bars_got=0`.
- Chunked probe showed `bars_oneshot_count=0` with `Invalid params`, and `bars_chunked_count=0` even across `467` chunks.
- Chunked probe also showed `source_tick_tail_got` and custom tail nearly equal (`custom_minus_source_tail_ms=-323ms`), which argues against XTI-only custom symbol corruption.

Probe artifacts:
- `lessons-learned/evidence/2026-04-27_qua95_xtiusd_probe.md`
- `lessons-learned/evidence/2026-04-27_qua95_xtiusd_chunked_probe.json`
- `lessons-learned/evidence/2026-04-27_qua95_xtiusd_source_vs_custom_api_probe.md`

Source-vs-custom API comparison (same terminal/session) additionally confirms:
- `XTIUSD` source symbol returns M1 bars (`rates_range_2d=257`, `rates_from_pos=10`).
- `XTIUSD.DWX` custom symbol returns zero/fail on bars APIs (`rates_range_2d=0`, `rates_from_pos=0` with `Terminal: Call failed`).
- Therefore the blocker is not broker source feed unavailability; it is custom-symbol/runtime bars visibility plus verifier handling.

## Durable change in this heartbeat

- Ran an idempotent verifier rerun + classifier for `QUA-95` via `Invoke-VerifyDisposition.ps1`.
- Added archived evidence artifacts (raw log + structured JSON).
- Added this investigation report for traceable issue-level disposition.
- Added targeted preflight/chunked probe artifacts that narrow the failure to verifier bars-read behavior.

## Final Disposition

- `defer`

## Next action

Unblock owner A: custom-symbol/runtime owner (T1 DWX state).  
Required action A: restore `XTIUSD.DWX` M1 bar visibility in terminal runtime (bars APIs returning non-zero).  

Unblock owner B: verifier implementation owner (`D:\QM\mt5\T1\dwx_import\verify_import.py`).  
Required action B: keep hardening (`symbol_select` pre-flight, bars warm-up/retry, chunked/alt-path diagnostics), then rerun until `XTIUSD.DWX` shows `bars_got > 0` with aligned tail.
