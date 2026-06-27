# QM5_12533 Terminal Claim Race Fix - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan. It documents only two strict-threshold FX cointegration
survivors:

- `QM5_12532` AUDUSD/NZDUSD D1 basket: logical-basket Q02 `PASS`; later Q04 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY D1 basket: still the actionable blocked forex basket.

No third unbuilt FX cointegration pair in that scan meets the documented build threshold
(`DEV > 0`, OOS net Sharpe > 0.8, and at least 4 OOS trades), so this action continues
unblocking `QM5_12533` instead of creating a weaker duplicate card.

## Latest Failure

Latest completed `QM5_12533` logical-basket Q02 row:

| Field | Value |
|---|---|
| Work item | `433bf1fd-c82f-4d3f-934c-21b772eea5fc` |
| Symbol | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` |
| Status / verdict | `done` / `INFRA_FAIL` |
| Evidence | `D:/QM/reports/work_items/433bf1fd-c82f-4d3f-934c-21b772eea5fc/QM5_12533/20260627_070554/summary.json` |
| Summary reason | `NO_HISTORY`, `INCOMPLETE_RUNS` |

The report was not a true `.DWX` history absence. `tester.ini` was valid, and the
T4 tester journal showed `QM5_12533` loaded and began testing on `EURJPY.DWX,D1`.
The generated HTML report was malformed (`Expert` empty, `Symbol` empty, `M0 1970`,
`Bars: 0`), while the T4 journal showed Windows history file sharing errors:

- `History 'EURUSD.DWX' file opening or reading error [32]`
- `History 'USDJPY.DWX' file opening or reading error [32]`
- `Tester last test passed with result "some error after pass finished" in 0:00:00.000`

The same T4 log had an earlier T4 tester run active without a clean finish before the
`QM5_12533` launch. This points to same-terminal overlap, not strategy failure.

## Code Fix

`tools/strategy_farm/terminal_worker.py` now treats an active row with a live
`claimed_by_worker_pid` as terminal-busy even when the child `pid` has not yet been
recorded.

Before this fix, a duplicate worker for the same terminal could see:

- active row for `T4`;
- live worker pid;
- no child terminal pid yet, because the first worker was between claim and spawn.

That path incorrectly released the active row as stale and claimed another item on the
same terminal. The result was two T4 launches contending for the same MT5 history files,
which can produce blank zero-bar reports misclassified as `NO_HISTORY`.

Regression coverage added in `tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py`:

- `test_live_worker_without_child_pid_keeps_terminal_busy`
- updated orphan-child test to match the current adoption contract.

## Validation

```powershell
python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q
python -m unittest tools.strategy_farm.tests.test_terminal_worker_adoption -v
```

Results:

- `14 passed`
- `3 passed`

## Queue Action

No replacement `QM5_12533` Q02 row was inserted in this pass.

Reason: the enabled terminal fleet is at the backtest CPU/slot ceiling. `T8`, `T9`, and
`T10` are disabled, while `T1` through `T7` all have active work items. The running
terminal-worker processes were also started before this code patch, so a new priority
Q02 row could be claimed by old code before worker recycle. The correct next action is
to let the paced fleet recycle onto this commit, then insert one guarded replacement
logical-basket Q02 row for `QM5_12533` if no pending/active duplicate exists.

