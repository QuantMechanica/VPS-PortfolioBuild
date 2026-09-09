# FX Cointegration Funnel — Active-Row CPU-Ceiling Stop

Date: 2026-09-09

Branch: `agents/board-advisor`

Captured: `2026-09-09T08:46:49.4952900Z`

Observation head: `7e11a3e8cacad099112a69ba97571f87b142da8e`

## Outcome

No new Strategy Card, EA, compile job, or Q02 row was created. The frozen
66-pair FX cointegration frontier remains fully mechanized, and a fresh
factory admission check hit the binding active-work-item ceiling before any
state-changing action.

The non-duplicate checks remain decisive:

- `QM5_12532` has logical-basket Q02 `PASS` on work item
  `e4890d77-b865-4a48-b946-315faefca920`, Q04 `PASS`, and terminal Q05
  `FAIL`. Its old component-leg failures are superseded and do not justify a
  Q02 repair.
- `QM5_12533` has logical-basket Q02 `PASS` on work item
  `76cb11ee-7e9d-4d75-be9d-626c205bca62` and terminal Q04 `FAIL`. Its old
  ONINIT/history failures are superseded.
- `QM5_41335` already completed the single AUDUSD D1 Q02 canary with `PASS`
  on `ff75b1c3-4930-419d-a2fe-49bd37eadc4d`; duplicating it is forbidden.
- `QM5_12507` already has one pending logical-basket Q02 row,
  `547c4fd3-f3fd-4c59-b9dc-654e96521251`; a second row would be duplicate
  work.

The governing frontier reconciliation is
`docs/research/FX_COINTEGRATION_FRONTIER_Q02_CPU_CEILING_STOP_2026-08-07.md`.
It records coverage through all 66 ranked relationships. The reputable
structural-method lineage remains Ernest P. Chan, *Quantitative Trading*
(Wiley, 2009), preserved in
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`.

## Binding capacity stop

The canonical read-only work-item query returned 10 active rows:

| Phase | Active |
|---|---:|
| Q02 | 2 |
| Q04 | 2 |
| Q07 | 1 |
| OPT_CENSUS | 5 |

`tools/strategy_farm/farmctl.py` defines
`BUILD_BACKPRESSURE_ACTIVE_WORK_ITEM_LIMIT = 7`. Ten active rows therefore
refuse new paced-fleet work. Nine factory terminals were running (`T1` through
`T7`, `T9`, and `T10`); `T_Live` and the FTMO terminal were observed only so
they could be excluded.

Five one-second host CPU samples were `79.79`, `75.77`, `78.04`, `71.98`, and
`74.05` percent (average `75.93`, maximum `79.79`). Those samples do not
override the independent active-row admission refusal.

## Reproduction

```powershell
python tools/strategy_farm/farmctl.py mt5-slots
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --status active
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_12532
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_12533
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_41335
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_12507
```

## PACER guard and safety

- No `.mq5` was generated or modified, so the mandatory
  `audit_framework_input_pins.py --check-source` pre-compile audit was not
  applicable.
- No compile, Q02, smoke, dispatch, priority, terminal-control, portfolio-gate,
  deploy-manifest, `T_Live`, or AutoTrading mutation was made.
- Existing unrelated dirty-worktree files were left untouched.

Machine-readable receipt:
`artifacts/fx_cointegration_cpu_ceiling_stop_20260909T084649Z_board_advisor.json`.
