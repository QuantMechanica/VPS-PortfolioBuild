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

## Targeted API Probe (2026-04-27 09:00 CEST)

Direct MT5 probe for `XAUUSD.DWX` with explicit warm-up/retries showed:
- `copy_ticks_from(...)` returns data at head, mid, and tail windows (non-zero ticks).
- `copy_ticks_range(...)` with datetime windows (as used by current verifier) returns zero in the same windows.
- `copy_rates_range(...)`, `copy_rates_from(...)`, and `copy_rates_from_pos(...)` all return zero M1 bars for this symbol in this runtime.

Implication:
- The verifier currently over-classifies this as tail/mid data loss because it relies on `copy_ticks_range(...)`.
- `bars got=0` appears to be an MT5 runtime/bar-build visibility condition for these custom symbols, not proof that tick history is absent.

## Durable change in this heartbeat

- Added this investigation record for `QUA-93` with concrete classifier output and triage conclusion.
- Updated `infra/scripts/README.md` with a one-command local triage probe for captured verifier logs.
- Performed and captured a fresh verifier rerun to validate whether the condition self-cleared (it did not).
- Added MT5 API-level diagnostic evidence to narrow implementation fix scope.

## Next action

Acceptance target (`XAUUSD` non-zero bars + matching tail) remains unmet after rerun.  
Unblock owner: verifier implementation owner (`D:\QM\mt5\T1\dwx_import\verify_import.py`).  
Required action:
- replace tail/mid probes with `copy_ticks_from(...)` window checks (not `copy_ticks_range(...)`);
- add retry + reconnect pre-flight around MT5 reads;
- make bar checks optional/degraded when MT5 returns zero bars for custom symbols despite non-zero tick probes, then rerun verification.
