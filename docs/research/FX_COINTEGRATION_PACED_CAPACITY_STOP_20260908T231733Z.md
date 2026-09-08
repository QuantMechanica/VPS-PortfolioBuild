# FX cointegration paced capacity stop

Recorded: 2026-09-08T23:17:33Z (2026-09-09 01:17 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `286864528ca590833a8ed959ac37de9fc6b88949`

## Outcome

The mission stopped at the binding paced backtest-capacity ceiling. The first
canonical farm read returned nine active work items and a confirmation read
returned eight, both above the seven-row admission ceiling. No EA generation,
compile, queue append, priority mutation, claim, dispatch, or tester launch
followed.

This is a fresh capacity observation, not another Q02 enqueue. The existing
EURUSD/GBPUSD fallback remains represented by exactly one pending logical Q02
row, so adding a second row would duplicate governed work.

## Frontier decision

The durable 66-pair relationship census remains authoritative: there is no
approved unbuilt FX cointegration relationship. The two preferred anchors are
not Q02 infrastructure blockers:

- `QM5_12532` has logical-basket Q02 `PASS`, Q04 `PASS`, then Q05 `FAIL`.
- `QM5_12533` has logical-basket Q02 `PASS`, then Q04 `FAIL`.

The mission-authorized existing-card fallback remains
`QM5_12507_pair-coint-z`, the concrete `EURUSD.DWX` / `GBPUSD.DWX` H1 basket.
Its canonical logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` remains pending, unclaimed, attempt
zero, without a verdict, and `priority_track=true`. A read-only
`mark-priority-track --dry-run` returned `already_priority_track=true`. The
exact open-row count for this EA, phase, and logical symbol is one. No duplicate
work item was created or reprioritized.

## Guard and fixed-risk verification

No `.mq5` source was generated or edited. The existing fallback source was
nevertheless checked with the binding audit command:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5"
```

The command exited zero with `ok=true`, predicate
`EA_FRAMEWORK_INPUT_PINNED`, one source, and zero findings. No compile command
or compile enqueue followed.

The authenticated logical setfile remains fixed-risk with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Its SHA-256 is
`f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`.

## Capacity evidence

At 2026-09-08T23:17:33Z, `farmctl work-items --status active` returned eight
rows:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T7 | Q04 | QM5_10299 | EURJPY.DWX | `a5fc7f32-fd6f-482f-9d2b-303602139e70` |
| T5 | Q04 | QM5_10661 | EURUSD.DWX | `02154a6f-22d5-4bca-b44e-eb7a6a0c029b` |
| T4 | Q04 | QM5_11082 | USDJPY.DWX | `8e03b5d1-b1ba-464d-b9a0-8230ba52c6a8` |
| T3 | OPT_CENSUS | QM5_41163 | USDCAD.DWX | `edc8cc57-e859-51d5-95d7-010cd76ccb21` |
| T9 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `738c526e-b7a6-5b09-9df7-c47c490ab621` |
| T8 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `f4ddfcfb-5337-5936-bfda-5879747d74ed` |
| T6 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `44136bb7-df68-569d-8320-822fb662a635` |
| T2 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `5b487aca-26d2-5465-897b-fa15706b676d` |

Five two-second whole-host CPU samples were `76.333561%`, `82.667759%`,
`92.383037%`, `92.455224%`, and `96.230250%` (average `88.013966%`, maximum
`96.230250%`). CPU stayed below the `97%` hard ceiling, but the active-row
admission interlock was over capacity. Free physical memory was `35.260 GiB`
of `63.120 GiB` at the confirmation read.

## Safety

No Strategy Card, EA source or binary, setfile, basket manifest, registry,
magic row, queue row, priority, hold, claim, terminal process, tester, verdict,
portfolio-admission/KPI/Q08-contribution surface, portfolio gate, `T_Live`
manifest or terminal, deploy artifact, or AutoTrading state was changed.
Unrelated shared-worktree changes were preserved and excluded from this
evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_paced_capacity_stop_20260908T231733Z_board_advisor.json`.
