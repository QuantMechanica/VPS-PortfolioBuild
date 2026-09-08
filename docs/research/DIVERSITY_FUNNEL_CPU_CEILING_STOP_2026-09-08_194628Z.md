# Diversity funnel CPU-ceiling stop

Recorded: 2026-09-08T19:46:28Z (21:46 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `be1697a659e43c2edfaa156c1004f9db3631c712`

## Outcome

The diversity-first paced-fleet mission stopped at its explicit capacity gate
before backlog ranking, Strategy Card selection, or a farm claim. This is a
fresh observation, not a carry-forward of the 2026-09-07 stop: the three
whole-host CPU samples were `90.658779%`, `100.000000%`, and `100.000000%`.
Their average was `96.886260%` and their maximum was `100.000000%`. Because the
admission rule requires both values to remain strictly below `97%`, the maximum
alone refuses new work.

The independent read-only farm snapshot also found ten active governed tester
rows across T1-T10, above the seven-row pacer saturation threshold. Windows
process inspection concurrently found eight `metatester64.exe` processes under
the governed `D:\QM\mt5\T*` roots. The DB and process counts need not match at
an instant while workers turn over; both observations independently indicate a
fully occupied fleet and neither authorizes another launch.

## Active governed rows

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T1 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `92b8ec0d-dc96-5f19-ac98-e3de767c2fe3` |
| T2 | Q07 | QM5_41182 | XTIUSD.DWX | `d9410460-f890-4619-920a-50415c166bec` |
| T3 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `d787e7be-9c81-5bef-9461-1d402d23f7a2` |
| T4 | Q04 | QM5_10299 | AUDNZD.DWX | `bff3ec78-ce1f-4220-a896-e8d2086fd931` |
| T5 | Q04 | QM5_41254 | XTIUSD.DWX | `c82da4dc-b682-4b22-b5e3-9ecbf884c4bb` |
| T6 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `f9b37681-07aa-57f6-b806-e7ff421f14a8` |
| T7 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `5fc5dc95-ba05-5bce-b721-7e593dae33e5` |
| T8 | Q04 | QM5_10726 | EURUSD.DWX | `368aab46-4947-400f-a234-85c79db03ab3` |
| T9 | OPT_CENSUS | QM5_41163 | USDCAD.DWX | `079010ab-05d7-5826-94da-ac087aa341a7` |
| T10 | Q08 | QM5_41158 | XTIUSD.DWX | `ed38c5b7-cf11-4591-897f-e2aec1e6a1d8` |

The canonical farm database was opened read-only. No row was claimed, created,
requeued, reprioritized, or advanced.

## PACER guard and safety boundary

No generated `.mq5` was written or edited, so the mandatory post-write
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile command, smoke, backtest, Q02 enqueue, dispatch tick, terminal control,
or process control was run.

No Strategy Card, EA source, EX5, SPEC, setfile, identity registry, magic
registry, resolver, farm task, work item, pipeline verdict, portfolio gate,
`T_Live` manifest, deploy manifest, live terminal, or AutoTrading state was
changed. Existing unrelated shared-worktree changes were preserved and excluded
from this receipt.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260908T194628Z.json`.

## Continuation

A later paced wake should take a fresh whole-host CPU window and a fresh
read-only active-tester count. It may rank and atomically claim one distinct
diversity candidate only if the capacity admission checks clear.
