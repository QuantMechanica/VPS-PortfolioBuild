# PR-06 BacktestBaseline

Status: active (dry-run evidence mode, specs-blocked)
Owner: Pipeline-Operator
Updated: 2026-04-26

## Scope guard

- Until [QUA-15](/QUA/issues/QUA-15) and [QUA-16](/QUA/issues/QUA-16) are done, `.DWX` symbols are blocked for baseline claims.
- Dry-run validation must use native broker symbols only.
- This process page records infrastructure evidence only (not strategy PASS/FAIL judgement).

## Day-1 dry-run target

- Terminal: `T1` only
- Primary EA: `SM_345` on `EURUSD`
- Fallback EA: `SM_186` on `EURUSD` if primary fails for build/spec reasons
- Window: `2017-01-01` to `2022-12-31`
- Model: `4` (fixed risk)

## Evidence ledger

- Aggregator status: `not_operational` (see child issue for restore work)
- Report artifact: `D:\QM\reports\smoke_20260426` (`.htm` count = `0` in Day-1 dry-run)
- Journal/log artifact: `D:\QM\mt5\T1\logs\20260426.log` + `D:\QM\mt5\T1\Tester\logs\20260426.log`
- Filesystem vs tracker count check: `tracker_missing` (`last_check_state.json` not found on this host)
- Run note: `evidence/2026-04-26_qua14_t1_dryrun.md`

## Evidence Template (report chain)

- `report_export_mode`: `relative_report_plus_postcopy`
- Per run:
- `report_source_path`: MT5 terminal-local relative export result (for T1: `D:\QM\mt5\T1\<relative>.htm`)
- `report_canonical_path`: canonical evidence copy (`D:\QM\reports\smoke\<ea>\<run_tag>\raw\<run>\report.htm`)
- `report_size_bytes`: file size from canonical copy (must be `> 0`)

## Notes

- Verdict files may be `PASS_BASELINE`, `FAIL_BASELINE`, `NO_REPORT`, or `SETUP_DATA_*`.
- For missing/thin outputs, classify with byte-size check before any EA-weakness claim.
