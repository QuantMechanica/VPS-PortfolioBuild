# 2026-04-27 - QUA-90 (DEVOPS-004 child) USDJPY.DWX verifier investigation

Issue: `QUA-90`  
Parent: `QUA-19` re-run (`verify_import.py`)  
Scope: investigate `USDJPY.DWX` failure signature and classify root cause.

## Evidence

- Source log: `infra/smoke/verify_import_run_2026-04-27_qua19.log`
- USDJPY row:

```text
[FAIL_tail_mid_bars] USDJPY.DWX: source=USDJPY; ... mid_ticks_5min=0; bars expected=446,627/got=0
```

- Same run shows the same `bars expected>0 / got=0` outcome across all observed FAIL rows, not only USDJPY.
- The failure set includes FX, indices, and commodities with identical bars outcome (`got=0`), which rules out a USDJPY-only import corruption hypothesis.

## Root-cause classification

- `USDJPY.DWX` is currently a **symptom** of a systemic verifier/runtime condition.
- Most likely failure class: verifier-side runtime data visibility (MT5 bars query context/session), not per-symbol data absence.

## Infra mitigation shipped

- Updated `infra/scripts/dwx_hourly_check.py` to parse `verify_import.py` output and emit systemic diagnostics when:
  - many FAIL rows are present, and
  - every FAIL row has `bars expected > 0` with `bars got = 0`.
- Added unit coverage in `infra/scripts/tests/test_dwx_hourly_check_readiness.py`.

This keeps child issue triage accurate: a global verifier/runtime failure should not be treated as isolated USDJPY data damage.

## Next action

- Re-run verifier in the next healthy session and confirm diagnostics behavior.
- If systemic-zero-bars repeats, patch `D:\QM\mt5\T1\dwx_import\verify_import.py` with MT5 session pre-flight (`symbol_select`/bars warm-up) before per-symbol checks.
