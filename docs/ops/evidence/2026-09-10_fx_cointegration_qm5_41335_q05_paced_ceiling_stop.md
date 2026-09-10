# FX cointegration fallback — QM5_41335 Q05 paced-ceiling stop

Recorded: 2026-09-10T13:46:50Z (15:46 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `7c3914b9ca5d05b1b107f3cf93dd66c1be5a8947`

## Outcome

No duplicate FX basket or work item was created. The frozen sign-aware 66-pair
cointegration frontier remains fully mechanized: the current reconciliation in
`artifacts/fx_cointegration_frontier_cpu_stop_20260910T0616Z_board_advisor.json`
checks 16 approved next-best Edge Lab Cards, and all 16 already have EA
directories and terminal Q02 history.

The two preferred baskets are beyond Q02 and do not need ONINIT/NO_HISTORY
repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 `PASS`, Q04 `PASS`, then Q05
  `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 `PASS`, then Q04
  `FAIL`.

The allowed existing-forex fallback, structural low-frequency
`QM5_41335_fx-usd-exhaustion-reversal-opt` on `AUDUSD.DWX` D1, has already
advanced through Q02 `PASS` and Q04 `PASS_LOWFREQ`. Its exact Q05 successor
`5b046970-f847-42c6-a3df-77b2d5ec11bc` exists once and was still `pending`.
Creating or requeueing another Q05 row would be duplicate work.

## PACER and identity checks

The current source, binary, and backtest setfile still match the authenticated
Q02/Q04/Q05 chain:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `d7eec6373be1b7b865902cd8420b2a3fe305c7a7e026603e9baef9e32ee1e7bc` |
| EX5 | `f17045107715b1ee127011f14ee60ad36e6ad23e8dbfc372819a27d4bb596280` |
| AUDUSD D1 setfile | `6ed5b4fe7549362276fa8812bcbf9450f6aca2b3b03fd169336a89799874bd47` |

The setfile contains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

No MQ5 was generated or edited and no compile command was enqueued. The binding
framework-input audit was nevertheless run read-only against the absolute
source path:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_41335_fx-usd-exhaustion-reversal-opt/QM5_41335_fx-usd-exhaustion-reversal-opt.mq5"
```

It exited zero with `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, and zero
findings.

Five one-second whole-host CPU samples were `52.839283%`, `45.080672%`,
`37.538164%`, `36.757119%`, and `29.207531%` (average `40.284554%`, maximum
`52.839283%`), below the 97% hard host threshold. The paced launch gate bound
first: `D:/QM/strategy_farm/state/launch_gate_max.txt` contains `1`, and the
process census showed one running factory tester (`T9`). A nearby database
census contained two active OPT_CENSUS claims (`T9` and `T6`); the later
process scan no longer showed T6, confirming changing fleet state but not a
free paced slot. Per the mission stop rule, no dispatch tick or tester work was
started.

## Safety

- No Card, EA source or binary, setfile, registry, magic row, compile work,
  work-item row, priority, hold, claim, verdict, terminal, or tester changed.
- No portfolio-admission, portfolio KPI, Q08-contribution, portfolio-gate,
  deploy-manifest, `T_Live`, or AutoTrading surface was touched.
- Existing unrelated shared-worktree changes were left untouched and excluded
  from this commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_41335_q05_paced_ceiling_stop_20260910T134650Z_board_advisor.json`.
