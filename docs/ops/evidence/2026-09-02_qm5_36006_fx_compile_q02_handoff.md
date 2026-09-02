# QM5_36006 FX compile and Q02 handoff — 2026-09-02

## Outcome

`QM5_36006_nnfx-halftrend-jurik-coppock-engine` is now a strict-clean compiled
D1 FX candidate and has entered the paced pipeline through one priority-track
Q02 canary. The farm build task is `done`; the canonical Q02 item is pending.

This was the highest-diversity exact pending approved-card build at claim time:
EURUSD, GBPUSD, and USDJPY diversify the current Q08 survivor concentration in
indices, metals, and energy. The approved card is mechanical, non-ML,
low-frequency, and records R1/R2/R3/R4 as `PASS`.

## Governed coordination

- Agent task: `e4fb46e5-3bbb-4510-b723-21a7613e1762`
- Build task: `5fbafbb8-c8c6-4480-8157-b2577c229a1b`
- Compile item: `d445db75-f0c0-422b-9517-622028203c7b`
- Claim: `codex:agents/board-advisor` at `2026-09-02T13:54:52Z`
- Branch: `agents/board-advisor`

The released compile item remained bound to the exact pending build task and
MQ5 SHA-256 `014dc6e0c3d8e466a2947ae0ac1e6590ac0c491b17a67c37cbae748cc665dfb6`.
The governed release used `BEGIN IMMEDIATE`, a verified backup, compare-and-swap
validation, and commit. Its pre-mutation backup is
`D:\QM\strategy_farm\state\backups\farm_state_before_compile_wave_20260902T135530Z_5824316a.sqlite`
(SHA-256 `142a6fbac06bdecb7a82d87adf373e157f893e3fadf8673031dcb984c7dfb6ba`).

## Build evidence

T1 claimed the source-bound utility item at `14:03:57Z` and completed it at
`14:04:33Z`:

- compile: `PASS`, 0 errors, 0 warnings;
- strict build check: `PASS` (one non-blocking event-vocabulary advisory);
- SPEC validation: `PASS`;
- post-generation guardrail validation: `PASS`, zero findings;
- EX5: 441,696 bytes, SHA-256
  `57e021403dae0d56d54270d6d1a72d8ad780724a430548f95039ef91f7f47c8d`;
- generated setfiles: 3, each with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`;
- active magic rows: 360060000/0 EURUSD, 360060001/1 GBPUSD, and
  360060002/2 USDJPY.

The external compile receipt is
`D:\QM\reports\work_items\d445db75-f0c0-422b-9517-622028203c7b\QM5_36006\COMPILE_EA\compile_evidence.json`
(SHA-256 `91c6acbcea293b07d35c5ddf2a171f00c35789201b169411dcd8f595824e7858`).

## CPU ceiling and smoke boundary

The required fresh pre-smoke CPU window was
`[96.7, 99.1, 98.0, 99.5, 100.0]`, averaging `98.66%` and peaking at
`100.0%` against the `97%` ceiling. The canonical DB simultaneously showed
eight active paced-fleet work items. Per the mission stop condition, this unit
started no smoke, tester, dispatcher, worker tick, optimization, or backtest.

The durable build result therefore records `deferred_p2_smoke` with explicit
fleet-saturation evidence. The Q01 admission helper classifies it as the
sanctioned `q01_smoke_saturation_waiver`; the normal pump owns the later smoke
successor when capacity returns.

## Pipeline handoff

`farmctl record-build` accepted the result at `2026-09-02T14:11:23Z`, marked
the build task `done`, and auto-enqueued:

- Q02 item `4f7cdc74-5d16-49fc-879c-8fea98605536`
- `EURUSD.DWX`, D1
- state at receipt: `pending`, attempt 0, unclaimed
- priority track: true

The canary fanout sidecar holds GBPUSD and USDJPY in `AWAITING_CANARY`; they
remain eligible for normal promotion after the canary passes or spare capacity
becomes available. The build result is
`artifacts/builds/5fbafbb8-c8c6-4480-8157-b2577c229a1b.json`
(SHA-256 `cb900916224658bad18ba464d4142efa1da283163939022a709fa6c8d35ca2e4`).

## Safety

No T_Live surface, AutoTrading setting, deploy manifest, T_Live manifest,
portfolio gate, or portfolio-admission artifact was readied or changed. Only
the exact EA binary/setfiles and this unit's build/evidence records are included
in the branch commit; unrelated shared-worktree changes are excluded.

Machine-readable receipt:
`artifacts/qm5_36006_fx_compile_q02_handoff_20260902T141123Z_board_advisor.json`.
