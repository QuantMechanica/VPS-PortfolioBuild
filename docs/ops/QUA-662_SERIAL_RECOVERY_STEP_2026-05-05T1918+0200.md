# QUA-662 serialized recovery step — 2026-05-05T19:18+02:00

## Action taken

- Ran one-symbol recovery for `EURNZD.DWX` on `T1`.

Command:
- `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols EURNZD.DWX --terminal T1 --year 2024 --runs 2 --out-prefix D:\QM\reports\pipeline --timeout 1800`

## Outcome

- Fast `INVALID` path with explicit contention error:
  - `no_summary_json:rc=1`
  - stderr includes `run_smoke.ps1` throw: "Terminal instance is already running ..."
- Auto-appended row:
  - `1003,P2,EURNZD.DWX,T1,INVALID,no_summary_json:rc=1,`

## Progress delta

- `report.csv` lines: `28 -> 29`
- Canonical coverage: `19/36 -> 20/36`
- Remaining canonical symbols: `16`

## Operational note

- Terminal contention became explicit in this step; runner is competing with already-running terminal instances.

## Next action

- Continue serialized one-symbol recovery on remaining symbols while preserving contention errors as distinct invalidation evidence.
