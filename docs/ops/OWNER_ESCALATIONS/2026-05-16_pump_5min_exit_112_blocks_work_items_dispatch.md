---
opened_utc: 2026-05-16T18:56Z
raised_by: Board Advisor (observe wake 2026-05-16T18:47Z)
severity: high
class: scheduled-task-infrastructure
scope: T1-T5 factory dispatcher
---

# `QM_StrategyFarm_Pump_5min` returns `LastResult=112`, work_items pile up undispatched

## Observed (this wake, 2026-05-16T18:51-18:55Z)

`farmctl tick` reported `mode=idle, free_terminals=[T1,T2,T3,T4,T5], actions=[]`.
0 `terminal64.exe` processes running, yet 6 `work_items` for QM5_1051 P2 backtest
(task `0cd310d0-a6e7-45e3-8ef5-a67cff9e1058`, all symbols H1 forex) had been
`status=pending` since 2026-05-16T18:34:43Z — i.e., ~20 min queued with the
fleet idle.

Root cause: the scheduled task `tick` calls `farmctl.py tick`, which only
runs the legacy `dispatch_tick` path (filters out tasks with work_items):

```python
# farmctl.py:3158
elif args.command == "tick":
    print_json({
        "tick_at": utc_now(),
        "dispatch": dispatch_tick(root, timeout_hours=args.timeout_hours),
    })
```

`dispatch_work_items` (the per-(ea x symbol) dispatcher introduced in the
2026-05-16 work_items refactor) is only invoked by `farmctl.py pump`
(line 1279). A separate scheduled task `QM_StrategyFarm_Pump_5min` exists to
run pump every 5 min — but it's broken:

```
TaskName                       State   LastRun              LastResult
QM_StrategyFarm_Pump_5min      Ready   2026-05-16 20:50:50    112
QM_StrategyFarm_Cockpit_2min   Ready   2026-05-16 20:52:52    112
QM_StrategyFarm_Tick_5min      Ready   2026-05-16 20:50:50      0
QM_StrategyFarm_Dashboard_Hourly Ready 2026-05-16 20:00:00      0
QM_StrategyFarm_AutonomousWake_Hourly Ready 2026-05-16 20:17:17 0
```

`QM_StrategyFarm_Pump_5min` and `QM_StrategyFarm_Cockpit_2min` both return
exit code 112 every cycle. Manual invocation of `py -3 farmctl.py pump`
under my interactive shell **succeeds** (exit 0) and dispatches work_items
correctly. So `pump()` itself is not broken — it's the scheduled wrapper
context (likely SYSTEM principal + no stdout/stderr redirect + Unicode
`print_json()` arrow chars failing under `cp1252` non-interactive stdout)
that's failing.

## Evidence

- Pump XML installed (`schtasks /XML`): `C:\Windows\py.exe -3 farmctl.py pump`
  under SYSTEM principal, no stdout/stderr redirect, ExecutionTimeLimit PT10M,
  MultipleInstancesPolicy=IgnoreNew. Definition NOT in repo
  (`tools/strategy_farm/scheduled_task_pump.xml` does not exist — Tick,
  Dashboard, Observe, AutonomousWake XMLs are checked in; Pump is not).
- Cockpit_2min showing identical pattern strongly suggests a shared SYSTEM-
  context shell issue, not a per-script bug.
- Prior autonomous wake transcript shows a related symptom — pump output
  contains the U+2192 arrow ("→") and SYSTEM-context Python defaults stdout
  to `cp1252` which raises `UnicodeEncodeError` on that character. (Caught
  earlier today at `/d/QM/strategy_farm/logs/autonomous_wake_2026-05-16T18-17-01Z.log`,
  `UnicodeEncodeError: 'charmap' codec can't encode character '→'`.)
- Pump_5min log evidence is limited because the XML doesn't redirect stdout
  or stderr — no captured trace.

## Operational impact

Until Pump_5min runs cleanly, every new backtest task that creates
work_items (the new path, from 2026-05-16 `_create_backtest_work_items`)
will sit idle. The legacy bundled path (`dispatch_tick`) still works for
tasks WITHOUT work_items, but the autonomous loop is now creating
work_items for every new task it enqueues, so the dispatcher gap blocks
forward progress on the P2 backtest queue.

## What this wake did (Test-Environment Ownership direct action)

- Manually invoked `farmctl.py pump` — dispatched 5 work_items for QM5_1051
  (AUDUSD, EURJPY, EURUSD, GBPUSD, USDCAD) to T1-T5.
- A second pump invocation (PowerShell-spawned diagnostic) picked up T5
  release after USDCAD finished and dispatched USDJPY.
- Verified: 5 `terminal64.exe` processes started 20:54-20:56 local, all 6
  work_items now status=active or done.
- Did NOT modify the Pump_5min task definition — that's a scheduled-task
  reinstall decision and belongs to OWNER / DevOps. Did not commit a new
  `scheduled_task_pump.xml` to repo either — would lock in the broken
  state before root-cause is pinned.

## Recommended fixes (any one is sufficient)

1. **Pump_5min wrapper PowerShell script.** Replace the `<Exec>`
   direct-command with a `.ps1` that:
   ```powershell
   $env:PYTHONIOENCODING = "utf-8"
   $env:PYTHONUTF8 = "1"
   & C:\Windows\py.exe -3 C:\QM\repo\tools\strategy_farm\farmctl.py pump *> "D:\QM\strategy_farm\logs\pump_$(Get-Date -Format yyyyMMddTHHmmssZ).log"
   exit $LASTEXITCODE
   ```
   Captures both stdout+stderr per run AND forces UTF-8 stdout so the U+2192
   arrows don't crash print_json.

2. **`print_json` defensive UTF-8 in farmctl.** Replace the bare
   `json.dumps` + `print()` with `sys.stdout.reconfigure(encoding='utf-8',
   errors='replace')` at the top of `main()`. Survives any future Unicode
   leakage into JSON output regardless of caller's stdout encoding.

3. **Merge pump into tick.** Drop the Pump_5min task entirely; have Tick
   call both `dispatch_tick` and `dispatch_work_items` from one entry point.
   Removes the two-task surface area, but means Codex/Claude spawns and
   build-retry move into the same 5-min cadence as MT5 dispatch (may or
   may not be desired — Codex spawn budget is currently 3 parallel).

(2) + repo-checkin of a corrected `scheduled_task_pump.xml` is cleanest.
(1) doesn't touch farmctl source; (3) restructures the controller.

## Recommended next step

OWNER (or DevOps) picks fix; lands it; verifies next Pump_5min run returns
LastResult=0; deletes the manual dispatch comment from this file when
resolved. The same fix likely resolves Cockpit_2min (which also runs a
farmctl-like SYSTEM-context Python command and returns 112 every cycle).

## Files referenced

- `C:\QM\repo\tools\strategy_farm\farmctl.py` — main controller; `tick`
  dispatch at lines 3158-3165, `pump` at line 1251, `dispatch_work_items`
  at line 698.
- `C:\QM\repo\tools\strategy_farm\scheduled_task_tick.xml` — Tick task
  definition (in repo, working).
- `C:\QM\repo\tools\strategy_farm\scheduled_task_pump.xml` — DOES NOT
  EXIST. Pump task is installed but its XML is not in the repo.
- `D:\QM\strategy_farm\state\farm_state.sqlite` — work_items state.
- `D:\QM\strategy_farm\logs\pump_*.json` — historical manual pump output.

## Recurrence log

- 2026-05-16T18:51Z (filing wake) — Pump_5min LastResult=112; 6 work_items pending; manual pump dispatched all 6 to T1-T5.
- 2026-05-17T04:50Z (observe wake) — Pump_5min still LastResult=112 (next run 06:50 local). 5 zombie work_items (QM5_1049, all 5 PIDs dead, log files showed completed runs but DB never advanced) + 44 fresh pending from autonomous wakes piling up; 0 terminal64.exe running. Manual `farmctl pump` under `PYTHONIOENCODING=utf-8 PYTHONUTF8=1` classified the 5 zombies + dispatched 5 fresh QM5_1049 work_items (UK100×3, WS30×2) to T1-T5; 4 terminal64.exe alive 30s post-pump. Pending dropped from 54 to 54 (offset by ablation_children expansion of QM5_1049 parents). Fix candidate (1) or (2) still unlanded — escalation remains open.
- 2026-05-19T13:53Z (observe wake) — new failure mode in the same family: `backtest_p2 status=failed` with `failure_reason=no_work_items_created` (and the variant `no_work_items_created_after_legacy_reclaim`). Today's burst: 758 such failures inside the 07Z UTC hour, then self-stabilised to 5/3/3/1 per hour for 09-13Z; current rate ~1/hr. Most concentrated on 4 cards (QM5_1118: 337, QM5_1328: 264, QM5_1371: 190, QM5_1383: 52) that the controller keeps re-enqueueing despite each attempt instantly returning `skipped_symbols_count=0`. MT5 fleet currently 5/5 saturated (T1-T5 all running pipeline/work_item terminals) so primary mission metric is met; QM5_1118/1328 are still advancing (85 and 14 P2 done respectively), QM5_1371 has 74 fresh work_items pending. **Stuck without a recovery path** (build_ea done + ea_review done + 0 work_items + only legacy backtest_p2 fails): QM5_1383, QM5_1387, QM5_1406, QM5_1435, QM5_1554. Same dispatcher-split root cause — the legacy `enqueue-backtest` path runs `_create_backtest_work_items` and gets 0 rows back for these cards (likely card-level target-symbol resolution failure against the DWX matrix), so the legacy task fails immediately and nothing populates work_items for the new path. Recommend fix (3) (merge pump into tick) plus a circuit-breaker in `_create_backtest_work_items` so a 0-work-item enqueue marks the EA `needs_symbol_resolution_review` instead of permitting unbounded re-enqueue. Cards-stuck list should also feed Board Advisor's Test-Environment-Ownership review of target_symbols vs. dwx_symbol_matrix.csv.
