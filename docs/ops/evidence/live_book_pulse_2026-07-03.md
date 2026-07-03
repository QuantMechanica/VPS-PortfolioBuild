# Live Book Pulse Evidence - 2026-07-03

Task: `72034a31-ba64-4383-9e1a-068519a0c2b6`

## Scope

Implemented a read-only live-book pulse monitor for `C:\QM\mt5\T_Live`. The
monitor reads terminal journals, `MQL5\Logs`, and QM EA JSON logs, then writes
only to:

- `D:\QM\reports\state\live_book_pulse.json`
- `D:\QM\reports\state\live_book_pulse.log`
- `D:\QM\strategy_farm\state\health_alarms.log` when alarms exist

It does not write under `T_Live`, does not start `terminal64.exe`, and does not
change AutoTrading.

## Files

- `tools/strategy_farm/live_book_pulse.py`
- `tools/strategy_farm/install_live_book_pulse_scheduled_task.ps1`

## Verification

- `python -m py_compile tools/strategy_farm/live_book_pulse.py`: PASS
- One-shot run: PASS
- Write guard: PASS. The monitor refused `--output-json C:\QM\mt5\T_Live\should_not_write.json` with `refusing to write inside live terminal tree`.
- Scheduled task install: PASS. `QM_StrategyFarm_LiveBookPulse` is registered as `SYSTEM`, state `Ready`, every 30 minutes.

## Final One-Shot Pulse

Source: `D:\QM\reports\state\live_book_pulse.json`

```json
{
  "generated_at_utc": "2026-07-03T06:38:40Z",
  "verdict": "OK",
  "account": "4000090541",
  "loaded_sleeves_from_terminal_journal": 13,
  "sleeves_from_ea_logs": 13,
  "terminal_positions": 1,
  "terminal_orders": 0,
  "experts_enabled_config": true,
  "heartbeat_minutes_since_last_journal_write": 55.43,
  "alarm_count": 0,
  "magic_registry": "C:\\QM\\repo\\framework\\registry\\magic_numbers.csv"
}
```

## Scheduled Task

```text
TaskName: QM_StrategyFarm_LiveBookPulse
UserId: SYSTEM
RunLevel: Highest
NextRunTime: 2026-07-03T09:00:00+02:00
Action: C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe "C:\QM\worktrees\codex-orchestration-1\tools\strategy_farm\live_book_pulse.py" --live-root "C:\QM\mt5\T_Live" --magic-csv "C:\QM\repo\framework\registry\magic_numbers.csv"
```

`RunNow` was not used during install; the direct one-shot run above provides the
validation sample.
