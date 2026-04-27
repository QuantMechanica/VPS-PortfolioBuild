# 2026-04-27 - QUA-91 WS30.DWX verifier failure investigation

Issue: `QUA-91` (DEVOPS-004 child)  
Parent context: `QUA-19` verifier re-run

## Scope

Investigate whether `WS30.DWX` `FAIL_tail_bars` is a WS30-specific import defect or a systemic verifier/runtime condition.

## Evidence

Source log: `infra/smoke/verify_import_run_2026-04-27_qua19.log`

Observed WS30 row (from the log):
- verdict: `FAIL_tail_bars`
- `mid_ticks_5min=1561` (non-zero)
- `bars expected=445,870/got=0`
- tail gap: ~`7143.924s`

Cross-symbol context in the same run:
- Every FAIL row shows `bars expected>0` with `bars got=0`.
- Multiple symbols have non-zero `mid_ticks_5min` (WS30, UK100, XTIUSD, etc.), so market feed visibility is not uniformly zero.
- This pattern indicates a shared verifier/runtime bars-read path failure rather than a WS30-only data corruption.

## Conclusion

`WS30.DWX` is **not isolated** in this run. The dominant failure mode is systemic (`bars got=0` across the board), with WS30 only one instance in that batch.

## Durable change in this heartbeat

- Added/extended tests for verifier fail-pattern classification in:
  - `infra/scripts/tests/test_dwx_hourly_check_readiness.py`
- Confirmed and documented the automated classifier contract in:
  - `infra/scripts/README.md`

Classifier contract used by `dwx_hourly_check.py`:
- `systemic_zero_bars`: >=10 FAIL rows with `bars expected>0` and `bars got=0`
- `systemic_zero_mid_ticks`: >=10 FAIL rows with `mid_ticks_5min=0`

## Next action

Run the next verifier pass under active market session and capture the same classifier signals. If `systemic_zero_bars` persists, escalate to verifier implementation owner for bars-read-path debugging (not symbol-level DWX repair).
