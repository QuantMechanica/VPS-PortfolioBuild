# QM5_36006 FX compile-release CPU stop

Date: 2026-09-02

Branch: `agents/board-advisor`

Outcome: **exact successor verified; release refused at the 97% CPU ceiling**

## Selection and claim

`QM5_36006_nnfx-halftrend-jurik-coppock-engine` remained the highest-diversity
non-duplicate build handoff. Its approved D1 card targets `EURUSD.DWX`,
`GBPUSD.DWX`, and `USDJPY.DWX`, expects 25 trades per year per symbol, and has
G0 plus R1-R4 `PASS`. The reviewed HalfTrend/Jurik/Coppock/CMF implementation
is structural, non-ML, and outside the NNFX Dirty Dozen ban list.

The live farm database confirmed that build task
`5fbafbb8-c8c6-4480-8157-b2577c229a1b` was pending and not in flight, no Q02
row existed, and no competing open agent task owned this EA. A guarded
compare-and-swap claim created paced-fleet task
`ce28db7e-0cda-40a0-b4de-3cb3aeed6bc9` at `2026-09-02T11:56:45Z`.

Preflight remained green:

- `skill_build_ea_guard.py`: EA registry, magic rows, and EA directory PASS;
- `validate_spec_doc.py`: PASS;
- `validate_build_guardrails.py`: PASS with zero findings;
- source SHA-256:
  `014dc6e0c3d8e466a2947ae0ac1e6590ac0c491b17a67c37cbae748cc665dfb6`;
- all three D1 presets retain `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Exact release dry-run

The reviewed release utility selected exactly one source-fresh row and no
deferred rows:

- compile successor: `d445db75-f0c0-422b-9517-622028203c7b`;
- expected and actual MQ5 hashes matched the source hash above;
- row state: pending, unclaimed, attempt 0, no verdict;
- active hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- build binding: `5fbafbb8-c8c6-4480-8157-b2577c229a1b`.

No new build task or compile row was created.

## Hard CPU stop

The initial five-sample whole-host window was below the hard ceiling:
`46.69, 45.03, 48.16, 48.83, 57.75%` (average `49.29%`, maximum
`57.75%`). Immediately before the guarded apply, the fresh window rose to
`90.05, 92.40, 92.48, 97.95, 96.68%` (average `93.91%`, maximum
`97.95%`). The maximum crossed the binding `97%` ceiling, so the PowerShell
admission guard stopped before `release_compile_wave.py --apply` executed.

The post-stop farm census had nine active work items. The compile successor
therefore remains held, pending, unclaimed, and without an `.ex5`; Q02 remains
absent. No compile, smoke, terminal reservation, tester launch, or Q02 enqueue
occurred.

The paced claim was released at `2026-09-02T12:01:17.014539Z`. The build task
remains pending, while agent task `ce28db7e` records the capacity stop as
`BLOCKED`; this leaves no live dispatch identity that could collide with a
later continuation.

## Continuation boundary

A later paced wake must take a fresh five-sample whole-host CPU window. Only
when both average and maximum are strictly below 97% may it atomically reclaim
the existing build task, release exact compile item
`d445db75-f0c0-422b-9517-622028203c7b`, require source-bound `COMPILE_OK`, and
record the build to enqueue Q02. Do not create another build task or compile
successor.

No portfolio gate, T_Live path, deploy manifest, live setfile, or AutoTrading
setting was touched.

Machine-readable companion:
`artifacts/qm5_36006_fx_compile_release_cpu_stop_20260902T115807Z_board_advisor.json`.
