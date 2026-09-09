# FX cointegration paced capacity stop

Recorded: 2026-09-09T11:48:38Z (13:48 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `b2f9a8b3aa3fe4fc79464a586523aa58317ae547`

## Outcome

The mission stopped at the binding paced backtest-capacity ceiling before any
card or EA generation, source edit, compile, compile enqueue, Q02 append,
claim, dispatch, or tester launch. The canonical farm contained nine active
work items, above the seven-active-row paced admission ceiling. The first five
whole-host CPU samples were 95.036613%, 93.283201%, 96.493191%, 92.776994%,
and 92.680654% (average 94.054131%, maximum 96.493191%). A confirmation sample
after the terminal rotation averaged 75.641125% with an 85.989372% maximum,
but the canonical nine-row active workload remained above the admission
ceiling. Free physical memory at confirmation was 25.071 GiB of 63.120 GiB.

## Frontier and fallback decision

The durable 66-pair relationship census remains authoritative: all 66
relationships are represented by 123 approved identities and 123 matching EA
directories, with zero approved unbuilt identities. Creating another card or
EA would duplicate governed work. The two preferred anchors are not blocked at
Q02:

- `QM5_12532` AUDUSD/NZDUSD has logical-basket Q02 `PASS`, Q04 `PASS`, then
  Q05 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY has logical-basket Q02 `PASS`, then Q04 `FAIL`.

The mission-authorized existing-card fallback remains the approved
`QM5_12507_pair-coint-z`, a concrete EURUSD/GBPUSD H1 basket with a reputable
public GitHub source and deterministic R1-R4 `PASS` assessment. Its canonical
logical Q02 work item `547c4fd3-f3fd-4c59-b9dc-654e96521251` remains pending,
unclaimed, attempt zero, without a verdict, and already priority-tracked. It is
the only open row for the exact EA/phase/logical-symbol identity. Appending,
requeueing, reprioritizing, or manually dispatching another row would be
duplicate work, so the existing row was left for normal paced-worker pickup.

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

The nine active rows at the confirmation observation were:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T1 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `930dd903-639a-563c-b466-f018988ddefc` |
| T3 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `21c787a3-44b6-50e7-a3d7-73fb68e79fcc` |
| T4 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `fabde3a2-fbd9-590a-b79c-42885a751e2d` |
| T5 | Q04 | QM5_36002 | AUDCAD.DWX | `a07a4042-6a8b-4a26-bc84-01ccbb5fdb73` |
| T6 | Q04 | QM5_9121 | GBPUSD.DWX | `1a9ad7eb-7c87-4a13-85ff-46afce0b6f0c` |
| T7 | Q02 | QM5_36005 | GBPJPY.DWX | `c35af55f-12f8-4220-aac4-0a1e66adbd38` |
| T8 | Q02 | QM5_36005 | EURJPY.DWX | `6a41c9df-7238-4b5e-927e-efbe5220de5d` |
| T9 | Q05 | QM5_36002 | GBPJPY.DWX | `96ff5caa-9d84-4066-afcd-07b3ff9d0727` |
| T10 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `dab572fe-2d0b-5abd-9e8c-c3096f16bfd8` |

All ten terminal-worker daemons were present, with no duplicate workers or
orphaned factory processes in the path-aware census. `T_Live` and the external
FTMO terminal were observed only to exclude them and were not controlled.

## Safety

No Strategy Card, EA source or binary, setfile, basket manifest, registry,
magic row, farm task or work item, priority, hold, claim, terminal process,
tester, verdict, portfolio-admission/KPI/Q08-contribution surface, portfolio
gate, `T_Live` manifest or terminal, deploy artifact, or AutoTrading state was
changed. Unrelated shared-worktree changes were preserved and excluded from
this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_paced_capacity_stop_20260909T114838Z_board_advisor.json`.
