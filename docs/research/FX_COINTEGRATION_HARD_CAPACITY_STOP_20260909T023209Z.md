# FX cointegration hard capacity stop

Recorded: 2026-09-09T02:32:09Z (04:32 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `2df35acaff885b90fa8a3541236877f9405c93a8`

## Outcome

The mission stopped at the binding backtest capacity ceiling before any EA
generation, source edit, compile, compile enqueue, Q02 append, claim, dispatch,
or tester launch. Five two-second whole-host CPU samples averaged 95.111207%
and peaked at 99.516854%, crossing the 97% hard ceiling. The canonical farm
also reported eight active work items, above the seven-active-row paced
admission ceiling.

## Frontier and non-duplicate fallback

The documented 66-pair scan qualified only two relationships, and both anchors
are already beyond Q02:

- `QM5_12532` AUDUSD/NZDUSD has logical-basket Q02 `PASS`, Q04 `PASS`, then
  Q05 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY has logical-basket Q02 `PASS`, then Q04 `FAIL`.

The existing-card fallback remains `QM5_12507_pair-coint-z`, a concrete
EURUSD/GBPUSD H1 basket. Its canonical logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` was reread as pending, unclaimed,
attempt zero, without a verdict. It is the sole open row for the exact EA,
phase, and logical symbol. A guarded `mark-priority-track --dry-run` returned
`already_priority_track=true`; a second enqueue or priority mutation would be
duplicate work and was refused.

## PACER guard and fixed-risk contract

No generated `.mq5` was written or edited, so the mandatory post-write audit
boundary was not entered. The existing fallback source was nevertheless
checked read-only with the binding command:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5"
```

It exited zero with `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, one
source, and zero findings. No compile command or compile enqueue followed.
The authenticated logical backtest setfile remains fixed-risk with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Capacity evidence

CPU samples at 2026-09-09T02:32:01Z through 02:32:09Z were
`99.169949`, `99.516854`, `92.187601`, `91.753711`, and `92.927919`
percent. Free physical memory was 37.592 GiB of 63.120 GiB.

The active-row observation returned:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T1 | Q04 | QM5_10008 | USDJPY.DWX | `7b7e7d7e-7c4b-4f49-94d2-04575085837d` |
| T8 | Q04 | QM5_10492 | USDJPY.DWX | `54396baf-62c7-44e0-9a1a-45aab2defa06` |
| T7 | Q04 | QM5_11049 | EURUSD.DWX | `d0961af2-2e4d-4376-8c75-3cf6fb00b1a6` |
| T4 | Q04 | QM5_11353 | GBPUSD.DWX | `03302864-c382-4b00-ae3b-ab20bf959ffe` |
| T5 | Q04 | QM5_1634 | EURUSD.DWX | `1e732a98-c1cc-40c3-b8ac-eb6214db07ba` |
| T9 | Q04 | QM5_20106 | EURUSD.DWX | `8574cecb-2bc7-4767-9aa4-e471171e6bf0` |
| T10 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `014f7d48-8fc5-5185-9c41-d3c5ae2ad1fb` |
| T3 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `37f8dbe6-5108-5e90-b0fd-86a672a030f5` |

The path-aware process census found seven running factory MT5 terminals
(`T1`, `T3`, `T4`, `T5`, `T7`, `T8`, and `T9`), no duplicate workers, and no
orphaned terminal processes. `T_Live` and the external FTMO terminal were
observed only to exclude them and were not controlled.

## Safety

No Strategy Card, EA source or binary, setfile, basket manifest, registry,
magic row, farm task or work item, priority, hold, claim, terminal process,
tester, verdict, portfolio-admission/KPI/Q08-contribution surface, portfolio
gate, `T_Live` manifest or terminal, deploy artifact, or AutoTrading state was
changed. Unrelated shared-worktree changes were preserved and excluded from
this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_hard_capacity_stop_20260909T023209Z_board_advisor.json`.
