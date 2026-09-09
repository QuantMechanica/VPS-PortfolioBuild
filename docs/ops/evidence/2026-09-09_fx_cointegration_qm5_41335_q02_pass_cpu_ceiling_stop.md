# FX Cointegration Funnel — Q02 Progress and CPU-Ceiling Stop

Date: 2026-09-09

Branch: `agents/board-advisor`

Captured: `2026-09-09T06:44:50Z`

## Outcome

No reputable-screen, non-duplicate pair remains unbuilt in the frozen 66-pair
FX cointegration scan. The seven strict sign-aware relationships all still
have EA directories, compiled `.ex5` artifacts, and `basket_manifest.json`
files. Creating another card or basket EA would duplicate existing coverage.

The two requested anchors do not need a Q02 infrastructure repair:

- `QM5_12532` has logical-basket Q02 `PASS`, Q04 `PASS`, then Q05 `FAIL`.
- `QM5_12533` has logical-basket Q02 `PASS`, then Q04 `FAIL`.

The permitted fallback did make new progress. `QM5_41335` AUDUSD D1 completed
Q02 with `PASS` at `2026-09-09T06:13:19Z` on work item
`ff75b1c3-4930-419d-a2fe-49bd37eadc4d`. This is the same single canary that was
already enqueued at 01:07Z; no duplicate row was created. The live work-item
query shows no Q04 successor for this EA yet.

## Binding stop

The canonical read-only fleet query returned nine active work items:

| Phase | Active |
|---|---:|
| Q04 | 5 |
| OPT_CENSUS | 4 |

`tools/strategy_farm/farmctl.py` defines
`BUILD_BACKPRESSURE_ACTIVE_WORK_ITEM_LIMIT = 7`. Nine active rows therefore
hit the mission's backtest CPU/backpressure stop condition. Six factory
terminals were visibly running (`T1`, `T2`, `T3`, `T4`, `T7`, `T8`) at the
captured instant; `T_Live` and the FTMO terminal were excluded.

The older logical-basket fallback `QM5_12507` also still has exactly one
pending Q02 row, `547c4fd3-f3fd-4c59-b9dc-654e96521251`, for
`QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`. Enqueueing either a second 12507
row or a second 41335 row would be duplicate work.

Accordingly, no Q04 successor, new Q02 row, compile job, priority mutation, or
dispatch tick was submitted.

## Reproduction

```powershell
python tools/strategy_farm/farmctl.py mt5-slots
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --status active
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_12532
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_12533
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_41335
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_12507
```

The governing scan reconciliation remains
`docs/research/FX_COINTEGRATION_FRONTIER_Q02_CPU_CEILING_STOP_2026-08-07.md`.
The reputable structural-method lineage is Ernest P. Chan, *Quantitative
Trading* (Wiley, 2009), preserved at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`.

## Safety

- No Strategy Card, EA source, binary, setfile, basket manifest, EA registry,
  or magic-number row changed.
- The PACER source-pin audit was not applicable because no `.mq5` was written.
- No compile or backtest work was enqueued, claimed, or dispatched.
- No portfolio-admission, portfolio KPI, Q08-contribution, deploy-manifest,
  `T_Live`, or AutoTrading state was touched.
- Existing unrelated dirty-worktree files were left untouched.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_41335_q02_pass_cpu_ceiling_stop_20260909T064450Z_board_advisor.json`.
