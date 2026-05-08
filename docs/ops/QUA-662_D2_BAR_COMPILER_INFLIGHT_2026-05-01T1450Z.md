# QUA-662 D2 bar-compiler inflight status (2026-05-01T14:50Z)

## Live execution evidence

Detected active v2 bar compilation script on T1:
- script log: `D:\QM\mt5\T1\MQL5\Files\compile_custom_bars_v2_20260501_115357.log`
- MT5 terminal log shows script loaded and not yet removed:
  - `script Compile_Custom_Bars_QM_v2 (EURUSD,M1) loaded successfully`

Current script progress lines:
- `[OK] AUDCAD.DWX ...`
- `[OK] AUDCHF.DWX ...`
- `[OK] AUDJPY.DWX ...`
- `[OK] AUDNZD.DWX ...`
- `[OK] AUDUSD.DWX ...`
- `[OK] CADCHF.DWX ...`
- `[OK] CADJPY.DWX ...`

## Mid-run verification probes

- `verify_import.py --symbol CADJPY.DWX` now reports non-zero `bars_from_pos` (`4440`) where prior state was effectively zero-access on bars.
- `CADJPY.DWX` `.hcc` folder now contains multi-year files (`2017..2024` + `2026` stub), indicating bar compilation is materially progressing.

## Current gate state

- DL-054 Gate 1 remains FAIL while compiler run is incomplete.
- Do not relaunch baseline until compiler finishes and full verifier pass is recorded.

## Next action

1. Wait for `Compile_Custom_Bars_QM_v2` completion marker in log (`done: ...`).
2. Immediately run full `verify_import.py` on all canonical symbols.
3. Record post-run pass/fail deltas and decide whether D2 can be closed.
