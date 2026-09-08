# FX cointegration paced capacity stop

Recorded: 2026-09-08T20:04:24Z (22:04 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `afd7c51ba05f74b4061b2722ae76e499141ed296`

## Outcome

The mission stopped at the binding paced backtest-capacity ceiling before any
EA generation, compile, queue mutation, claim, or tester dispatch. The
canonical farm had ten active work items against the seven-row ceiling, and
nine factory terminals were running against the seven-terminal ceiling.

This is a changed capacity observation, not another Q02 enqueue. The existing
EURUSD/GBPUSD fallback remains represented by exactly one pending logical Q02
row, so appending a second row would duplicate governed work.

## Frontier decision

The durable relationship census remains authoritative: all 66 unordered FX
relationships are represented by existing approved identities and EA
directories. There is no approved unbuilt pair to mechanize without duplicating
the scan.

The two preferred anchors are not Q02 infrastructure blockers:

- `QM5_12532` has logical-basket Q02 `PASS`, Q04 `PASS`, then Q05 `FAIL`.
- `QM5_12533` has logical-basket Q02 `PASS`, then Q04 `FAIL`.

The mission-authorized existing-card fallback is therefore still
`QM5_12507_pair-coint-z`, the concrete `EURUSD.DWX` / `GBPUSD.DWX` H1 basket.
Its canonical logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` remains pending, unclaimed, attempt
zero, without a verdict, and `priority_track=true`. No duplicate work item was
created or reprioritized.

## Guard and fixed-risk verification

No `.mq5` source was generated or edited. The existing fallback source was
nevertheless checked using the binding command:

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

At the snapshot, `farmctl work-items --status active` returned ten rows:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T4 | Q04 | QM5_10801 | GBPUSD.DWX | `e07d374e-e394-4040-96b6-208fdfe5c9cd` |
| T6 | Q04 | QM5_10855 | EURUSD.DWX | `065d8355-9d04-4fc6-adf2-95d4b0cf4e2d` |
| T8 | Q04 | QM5_11182 | EURUSD.DWX | `f6435ac8-da90-4314-b15b-5fe6711f72d8` |
| T10 | Q08 | QM5_41158 | XTIUSD.DWX | `ed38c5b7-cf11-4591-897f-e2aec1e6a1d8` |
| T9 | OPT_CENSUS | QM5_41163 | USDCAD.DWX | `879defb7-75de-515f-90da-5f7bf3a0bed5` |
| T2 | Q07 | QM5_41182 | XTIUSD.DWX | `d9410460-f890-4619-920a-50415c166bec` |
| T3 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `809e9a09-54a5-5376-ac01-779507d62ba1` |
| T7 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `7235d7cc-6b09-53f3-88a1-ca2e6189445b` |
| T1 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `2bbde7bc-6739-5f41-8a2e-c34a5178eb33` |
| T5 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `dfef51a5-b8b7-54e2-ab5c-805b3522bdf8` |

Nine factory terminal roots were active: T1, T2, T3, T4, T5, T7, T8, T9,
and T10. Five two-second whole-host CPU samples were 76.141350%, 71.294836%,
71.291309%, 88.087617%, and 85.513080% (average 78.465638%, maximum
88.087617%). The percentage ceiling itself was not crossed, but the active-row
and terminal-count interlocks were already over capacity. Free physical memory
was 30.601 GiB of 63.120 GiB.

## Safety

No Strategy Card, EA source or binary, setfile, basket manifest, registry,
magic row, queue row, priority, hold, claim, terminal process, tester, verdict,
portfolio-admission/KPI/Q08-contribution surface, portfolio gate, `T_Live`
manifest or terminal, deploy artifact, or AutoTrading state was changed.
Unrelated shared-worktree changes were preserved and excluded from this
evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_paced_capacity_stop_20260908T200424Z_board_advisor.json`.
