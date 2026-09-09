# FX cointegration hard CPU stop

Recorded: 2026-09-09T03:31:13Z (05:31 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `b67f7444081a4e506c353b1c339b4280a43876ec`

## Outcome

The mission stopped at the binding backtest CPU ceiling before any card or EA
generation, source edit, compile, compile enqueue, Q02 append, claim, dispatch,
or tester launch. Five whole-host samples taken two seconds apart were 91%,
100%, 100%, 100%, and 100%: average 98.2%, maximum 100%. This crosses the
97% hard ceiling. The canonical farm simultaneously reported seven active
work items and all ten terminal workers running.

## Frontier and fallback decision

The durable 66-pair scan qualified only two relationships. Both anchors are
already beyond Q02:

- `QM5_12532` AUDUSD/NZDUSD has logical-basket Q02 `PASS`, Q04 `PASS`, then
  Q05 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY has logical-basket Q02 `PASS`, then Q04 `FAIL`.

The governed strict sign-aware extension is also fully mechanized. Creating a
new card or build from this frontier would duplicate an existing EA.

The mission-authorized existing-card fallback remains
`QM5_12507_pair-coint-z`, a concrete EURUSD/GBPUSD H1 basket. Its logical Q02
work item `547c4fd3-f3fd-4c59-b9dc-654e96521251` was reread as pending,
unclaimed, attempt zero, without a verdict. It is the only open row for the
exact EA, phase, and logical-symbol identity, so no duplicate was enqueued.

## PACER guard and fixed-risk contract

No generated `.mq5` was written or edited, so the mandatory post-write audit
boundary was not entered. The existing fallback source was nevertheless
checked read-only with the binding command:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5"
```

It exited zero with `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, one
source, and zero findings. No compile command or compile enqueue followed. The
authenticated logical backtest setfile remains fixed-risk with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Capacity evidence

Free physical memory was 39.498 GiB. The seven active rows were:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T2 | Q04 | QM5_10297 | NZDJPY.DWX | `2076ac42-91bb-4211-820e-ac8af394d9ee` |
| T3 | Q04 | QM5_12350 | EURUSD.DWX | `86a1a17e-3b2f-4cc9-9a5d-dd0f6e3331af` |
| T6 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `e5f0f567-ade6-529e-bcd0-6ce4ddec4cdb` |
| T1 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `a11fca07-7a34-5218-803e-051a499292fa` |
| T4 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `b06689ab-0e74-59c9-807a-fe64057ff229` |
| T5 | Q04 | QM5_9229 | EURUSD.DWX | `83837c1c-a050-475a-ac23-a9b606065a2d` |
| T10 | Q04 | QM5_9291 | EURUSD.DWX | `09f00872-c770-48ca-8d52-840f913e5048` |

The path-aware process census observed factory tester processes on T1, T4,
T6, and T10 at `2026-09-09T03:31:22Z`, with no duplicate worker or orphaned
terminal process. Worker daemons were present for T1 through T10. `T_Live`
and the external FTMO terminal were observed only to exclude them and were not
controlled.

## Safety

No Strategy Card, EA source or binary, setfile, basket manifest, registry,
magic row, farm task or work item, priority, hold, claim, terminal process,
tester, verdict, portfolio-admission/KPI/Q08-contribution surface, portfolio
gate, `T_Live` manifest or terminal, deploy artifact, or AutoTrading state was
changed. Unrelated shared-worktree changes were preserved and excluded from
this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_hard_cpu_stop_20260909T033113Z_board_advisor.json`.
