# FX cointegration hard CPU stop

Recorded: 2026-09-08T19:16:00Z (21:16 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `fe1c047183b4eab2af22f9c521a2d855b76f9fc6`

## Outcome

The mission stopped at the binding backtest CPU ceiling before selecting,
claiming, generating, compiling, or enqueueing an EA. Five two-second
whole-host CPU samples averaged 94.306227% and peaked at 99.170736%, crossing
the 97% hard ceiling. The canonical farm also had seven active work items,
exactly the paced-fleet row ceiling.

The same-day 66-pair reconciliation remains authoritative: no unbuilt approved
FX cointegration relationship exists. The two preferred anchors do not need
Q02 repair: `QM5_12532` has logical-basket Q02 `PASS`, Q04 `PASS`, then Q05
`FAIL`; `QM5_12533` has logical-basket Q02 `PASS`, then Q04 `FAIL`.

The mission-authorized existing-card fallback remains
`QM5_12507_pair-coint-z`, a concrete EURUSD/GBPUSD H1 basket. Its canonical
logical Q02 work item `547c4fd3-f3fd-4c59-b9dc-654e96521251` remains
`pending`, unclaimed, attempt zero, without a verdict, and already carries
`priority_track=true`. A second enqueue would duplicate governed work.

## Binding capacity evidence

`farmctl work-items --status active` returned seven rows:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T5 | Q04 | QM5_10800 | GBPUSD.DWX | `6485801c-c797-4197-b6bb-1ce60d4e4003` |
| T9 | Q04 | QM5_11458 | USDCAD.DWX | `eb5d3d30-b493-4513-ac0b-347a8183d0da` |
| T8 | Q07 | QM5_41158 | XTIUSD.DWX | `2c3757b4-1bbc-46c6-b19b-f1c5423b4127` |
| T4 | Q03 | QM5_41184 | XTIUSD.DWX | `9a185bd5-a60f-4889-bab5-441afe314696` |
| T10 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `d8759e94-f8a5-5669-b5f9-048000e3fc0f` |
| T6 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `5fb609cc-e84b-578d-8771-f565f2b62f58` |
| T7 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `3c785d1b-7753-5e09-ad6f-827d3460368b` |

The CPU samples were 99.170736%, 96.210773%, 86.053000%, 94.144807%, and
95.951821%. Free physical memory was 34.017 GiB of 63.120 GiB. Six factory
terminals were running (`T4`, `T5`, `T6`, `T8`, `T9`, and `T10`), with no
duplicate workers or orphaned terminal processes. `T_Live` and the external
FTMO terminal were observed only by the read-only slot census and were not
controlled.

## PACER guard and safety boundary

No generated `.mq5` source was written or edited, so the mandatory post-write
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile command or compile enqueue was attempted, and no Q02 row was appended.

No Strategy Card, EA source or EX5, registry or magic row, resolver, setfile,
basket manifest, farm task or work item, priority, hold, claim, terminal,
tester, verdict, portfolio-admission/KPI/Q08-contribution surface, portfolio
gate, `T_Live` manifest or terminal, deploy artifact, or AutoTrading state was
changed. Unrelated shared-worktree changes were preserved and excluded from
this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_hard_cpu_stop_20260908T191600Z_board_advisor.json`.
