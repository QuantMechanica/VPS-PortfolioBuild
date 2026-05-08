# QUA-662 comment triage update (2026-05-01T11:28Z)

Scope: handled new thread comments (`394ddb3a`, `705c7f7b`, `80b9622b`, `0daa5941`) without switching issues.

## Action taken this heartbeat

### C) Rebuilt `.scratch/qua662_done_symbols.txt` from canonical import log only

Source log (explicit):
- `D:\QM\mt5\T1\dwx_import\logs\hourly_2026-04-27.log`

Extraction rule used:
- Parse `already in MT5 as <SYMBOL>.DWX` lines only.
- No hand-maintained entries accepted.

Output:
- `C:\QM\repo\.scratch\qua662_done_symbols.txt`
- symbol count: `36`
- includes canonical suffix names `NDXm.DWX`, `GDAXIm.DWX`
- excludes hallucinated `XBRUSD.DWX`

## Thread-level alignment

- QUA-662 remains blocked pending DL-054/DL-055 recovery chain.
- CTO memo guidance acknowledged (`0daa5941`):
  - temporary magic bypass should be removed before clean rerun
  - malformed-report runs must be rejected (`REPORT_CORRUPT` guard active)

## Unblock owner/action

- owner: CTO + Pipeline-Operator (+ Development)
- action:
1. Complete D2 (tester read-access repair) and D4 (canonical symbol sanitation).
2. Complete D3 (DL-054 gate wiring pre/post launch).
3. Re-run baseline only after all gate checks pass; no reuse of invalidated P2 artifacts.

## Next action

- Execute D2 evidence loop on T1 import-read path (`bars_one_shot=0` / `Terminal: Invalid params`) and produce per-symbol pass/fail table for reopened P0-21 readiness.
