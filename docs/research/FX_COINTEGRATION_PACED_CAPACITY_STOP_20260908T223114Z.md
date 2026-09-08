# FX cointegration paced capacity stop

Recorded: 2026-09-08T22:31:14Z (2026-09-09 00:31 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `c8992758b65ebfc1803846ca9162a0a52e800556`

## Outcome

The mission stopped at the binding paced backtest-capacity ceiling. The
canonical farm had seven active work items, exactly filling the seven-row
admission ceiling. No EA generation, compile, queue append, priority mutation,
claim, dispatch, or tester launch followed.

This is a fresh capacity observation, not another Q02 enqueue. The existing
EURUSD/GBPUSD fallback remains represented by exactly one pending logical Q02
row; adding a second row would duplicate governed work.

## Frontier decision

The durable relationship census remains authoritative: all 66 unordered FX
relationships are represented by existing approved identities and EA
directories. There is no approved unbuilt pair to mechanize without duplicating
the scan.

The two preferred anchors are not Q02 infrastructure blockers:

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

The canonical logical setfile still binds `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Its SHA-256 is
`f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`.

## Capacity evidence

At the snapshot, `farmctl work-items --status active` returned seven rows:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T8 | Q04 | QM5_10485 | GBPUSD.DWX | `ce9bd435-2b5b-4b3d-b19e-529437fef286` |
| T2 | Q04 | QM5_12476 | GBPUSD.DWX | `bd538875-2990-466a-85d5-09b4113a4ee2` |
| T6 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `9248abc2-e74d-50c8-8b88-16b15997d43f` |
| T1 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `c93dcb10-947d-5f60-8de1-0a8d7e5438d5` |
| T5 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `ee950b93-30fb-5ade-8fe7-e787e06ec0e9` |
| T4 | Q04 | QM5_9236 | EURUSD.DWX | `d24d44b9-6674-4af1-ae9a-f23ec0e8dc75` |
| T9 | Q04 | QM5_9936 | GBPUSD.DWX | `8243b15e-2fdd-4fbb-9253-43aa03ef3ac6` |

Six factory terminal roots were running (`T1`, `T2`, `T4`, `T5`, `T8`, and
`T9`), with no duplicate workers or orphaned terminal processes. Five
two-second whole-host CPU samples were `94.415321%`, `96.355536%`,
`96.486519%`, `93.363424%`, and `96.484976%` (average `95.421155%`, maximum
`96.486519%`). CPU was below the `97%` percentage threshold, but the active-row
admission interlock was full. Free physical memory was `39.665 GiB` of
`63.120 GiB`.

## Safety

No Strategy Card, EA source or binary, setfile, basket manifest, registry,
magic row, queue row, priority, hold, claim, terminal process, tester, verdict,
portfolio-admission/KPI/Q08-contribution surface, portfolio gate, `T_Live`
manifest or terminal, deploy artifact, or AutoTrading state was changed.
Unrelated shared-worktree changes were preserved and excluded from this
evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_paced_capacity_stop_20260908T223114Z_board_advisor.json`.
