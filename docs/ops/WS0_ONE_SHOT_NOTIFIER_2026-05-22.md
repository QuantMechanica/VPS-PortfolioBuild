# WS-0 One-Shot Notifier

Date: 2026-05-22
Task: `4fcc31a0-58d7-43bd-9512-4448746158d7`

## Result

- Added a one-shot WS-0-clear notifier to `tools/strategy_farm/gmail_alarm.py`.
- A concurrent pump-integrated notifier hook appeared in `tools/strategy_farm/farmctl.py` / `tools/strategy_farm/ws0_notifier.py`; it was hardened to the same post-policy cutoff and shares the same sentinel path.
- The notifier checks `work_items` for the first post-policy Q02/P2 real verdict:
  - `phase='P2'`
  - `status='done'`
  - `verdict IN ('PASS', 'FAIL', 'ZERO_TRADES')`
  - `updated_at >= '2026-05-22T07:41:37'`
- `INVALID` and timeout evidence are not eligible.
- The notifier persists `D:/QM/strategy_farm/state/ws0_notified.json` and will not send again once that sentinel exists.

## Live Outcome

The first eligible row was already present:

- work item: `7e75e630-550a-466a-ab50-6b7b3e9a90d2`
- EA: `QM5_10260`
- symbol: `GBPCHF.DWX`
- verdict: `FAIL`
- updated_at: `2026-05-22T07:42:39+00:00`
- evidence: `D:/QM/reports/work_items/7e75e630-550a-466a-ab50-6b7b3e9a90d2/QM5_10260/20260522_064152/summary.json`

The notifier sent the OWNER email once with subject:

`[QM Strategy Farm] WS-0 cleared - Q02 real verdict FAIL`

The sentinel was written. A second invocation returned `ws0_sentinel_exists`, verifying it cannot fire twice.

## Verification

- `python -m py_compile tools/strategy_farm/gmail_alarm.py`: PASS
- Direct notifier check: first call sent mail and wrote sentinel.
- Direct notifier check: second call returned `{'sent': False, 'reason': 'ws0_sentinel_exists', ...}`.
- `python -m py_compile tools/strategy_farm/ws0_notifier.py tools/strategy_farm/farmctl.py`: PASS

No Q-gate verdicts were inferred beyond the pipeline row already present in `work_items`. No T_Live or AutoTrading changes were made. No terminal was started manually.
