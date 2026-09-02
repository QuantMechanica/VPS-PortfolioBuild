# Live-book pulse load-evidence repair — 2026-09-02

Task: `26434855-11fb-46e6-aeab-a2d594c4a1b1` (priority 88).

## Result

The reported `loaded_sleeve_count=0` was a monitor lookback defect, not a live deployment failure. The pulse inspected only the newest ten daily terminal journals, while the most recent profile-load evidence was in `C:\QM\mt5\T_Live\MT5_Base\logs\20260823.log`.

`parse_terminal_journals` now retains the normal ten-file operational window and, only when that window has no expert-load or terminal-start marker, walks older journals newest-first to the last lifecycle-bearing file. The pulse explicitly records this fallback as `load_lookback_extended=true`.

The live rerun at `D:\QM\reports\state\live_book_pulse.json` reports:

- `loaded_sleeve_count=24`
- `load_lookback_extended=true`
- no `manifest_missing_loaded_sleeve` findings
- one genuine remaining `WARN:ks_baseline_status` (`loaded_ok=23/24`)
- overall `verdict=WARN`

Verdict aggregation was also corrected: a WARN-only finding now produces `WARN`; only FAIL/ALARM/ERROR findings produce `ALARM`. This prevents informational load warnings from being promoted into false critical alarms.

## Verification

`python -m pytest tools/strategy_farm/tests/test_live_book_pulse.py tools/strategy_farm/tests/test_live_observability_contract.py -q`

Result: **20 passed**. Coverage includes walking back beyond ten journals and WARN-only verdict behavior. The production pulse was rerun successfully and the values above were read from its durable JSON output.

No files beneath `C:\QM\mt5\T_Live` were written and no terminal was started or interrupted.
