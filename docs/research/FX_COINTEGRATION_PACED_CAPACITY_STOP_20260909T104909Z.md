# FX cointegration paced capacity stop

Recorded: 2026-09-09T10:49:09Z (12:49 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `d968ba2b721a6eb53d361fbd4e13fd08f42e19ad`

## Outcome

The mission stopped at the binding paced backtest-capacity ceiling before any
card or EA generation, source edit, compile, compile enqueue, Q02 append,
claim, dispatch, or tester launch. The canonical farm reported eight active
work items, above the seven-active-row paced admission ceiling. Five whole-host
CPU samples were 69.142122%, 67.190114%, 66.021682%, 71.924832%, and
73.510339% (average 69.557818%, maximum 73.510339%); the stop is the occupied
farm admission ceiling, not the 97% instantaneous CPU guard. Free physical
memory was 6.644 GiB of 63.120 GiB.

## Frontier and fallback decision

The frozen 66-pair discovery was reproduced read-only with
`analyze_cross_asset_v3.py --include-negative-hedges`. Only the seven already
mechanized strict rows clear the declared DEV/OOS/trade-count bar, including
the two preferred anchors. The anchors are not blocked at Q02:

- `QM5_12532` AUDUSD/NZDUSD has logical-basket Q02 `PASS`, Q04 `PASS`, then
  Q05 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY has logical-basket Q02 `PASS`, then Q04 `FAIL`.

The mission-authorized existing-card fallback remains
`QM5_12507_pair-coint-z`, a concrete EURUSD/GBPUSD H1 basket. Its logical Q02
work item `547c4fd3-f3fd-4c59-b9dc-654e96521251` was reread as pending,
unclaimed, attempt zero, and without a verdict. A guarded priority-track
dry-run returned `already_priority_track=true`. Appending or reprioritizing a
second row would be duplicate work, so the existing canonical row was left for
the paced terminal workers after capacity recovers.

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

The eight active rows at the observation time were:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T2 | Q02 | QM5_11240 | GBPUSD.DWX | `84aa0e4b-a970-440d-8581-831ca726f817` |
| T5 | Q08 | QM5_41165 | XTIUSD.DWX | `376bea1c-cde6-4239-bf95-2f9d4b2e4ef0` |
| T10 | Q07 | QM5_41176 | XTIUSD.DWX | `a486680e-c81b-4fbd-8d88-890de92d52bc` |
| T8 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `d6d9e356-e4a9-5a25-b3ae-b70bd91d55d8` |
| T3 | OPT_CENSUS | QM5_41322 | XAUUSD.DWX | `c476b90e-643f-5b25-bc9a-4099aa792c2f` |
| T7 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `4f90cf2a-b8fd-5646-af30-93dcbf1d244c` |
| T1 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `0a5520f8-8074-57bc-b0ea-69d350456449` |
| T6 | Q04 | QM5_9121 | GBPUSD.DWX | `1a9ad7eb-7c87-4a13-85ff-46afce0b6f0c` |

The path-aware process census observed factory tester processes on T1, T2,
T3, T5, T6, T7, T8, and T10, with one worker daemon present for every T1-T10
slot and no duplicate worker or orphaned factory process. `T_Live` and the
external FTMO terminal were observed only to exclude them and were not
controlled.

## Safety

No Strategy Card, EA source or binary, setfile, basket manifest, registry,
magic row, farm task or work item, priority, hold, claim, terminal process,
tester, verdict, portfolio-admission/KPI/Q08-contribution surface, portfolio
gate, `T_Live` manifest or terminal, deploy artifact, or AutoTrading state was
changed. Unrelated shared-worktree changes were preserved and excluded from
this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_paced_capacity_stop_20260909T104909Z_board_advisor.json`.
