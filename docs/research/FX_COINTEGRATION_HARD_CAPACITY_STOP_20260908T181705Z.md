# FX cointegration hard capacity stop

Recorded: 2026-09-08T18:17:05Z (20:17 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `f3a32bf9abe547db76a4487480481f7c97a2f5c9`

## Outcome

The mission stopped at its binding paced-fleet capacity gate before selecting,
claiming, generating, compiling, or enqueueing an EA. Five two-second
whole-host CPU samples averaged 84.647924% and peaked at 87.844904%, but the
canonical farm had nine active work items, above the seven-active-row ceiling.

The repository and current runtime state continue to support the existing
non-duplicate selection:

- The same-day 66-pair reconciliation records no unbuilt approved FX
  cointegration relationship.
- `QM5_12532` has logical-basket Q02 `PASS`, Q04 `PASS`, then Q05 `FAIL`.
- `QM5_12533` has logical-basket Q02 `PASS`, then Q04 `FAIL`.
- The mission-authorized fallback remains `QM5_12507_pair-coint-z`, a concrete
  EURUSD/GBPUSD H1 basket. Its canonical logical Q02 work item
  `547c4fd3-f3fd-4c59-b9dc-654e96521251` remains `pending`, unclaimed,
  attempt zero, without a verdict, and already carries
  `priority_track=true`. A second enqueue would duplicate governed work.

## Binding capacity evidence

`farmctl work-items --status active` returned nine rows:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T7 | Q04 | QM5_12364 | EURUSD.DWX | `5c8c3c96-79fb-45a0-a769-fd0b6213b82e` |
| T10 | Q07 | QM5_41158 | XTIUSD.DWX | `24da59bb-0c72-4a52-96e0-8aac2a04b524` |
| T3 | OPT_CENSUS | QM5_41163 | USDCAD.DWX | `965ac1e9-09c7-528b-9495-01dfc7eb6d3c` |
| T1 | Q08 | QM5_41167 | XTIUSD.DWX | `4d39c73c-8a1f-4c66-a90c-cd69c4c4152d` |
| T6 | Q06 | QM5_41173 | XTIUSD.DWX | `8c308842-098a-4b18-ba38-e6a3e448fb90` |
| T9 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `409b9ea7-0bdf-5b38-b031-be1fde91c8af` |
| T2 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `922f5d80-ca2e-5174-92f0-841291bbaa3e` |
| T5 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `b334caf3-5e24-5121-8e9f-d6527b75f588` |
| T4 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `326f401a-3304-5dd6-8921-37e56583d403` |

The CPU samples were 87.844904%, 83.031490%, 84.480621%, 84.091795%, and
83.790808%. Free physical memory was 27.018 GiB of 63.120 GiB. The row-count
ceiling binds independently of the instantaneous CPU sample.

## PACER build guard and safety boundary

No generated `.mq5` source was written or edited in this turn, so the mandatory
post-write `audit_framework_input_pins.py --check-source` boundary was not
entered. No compile command or compile enqueue was attempted.

No Strategy Card, EA source or EX5, registry or magic row, resolver, setfile,
basket manifest, farm task or work item, priority, hold, claim, terminal,
tester, verdict, portfolio-admission/KPI/Q08-contribution surface, portfolio
gate, `T_Live` manifest or terminal, deploy artifact, or AutoTrading state was
changed. Unrelated shared-worktree changes were preserved and excluded from
this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_hard_capacity_stop_20260908T181705Z_board_advisor.json`.
