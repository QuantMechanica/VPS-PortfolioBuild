# Live Book Pulse Journal-Stale Calibration

Task: `4763e823-babe-45f2-a161-ad6077e0050a`

## Change

Updated `tools/strategy_farm/live_book_pulse.py` so the journal heartbeat matches
the observed T_Live cadence:

- The 120 minute stale-journal alarm now applies only when live exposure is open,
  using the max of terminal sync positions and EA trade-manager open entries.
- Flat-terminal liveness is checked through the MT5 network scan heartbeat
  (`scanning network finished`) with a 390 minute / 6.5 hour stale threshold.
- A separate `today_broker_journal_missing_after_first_scan` alarm fires when
  the broker-date journal file is absent after the first scheduled scan grace.
- Heartbeat alarms now emit distinct reason codes and metrics for journal stale,
  scan stale/missing, and missing today-log states.

No live terminal settings were changed. No `T_Live` or AutoTrading control was
touched. Verification outputs were written outside the live terminal tree.

## Verification

Focused unit tests:

```text
python -m pytest tools/strategy_farm/tests/test_live_book_pulse.py
7 passed in 0.20s
```

Read-only pulse run against `C:\QM\mt5\T_Live`:

```text
python tools/strategy_farm/live_book_pulse.py --output-json D:\QM\reports\state\live_book_pulse_codex_verify_20260704.json --append-log D:\QM\reports\state\live_book_pulse_codex_verify_20260704.log --no-alarm-log
```

Result:

```json
{
  "verdict": "OK",
  "alarms": [],
  "heartbeat": {
    "latest_journal_file": "C:\\QM\\mt5\\T_Live\\MT5_Base\\logs\\20260704.log",
    "latest_journal_write_utc": "2026-07-03T23:44:00Z",
    "minutes_since_last_journal_write": 40.69,
    "latest_network_scan": {
      "file": "C:\\QM\\mt5\\T_Live\\MT5_Base\\logs\\20260704.log",
      "file_write_utc": "2026-07-03T23:44:00Z",
      "ts_terminal": "2026-07-04T01:43:12.363000"
    },
    "minutes_since_last_network_scan_write": 41.5,
    "network_scan_age_source": "terminal_ts",
    "open_exposure_count": 4,
    "today_broker_log": "20260704.log",
    "today_broker_log_exists": true
  }
}
```
