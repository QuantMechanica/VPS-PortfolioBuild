# 2026-04-27 - QUA-93 XAUUSD.DWX verifier failure investigation

Issue: `QUA-93` (DEVOPS-004 child)  
Parent context: `QUA-19` verifier re-run

## Scope

Investigate whether `XAUUSD.DWX` `FAIL_tail_mid_bars` indicates symbol-specific DWX corruption or a systemic verifier/runtime failure.

## Evidence

Source log: `infra/smoke/verify_import_run_2026-04-27_qua19.log`

Observed XAU row (same run):
- verdict: `FAIL_tail_mid_bars`
- `mid_ticks_5min=0`
- `bars expected=446,753/got=0`
- tail read missing (`tail got=0`)

Cross-symbol context in the same run:
- Parsed fail rows: `56`
- Classifier verdict: `systemic_zero_bars=True`, `systemic_zero_mid_ticks=False`
- Every parsed FAIL row has `bars expected>0` with `bars got=0`
- Mixed `mid_ticks_5min` values across symbols (some zero, some non-zero), so market feed visibility is not uniformly absent.

## Conclusion

`XAUUSD.DWX` is **not isolated** in this verifier pass. The failure signature is dominated by a systemic bars-read/runtime condition, not an XAU-only data defect.

## Rerun Evidence (2026-04-27 08:55 CEST)

Fresh verifier run executed:
- command: `python D:\QM\mt5\T1\dwx_import\verify_import.py`
- log artifact: `infra/smoke/verify_import_run_2026-04-27_085514_qua93.log`
- exit code: `1`

Classifier output on the rerun artifact:
- `fail_count=56`
- `systemic_zero_bars=True`
- `systemic_zero_mid_ticks=False`

`XAUUSD.DWX` in rerun:
- verdict: `FAIL_tail_mid_bars`
- `mid_ticks_5min=0`
- `bars expected=446,753/got=0`
- `tail_ms expected=1775444399867/got=0`

## Durable change in this heartbeat

- Added this investigation record for `QUA-93` with concrete classifier output and triage conclusion.
- Updated `infra/scripts/README.md` with a one-command local triage probe for captured verifier logs.
- Performed and captured a fresh verifier rerun to validate whether the condition self-cleared (it did not).

## Next action

Acceptance target (`XAUUSD` non-zero bars + matching tail) remains unmet after rerun.  
Unblock owner: verifier implementation owner (`D:\QM\mt5\T1\dwx_import\verify_import.py`).  
Required action: add MT5 session pre-flight hardening (`symbol_select`/bars warm-up/retry) before per-symbol checks, then rerun verification.
