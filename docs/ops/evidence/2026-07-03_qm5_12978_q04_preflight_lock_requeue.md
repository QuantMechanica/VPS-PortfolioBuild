# QM5_12978 Q04 Preflight Recovery - 2026-07-03

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate, `portfolio_admission`, `_kpi`, or `_q08_contribution` edits.

## Mission Selection

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan artifact. It documents only two strict positive-hedge
FX cointegration survivors: `QM5_12533` EURJPY/GBPJPY and `QM5_12532`
AUDUSD/NZDUSD. Both are already built and have Q02 `PASS` evidence, so there is
no unbuilt strict-threshold pair left from that scan.

Per the fallback, this pass continued the existing non-duplicate FX cointegration
sleeve:

- EA: `QM5_12978`
- Slug: `edgelab-gbpusd-usdcad-cointegration`
- Logical symbol: `QM5_12978_GBPUSD_USDCAD_COINTEGRATION_D1`
- Pair: GBPUSD/USDCAD, two-leg D1 market-neutral cointegration basket

## Current Funnel State

`QM5_12978` has:

- Q02 `PASS`: work item `b1656e8e-d9dc-4a7b-b5a2-ba8e3ff0150b`
- Q03 `PASS`: work item `30907ff5-af52-448b-81b4-1e008539602f`
- Q04 `INVALID`: work item `bf98a2c5-0ed2-4410-abbe-7e66fe97e843`

The Q04 failure was a stale-worker preflight miss:

```text
reason: ea_dir_missing
detail: C:\QM\worktrees\codex-orchestration-1\framework\EAs\QM5_12978_*
setfile_path: C:\QM\repo\framework\EAs\QM5_12978_edgelab-gbpusd-usdcad-cointegration\sets\QM5_12978_edgelab-gbpusd-usdcad-cointegration_QM5_12978_GBPUSD_USDCAD_COINTEGRATION_D1_D1_backtest.set
```

Current `C:\QM\repo` code resolves the EA directory from the absolute setfile path:

```text
ea_dir_from_setfile: C:\QM\repo\framework\EAs\QM5_12978_edgelab-gbpusd-usdcad-cointegration
preflight_failure_current_code: null
```

## Validation

- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12978_edgelab-gbpusd-usdcad-cointegration --verbose`
  - Result: `BASKET_OK`, `n_violations=0`
- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12978_edgelab-gbpusd-usdcad-cointegration -RepoRoot C:/QM/repo -SkipCompile`
  - Result: `PASS`
  - Failures: `0`
  - Warnings: `16` existing shared-framework DWX advisories
  - Report: `D:/QM/reports/framework/21/build_check_20260703_074841.json`
- Regression added:
  - `python -m unittest tools.strategy_farm.tests.test_terminal_worker_atomic_claim.TerminalWorkerAtomicClaimTests.test_preflight_resolves_absolute_setfile_outside_worker_repo_root`
  - Result: `OK`

## Queue Action

Database backup before mutation attempt:

```text
D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12978_q04_requeue_20260703T074904Z.sqlite
```

Preferred requeue command:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12978 --phase Q04
```

Result:

- First attempt timed out before commit.
- Second attempt failed with `sqlite3.OperationalError: database is locked`.
- Minimal direct transaction attempt also failed with `sqlite3.OperationalError: database is locked`.
- A write-lock probe returned `write_lock_available=false`.

Observed lock holder:

```text
python C:\QM\repo\tools\strategy_farm\farmctl.py pump
PID 16332, started 2026-07-03 09:43:01 Europe/Berlin
```

After the pump released the write lock, the normal requeue path succeeded:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12978 --phase Q04
```

Result:

```text
enqueued: true
created: []
requeued: [{id: bf98a2c5-0ed2-4410-abbe-7e66fe97e843, symbol: QM5_12978_GBPUSD_USDCAD_COINTEGRATION_D1}]
skipped: []
```

Post-action state:

```text
Q04 work item: bf98a2c5-0ed2-4410-abbe-7e66fe97e843
status: pending
verdict: null
claimed_by: null
evidence_path: null
host_symbol: GBPUSD.DWX
host_timeframe: D1
tester_currency: USD
tester_deposit: 100000
pending_active_q04_count: 1
```

`farmctl` rebuilt the retry payload without the earlier mission priority flag, so
the same row was updated in place with `priority_track=true` and this reason:

```text
OWNER 2026-07-03 forex sleeve mission: keep QM5_12978 Q04 retry visible after stale-worker preflight repair
```

`framework/scripts/mt5_queue_status.py` then showed `QM5_12978` Q04 as the first
queued item with `priority_track=true`. No duplicate Q04 row was inserted and no
manual MT5 run was launched.

## Safety

- Manual MT5 backtest launched: no
- Duplicate queue row created: no
- `T_Live` touched: no
- AutoTrading touched: no
- Portfolio gate touched: no
- Deploy manifest touched: no
