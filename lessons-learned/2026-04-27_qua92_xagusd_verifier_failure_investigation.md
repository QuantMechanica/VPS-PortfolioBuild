# 2026-04-27 - QUA-92 XAGUSD.DWX verifier failure investigation

Issue: `QUA-92` (DEVOPS-004 child)  
Parent context: `QUA-19` verifier re-run

## Scope

Determine whether `XAGUSD.DWX` `FAIL_tail_bars` indicates XAGUSD-specific import damage or a systemic verifier/runtime condition.

## Evidence

Source log: `infra/smoke/verify_import_run_2026-04-27_qua19.log`

Observed `XAGUSD.DWX` row:
- verdict: `FAIL_tail_bars`
- `mid_ticks_5min=255` (non-zero)
- `bars expected=446,113/got=0`
- tail gap: ~`7140.626s`
- source/contract fields aligned (`custom_tv=5.0`, `broker_tv=5.0`, `rel_err=0.0000`)

Cross-symbol context in the same run:
- FAIL rows across FX, indices, and commodities all show `bars expected>0` with `bars got=0`.
- Multiple symbols (WS30, UK100, XTIUSD, XAGUSD) have non-zero `mid_ticks_5min`.
- This pattern matches a shared verifier/runtime bars-read-path failure, not a single-symbol import defect.

## Conclusion

`XAGUSD.DWX` is a symptom of the same systemic verifier/runtime condition seen across the batch. Treat as runtime/read-path issue until disproven by a clean-session rerun.

## Durable change in this heartbeat

- Added parser regression coverage for a real `XAGUSD.DWX` verifier row in:
  - `infra/scripts/tests/test_dwx_hourly_check_readiness.py`
- Updated parser contract notes in:
  - `infra/scripts/README.md`

## Next action

- Re-run verifier under confirmed healthy market session.
- If `systemic_zero_bars` repeats, escalate to verifier implementation owner for MT5 bars-read-path debugging (`verify_import.py` pre-flight/warm-up), not symbol-level DWX data repair.
