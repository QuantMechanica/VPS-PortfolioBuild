# QM5_12624 Q02 Log-Bomb Terminal State - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

The controlling FX cointegration scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. It hard-certified only:

- `QM5_12533` EURJPY/GBPJPY: logical-basket Q02 `PASS`, later Q04 `FAIL`.
- `QM5_12532` AUDUSD/NZDUSD: logical-basket Q02 `PASS`, later Q04 `FAIL`.

No unbuilt strict-threshold FX cointegration pair was found. The already-built
next-best exploratory pair, `QM5_12624` EURJPY/AUDJPY, was the concrete existing
forex card to advance.

## Current Q02 Evidence

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Latest `QM5_12624` logical-basket Q02 rows:

| Work item | Status / verdict | Evidence |
|---|---|---|
| `53f8fa92-3452-48ed-9e7c-82344a76883c` | `done` / `INFRA_FAIL` | `D:/QM/reports/work_items/53f8fa92-3452-48ed-9e7c-82344a76883c/QM5_12624/20260627_151534/summary.json` |
| `9461ba0f-5de6-490e-8d85-380738abd892` | `done` / `INFRA_FAIL`, `attempt_count=99` | no summary; log-bomb guard terminal state |

The first run produced real EURJPY/AUDJPY basket trades before report export
failed. The second run progressed on T7 from `18:05:35` local to `42%` at
`18:55:37` local, then the worker killed it and set `attempt_count=99`, matching
the log-bomb guard path. This is not an `ONINIT` or `NO_HISTORY` failure.

## Code Change

`tools/strategy_farm/terminal_worker.py` now records log-bomb kills as auditable
infra evidence:

- stops the terminal slot on log-bomb kill;
- writes `log_bomb_evidence.json` under the work-item report root when possible;
- stamps the work-item payload with `reason_classes=["LOG_BOMB"]`,
  `verdict_reason=LOG_BOMB`, `final_failure=log_bomb`, journal size/cap, and the
  evidence path.

Regression test added in
`tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py`.

## Validation

```powershell
python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py tools/strategy_farm/tests/test_basket_work_items.py -q
```

Result: `21 passed`.

## Stop Condition

No new Q02 row was inserted. `QM5_12624` hit the backtest CPU/disk-protection
ceiling, and the mission constraint says to stop rather than launch another
heavy basket run.
