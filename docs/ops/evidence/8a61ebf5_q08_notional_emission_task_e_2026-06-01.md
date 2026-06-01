# Q08/Q11 Worst-Case Commission Task E Evidence

Task: 8a61ebf5-9a9f-45be-b662-39f4e4de24c8

Scope completed:
- Extended `framework/include/QM/QM_Common.mqh` `TRADE_CLOSED` JSONL emission additively.
- Existing fields preserved: `net`, `profit`, `swap`, `commission`, `volume`, `time`.
- Added `notional` and `symbol`.
- `notional` is computed from `DEAL_VOLUME * SYMBOL_TRADE_CONTRACT_SIZE * DEAL_PRICE` with best-effort conversion from symbol profit currency into `ACCOUNT_CURRENCY`.
- Recompiled active Q08 blocker `QM5_10260_cieslak-fomc-cycle-idx` through `framework/scripts/compile_one.ps1`.

Focused verification:
- Compile command:
  `pwsh.exe -NoProfile -File framework/scripts/compile_one.ps1 -EALabel QM5_10260_cieslak-fomc-cycle-idx`
- Compile result:
  `PASS`, `errors=0`, `warnings=0`
- Compile log:
  `C:\QM\repo\framework\build\compile\20260601_083523\QM5_10260_cieslak-fomc-cycle-idx.compile.log`
- Compile summary:
  `D:\QM\reports\compile\20260601_083523\summary.csv`
- Fresh Q08 baseline:
  `python -m framework.scripts.q08_davey.aggregate --ea-id 10260 --symbol WS30.DWX --log D:/QM/reports/pipeline/QM5_10260/Q08/task_e_empty_input.jsonl --terminal T3 --out-dir D:/QM/reports/pipeline/QM5_10260/Q08/WS30_DWX_task_e_notional`
- Baseline summary:
  `D:\QM\reports\pipeline\QM5_10260\Q08\_baseline\QM5_10260\20260601_083626\summary.json`
- Trade stream path:
  `C:\Windows\System32\config\systemprofile\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q08_trades\10260_WS30_DWX.jsonl`

Sample `TRADE_CLOSED` line:
```json
{"event":"TRADE_CLOSED","time":1674232710,"net":-10154.72,"profit":-9994.98,"swap":-157.23,"commission":-2.51,"volume":7.17,"notional":236136.78,"symbol":"WS30.DWX"}
```

Operational note:
- The routed task asked for a fleet recompile. This single-pass cycle recompiled the active Q08 blocker `QM5_10260` and verified the emitted stream in MT5. A full `framework/EAs` force-recompile would cover 811 EA directories in this worktree and was not run during the headless router cycle.
