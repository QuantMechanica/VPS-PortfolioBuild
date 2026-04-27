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

## Durable change in this heartbeat

- Added this investigation record for `QUA-94` with concrete row-level evidence and batch classifier context.
- Added parser regression test coverage for a real `XNGUSD.DWX` verifier line in:
  - `infra/scripts/tests/test_dwx_hourly_check_readiness.py`
- Updated parser contract notes in:
  - `infra/scripts/README.md`

## Next action

Re-run verifier in a healthy market/session window. If `systemic_zero_bars` persists, escalate to verifier implementation owner for MT5 bars-read-path hardening (`symbol_select` + bars warm-up) before any symbol-level repair.
