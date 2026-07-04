# Live Book Pulse Cadence Fix - 2026-07-04

Task: `4763e823-babe-45f2-a161-ad6077e0050a`

## Scope

Calibrated `tools/strategy_farm/live_book_pulse.py` so the T_Live terminal
journal heartbeat matches the observed 6-hour scan cadence while keeping tight
monitoring when the live book is exposed.

The pulse now:

- keeps the 120-minute journal-stale rule only when terminal sync reports open positions;
- uses a 450-minute journal threshold for flat/no-scan fallback;
- parses `scanning network finished` and alarms when that scan heartbeat is older than 390 minutes;
- alarms if the current broker-date journal is missing after the 01:50 local first-scan due point;
- emits structured heartbeat alarm details and scan age into the pulse JSON/append log.

No T_Live files were written, no terminal process was started, and AutoTrading
was not changed.

## Files

- `tools/strategy_farm/live_book_pulse.py`
- `tools/strategy_farm/tests/test_live_book_pulse.py`

## Verification

- `python -m pytest tools/strategy_farm/tests/test_live_book_pulse.py`: PASS, 7 tests.
- `python -m py_compile tools/strategy_farm/live_book_pulse.py`: PASS.
- Read-only live sample: `D:\QM\strategy_farm\artifacts\ops\live_book_pulse_4763e823_2026-07-04.json`

## Live Sample

The one-shot sample returned `verdict=OK` with no alarms. Heartbeat summary:

- latest scan heartbeat: `2026-07-04T01:43:12.363`
- minutes since scan at sample time: `46.51`
- today broker-date journal present: `true`
- terminal-sync position exposure: `true`
- active stale threshold while exposed: `120` minutes
- market-hours gate at sample time: `false`

