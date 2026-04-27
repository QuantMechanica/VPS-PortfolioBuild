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

## Rerun Evidence (2026-04-27 08:56 CEST)

Fresh verifier run executed:
- command: `python D:\QM\mt5\T1\dwx_import\verify_import.py`
- log artifact: `infra/smoke/verify_import_run_2026-04-27_085623_qua92.log`
- exit code: `1`

Classifier output on the rerun artifact:
- `fail_count=56`
- `systemic_zero_bars=True`
- `systemic_zero_mid_ticks=False`

`XAGUSD.DWX` in rerun:
- verdict: `FAIL_tail_bars`
- `mid_ticks_5min=255`
- `bars expected=446,113/got=0`
- `tail_ms expected=1775444390467/got=1775437249841` (shortfall `7140.626s`)

## Durable change in this heartbeat

- Performed and captured a fresh verifier rerun for `QUA-92`.
- Updated this investigation record with concrete rerun diagnostics and current disposition.

## Next action

Acceptance target (`XAGUSD` non-zero bars + matching tail) remains unmet after rerun.  
Unblock owner: verifier implementation owner (`D:\QM\mt5\T1\dwx_import\verify_import.py`).  
Required action: add MT5 session pre-flight hardening (`symbol_select`/bars warm-up/retry) before per-symbol checks, then rerun verification.
