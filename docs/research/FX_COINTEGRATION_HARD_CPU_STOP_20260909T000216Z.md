# FX cointegration hard CPU stop

Recorded: 2026-09-09T00:02:16Z (02:02 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `3e2406ca7ae6eec0ebbfbb6361a3b2043a2b20c9`

## Outcome

The mission stopped at the binding backtest CPU ceiling. Five two-second
whole-host CPU samples averaged 95.8% and peaked at 100%, crossing the 97%
hard ceiling. The canonical farm simultaneously reported ten active work
items, above the seven-row paced admission ceiling, and nine running factory
terminals.

No EA generation, source edit, compile, compile enqueue, Q02 append, claim,
dispatch, or tester launch followed.

## Frontier and fallback decision

The durable 66-pair reconciliation remains authoritative: the approved FX
cointegration frontier has no unbuilt relationship. The published scan itself
hard-qualified only the two anchor pairs, and both are already beyond Q02:

- `QM5_12532` AUDUSD/NZDUSD has logical-basket Q02 `PASS`, Q04 `PASS`, then
  Q05 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY has logical-basket Q02 `PASS`, then Q04 `FAIL`.

The mission-authorized existing-card fallback remains the concrete
EURUSD/GBPUSD H1 relationship in `QM5_12507_pair-coint-z`. Its logical Q02
work item `547c4fd3-f3fd-4c59-b9dc-654e96521251` was reread as pending,
unclaimed, attempt zero, without a verdict. It is the only open row for the
exact EA, phase, and logical-symbol identity. A guarded
`mark-priority-track --dry-run` returned `already_priority_track=true`; no
duplicate enqueue or queue-priority mutation was made.

## PACER build guard and risk contract

No generated `.mq5` was written or edited, so the mandatory post-write audit
boundary was not entered. The existing fallback source was nevertheless
checked read-only with the binding command:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5"
```

It exited zero with `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, one
source, and zero findings. The authenticated logical backtest setfile remains
fixed-risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## Capacity evidence

CPU samples were `100`, `100`, `94`, `97`, and `88` percent. Free physical
memory was 33.305 GiB of 63.120 GiB.

The ten active rows were:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T8 | Q04 | QM5_10183 | EURAUD.DWX | `cbfc5c58-db31-4b4f-a6fd-14221b2bafe6` |
| T6 | Q04 | QM5_11886 | USDJPY.DWX | `b979dd1c-748f-4f3c-9cee-8c14c1bfb98c` |
| T1 | Q04 | QM5_1371 | USDCHF.DWX | `c0b5a327-c833-4e8e-897c-3f9bdd39beb2` |
| T2 | Q04 | QM5_1386 | AUDUSD.DWX | `c30c0a57-5bfd-44c7-b69e-bfc914e0b33d` |
| T10 | Q04 | QM5_1443 | NZDUSD.DWX | `4fe011c7-2fef-441a-bca8-7ceed1774af2` |
| T4 | OPT_CENSUS | QM5_41163 | USDCAD.DWX | `ba4db336-60d4-5568-95f5-b95885317480` |
| T3 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `dd88d8f2-c7ea-52db-ad3c-eda37a97bc6a` |
| T7 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `5498a088-0c79-551f-85dc-9ddd44a9673d` |
| T5 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `4d699393-2ab1-5e23-9e1c-92b7c240b644` |
| T9 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `089dd586-a728-5ade-a393-08dd7a819897` |

The path-aware slot census found nine factory MT5 processes (`T1`, `T2`,
`T3`, `T4`, `T5`, `T6`, `T7`, `T9`, and `T10`), no duplicate workers, and no
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
`artifacts/fx_cointegration_hard_cpu_stop_20260909T000216Z_board_advisor.json`.
