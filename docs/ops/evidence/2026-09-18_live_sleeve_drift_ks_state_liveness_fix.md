# live_sleeve_drift: ks_state mtime as a second liveness signal (task cc807c1b)

Task: `cc807c1b-8c34-4584-9a94-0c2c1afbab7a` (fable-hourly-watch-2026-09-18).

## Defect

`live_sleeve_drift_monitor.eval_heartbeat` derived liveness solely from the
per-EA JSONL logger's last line (`ts_utc`). Same pattern as the known-dark
12778/12969/13117 false alarms: a VPS reboot on 2026-09-11 orphaned the file
handle for `QM5_1567_ea-1567.log` (last write 2026-09-11 21:51), so the logger
never appended again even though the EA kept running on chart -- confirmed by
`halt/ks_state_1567_15670007.state` updated 2026-09-17 23:04. The monitor
raised `ALARM_SILENT` on a logger gap, not a dead sleeve.

## Fix (GRUEN, monitor-side only; no T_Live change)

`tools/strategy_farm/live_sleeve_drift_monitor.py`:
- Added `ks_state_file_mtime(ea_log_dir, ea_id, magic)`: stats
  `QM\halt\ks_state_<ea_id>_<magic>.state` (path convention from
  `QM_KillSwitch.mqh:499-500`, already relied on by
  `account_governor_halt_executor.py`). `QM_KillSwitchCheck` runs on every
  `OnTick` and calls `QM_KillSwitchRefreshBrokerDay`, which rewrites this file
  once per broker-day boundary (`QM_KillSwitch.mqh:258-276`) -- an
  independent, cheap liveness proof that does not depend on the JSONL logger.
- `eval_heartbeat` now takes the more recent of `last_log_line` and
  `ks_state_mtime` as the effective heartbeat, records which one won in
  `heartbeat.liveness_source` (`ea_log` | `ks_state_mtime`), and only raises
  `ALARM_SILENT` if that combined signal is stale beyond
  `HEARTBEAT_SILENT_TRADING_DAYS`. A missing EA log still raises
  `WARN_NO_EA_LOG` independently (folded through `_severity_of`, so it never
  silently disappears).
- `_alarm_detail` and `render_markdown` surface `ks_state_mtime` /
  `liveness_source` so a human reviewing an `ALARM_SILENT` row can see which
  signal was used (`*` marker + footnote in the markdown table).
- No change to any other metric, threshold, or the read-only/T_Live contract.

Rejected: fix (b) from the task payload (investigate why the per-EA file
logger does not resume after a terminal restart / reopen the handle in
`OnInit`) touches the live EA's MQL5 logging and would require a T_Live
recompile + redeploy with a Fable receipt -- out of scope for a GRUEN
monitor-only change.

## Test evidence

`tools/strategy_farm/tests/test_live_sleeve_drift_monitor.py`, run:

```
python -m pytest tools/strategy_farm/tests/test_live_sleeve_drift_monitor.py -q
15 passed in 0.64s
```

New tests:
- `test_ks_state_file_mtime_reads_stat` -- stat-based mtime read, `None` on
  missing magic / missing file.
- `test_ks_state_mtime_prevents_false_alarm_silent_after_reboot` -- reuses the
  existing SILENT fixture (9003/USDJPY, stale log since 2026-09-08) and adds a
  fresh `ks_state_9003_90030000.state`; asserts `ALARM_SILENT` no longer
  fires, `liveness_source == "ks_state_mtime"`, and the sleeve drops out of
  `summary.silent`.
- `test_eval_heartbeat_still_alarms_when_both_signals_stale` -- guards against
  the ks_state signal itself going stale (no permanent bypass).

All 12 pre-existing tests in the file still pass unchanged, including
`test_end_to_end_alarm_classes`'s `ALARM_SILENT` assertion for 9003 (no
ks_state file present in that fixture run, so behaviour is unchanged when the
new signal is absent).

## Scope / hard-rule compliance

- Read-only contract preserved: only stats a file under
  `C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\halt\`, never opens/writes it.
- No T_Live, EA, or gate-threshold change; monitor still exits 0 unconditionally.
- Left in REVIEW per the Gemini/Claude build-lane contract; not self-approved,
  not moved to PIPELINE, no merge to `main`.

Files changed: `tools/strategy_farm/live_sleeve_drift_monitor.py`,
`tools/strategy_farm/tests/test_live_sleeve_drift_monitor.py`.
