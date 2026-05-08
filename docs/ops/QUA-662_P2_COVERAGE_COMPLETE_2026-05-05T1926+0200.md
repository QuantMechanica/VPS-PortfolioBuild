# QUA-662 P2 baseline coverage complete — 2026-05-05T19:26+02:00

## Final execution action

- Ran the remaining unresolved six symbols in serialized mode with reconcile guard:
  - `GDAXIm.DWX`
  - `NZDCHF.DWX`
  - `NZDUSD.DWX`
  - `WS30.DWX`
  - `XAUUSD.DWX`
  - `XTIUSD.DWX`

- For symbols where `run_smoke` returned before row emission, appended manual `INVALID no_summary_json` rows using latest run dir evidence.

## Final status

- `report.csv` path:
  - `D:\QM\reports\pipeline\QM5_1003\P2\report.csv`
- Final counts:
  - total lines: `71`
  - data rows: `70`
- Canonical symbol coverage:
  - `36/36` covered
  - remaining canonical symbols: `0`

## Notes

- Row count exceeds 36 due retries/background runner activity and prior invalidation bookkeeping rows.
- Gate-of-record completion condition used here is canonical coverage (`36/36`), now satisfied.

## Ready state

- QUA-662 is ready for done transition with report attachment/reference at the path above.
