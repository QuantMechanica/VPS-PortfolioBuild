# 2026-04-27 - QUA-94 XNGUSD.DWX verifier failure investigation

Issue: `QUA-94` (DEVOPS-004 child)  
Parent context: `QUA-19` verifier re-run

## Scope

Investigate whether `XNGUSD.DWX` `FAIL_tail_mid_bars` indicates XNGUSD-specific DWX corruption or a systemic verifier/runtime failure.

## Evidence

Source log: `infra/smoke/verify_import_run_2026-04-27_qua19.log`

Observed `XNGUSD.DWX` row:
- verdict: `FAIL_tail_mid_bars`
- `mid_ticks_5min=0`
- `bars expected=383,654/got=0`
- tail missing (`tail_ms .../got=0`)
- source/contract fields aligned (`custom_tv=10.0`, `broker_tv=10.0`, `rel_err=0.0000`)

Cross-symbol context in the same run:
- Parsed fail rows: `56`
- Classifier verdict: `systemic_zero_bars=True`, `systemic_zero_mid_ticks=False`
- Every parsed FAIL row has `bars expected>0` with `bars got=0`.
- Mixed `mid_ticks_5min` across symbols (for example `WS30=1561`, `XTIUSD=997`, `XAGUSD=255`, others `0`), which indicates bars-read/runtime path failure rather than a single-symbol XNG defect.

## Conclusion

`XNGUSD.DWX` is **not isolated** in this verifier pass. The dominant signature is systemic verifier/runtime bars-read failure, not XNG-specific data corruption.

## Follow-up rerun (same day)

Rerun command executed:

```powershell
python D:\QM\mt5\T1\dwx_import\verify_import.py
```

Captured output:
- `infra/smoke/verify_import_run_2026-04-27_085826_qua94_rerun.log`
- process exit code: `1`
- fail rows observed: `56`
- `XNGUSD.DWX` row remained:
  - verdict: `FAIL_tail_mid_bars`
  - `tail_ms expected=1775444289019/got=0`
  - `mid_ticks_5min=0`
  - `bars expected=383,654/got=0`

Disposition after rerun:
- `QUA-94` is **not cleared**.
- This remains a verifier/runtime read-path failure class, not symbol-level XNG import damage.

## Structured disposition artifact

Automated rerun + classification command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-VerifyDisposition.ps1 -IssueId QUA-94 -Symbol XNGUSD.DWX
```

Generated evidence:
- `lessons-learned/evidence/2026-04-27_qua94_xngusd_rerun_evidence.json`
- `disposition=defer`
- `verify_exit_code=1`
- classifier: `fail_count=56`, `systemic_zero_bars=true`, `systemic_zero_mid_ticks=false`
- symbol payload confirms `XNGUSD.DWX` remained `FAIL_tail_mid_bars` with `bars_got=0` and `tail_ms_got=0`

Additional root-cause probe:
- `lessons-learned/evidence/2026-04-27_qua94_rates_probe.md`
- `XNGUSD.DWX` stayed at `oneshot_count=0`, `chunked_count=0`, `tail_window_count=0` even with chunked/day windows.
- Comparator `WS30.DWX` returned partial chunked bars (`100,251`), so the runtime read-path issue is not perfectly uniform across symbols.

## Durable change in this heartbeat

- Added this investigation record for `QUA-94` with concrete row-level evidence and batch classifier context.
- Added parser regression test coverage for a real `XNGUSD.DWX` verifier line in:
  - `infra/scripts/tests/test_dwx_hourly_check_readiness.py`
- Updated parser contract notes in:
  - `infra/scripts/README.md`

## Next action

Blocked on verifier owner action:
- Unblock owner: verifier implementation owner (`verify_import.py` runtime path)
- Required unblock action: add MT5 session pre-flight hardening (`symbol_select` confirmation + bars warm-up/retry before `copy_rates_range`) plus chunked fallback, and provide a rerun log where `XNGUSD.DWX` has non-zero `bars got` and non-zero tail sample.
