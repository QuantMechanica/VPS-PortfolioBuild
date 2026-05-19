# MT5 T6-T10 Expansion Evidence — 2026-05-19

## Scope

- Branch: `agents/board-advisor`
- Factory terminals expanded from `D:/QM/mt5/T1..T5` to `D:/QM/mt5/T1..T10`.
- `C:/QM/mt5/T_Live` remains hard-excluded from factory scripts and worker spawning.

## Disk Usage

| Checkpoint | D: used bytes | D: free bytes | D: free GiB |
|---|---:|---:|---:|
| Before T6 clone | 506,339,622,912 | 517,852,786,688 | 482.21 |
| After T6-T10 clone verification | 507,701,649,408 | 516,490,756,096 | 481.02 |
| Final evidence snapshot | 508,744,155,136 | 515,448,254,464 | 480.05 |

The clone step consumed about 1.27 GiB for five terminals because `Bases/` and `MQL5/Files/registry/` are junctions rather than copied data.

## Junction Map

| Terminal | Bases target | Registry target | imports exists |
|---|---|---|---|
| T6 | `D:\QM\mt5\T1\Bases` | `D:\QM\mt5\T1\MQL5\Files\registry` | false |
| T7 | `D:\QM\mt5\T1\Bases` | `D:\QM\mt5\T1\MQL5\Files\registry` | false |
| T8 | `D:\QM\mt5\T1\Bases` | `D:\QM\mt5\T1\MQL5\Files\registry` | false |
| T9 | `D:\QM\mt5\T1\Bases` | `D:\QM\mt5\T1\MQL5\Files\registry` | false |
| T10 | `D:\QM\mt5\T1\Bases` | `D:\QM\mt5\T1\MQL5\Files\registry` | false |

Each T6-T10 root has `terminal64.exe` and `portable.txt`.

## Worker Daemons

Verified 10 `pythonw.exe` terminal workers after `python tools/strategy_farm/start_terminal_workers.py --dedupe`:

| Terminal | PID |
|---|---:|
| T1 | 49396 |
| T2 | 77268 |
| T3 | 19804 |
| T4 | 14576 |
| T5 | 48564 |
| T6 | 57432 |
| T7 | 8500 |
| T8 | 15852 |
| T9 | 48600 |
| T10 | 59044 |

Health check result:

```json
{"name":"mt5_worker_saturation","status":"OK","value":10,"threshold":10,"detail":"10/10 terminal_worker daemons alive (T1, T10, T2, T3, T4, T5, T6, T7, T8, T9)"}
```

## T6 Dry-Run Dispatch

Command:

```powershell
python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols EURUSD.DWX --year 2024 --period H1 --terminal T6 --dry-run
```

Result:

```text
[P2] EA=QM5_1003 ea_id=1003 period=H1 window=2024 runs=2
[P2] symbols=1 report_csv=D:\QM\reports\pipeline\QM5_1003\P2\report.csv
[P2] DRY RUN (no MT5 launches)
[DRY] EURUSD.DWX -> T6 (setfile=QM5_1003_davey_baseline_3bar_EURUSD.DWX_H1_backtest.set)
[P2 DONE] {'PASS': 0, 'FAIL': 0, 'INVALID': 0, 'DRY': 1}  summary=D:\QM\reports\pipeline\QM5_1003\P2\p2_QM5_1003_result.json
```

## T_Live Exclusion

Verified grep scope: `tools/strategy_farm`, `framework/scripts`, and `scripts/aggregator`.

- `tools/strategy_farm/farmctl.py` uses `MT5_TERMINALS = tuple(f"T{i}" for i in range(1, 11))` and `LIVE_TERMINAL_NAMES = {"T_LIVE", "T6_LIVE"}`.
- `tools/strategy_farm/start_terminal_workers.py` uses `TERMINALS = tuple(f"T{i}" for i in range(1, 11))` plus `FACTORY_TERMINAL_RE = ^T(?:[1-9]|10)$`.
- `tools/strategy_farm/start_terminal_workers.ps1` builds `$factoryTerminals` from `1..10`.
- `scripts/aggregator/standalone_aggregator_loop.py` enumerates T1-T10 and hard-excludes `C:\QM\mt5\T_Live` and `D:\QM\mt5\T_Live`.
- `framework/scripts/clone_terminal.ps1` refuses `T_Live`.
- `framework/scripts/run_smoke.ps1` rejects non-factory terminals and states that `T_Live` is off limits.

No factory worker or pump code path found that includes `T_Live` in the factory terminal list.

## Commits

- `e9dfc1a5` `feat(mt5): clone_terminal.ps1 + T6-T10 portable copies`
- `1accb617` `feat(strategy_farm): expand MT5_TERMINALS to T1..T10`
- `d148ef54` `feat(strategy_farm): scale worker daemons to T1..T10`
- `9ec48b52` `feat(strategy_farm): scale worker daemons to T1..T10`
- `351bb369` `feat(strategy_farm): MT5 saturation health threshold T1..T10`
