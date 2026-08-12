# QM5_11619 diverse-FX Q02 history-sync recovery — 2026-08-05

## Disposition

`REPAIR_COMPILED_AWAITING_Q02_CAPACITY`: the approved H1 five-major FX sleeve
was blocked at Q02 by terminal history synchronization failures, not by an
economic verdict. Its unchanged strategy source has been rebuilt against the
current V5 framework, and all five fixed-risk backtest setfiles now explicitly
disable every news axis so the framework can skip calendar initialization.

No fresh tester was started. The farm was already at its backtest CPU ceiling,
and two pre-binding Q02 rows for this EA remain pending for the governed
scheduler. This record does not infer a Q02 result or authorize any later phase
or live use.

## Scope and farm claim

- Branch: `agents/board-advisor`.
- Farm claim: `b9abd2c1-d2a7-47f8-8657-6b484a950eeb`, assigned to
  `codex:agents/board-advisor` before editing.
- Pre-claim SQLite backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11619_claim_20260805T150511Z.sqlite`.
- Approved card:
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11619_robo-psar01-ema6-11-34-h1.md`.
- Card lineage: RoboForex educational PDF; fixed PSAR plus 6/11/34 EMA fan,
  H1, no ML/adaptive/banned-indicator mechanics.
- Sleeve: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, and
  `AUDUSD.DWX`.
- Registry preflight: EA id 11619 and magic slots 0–4 are active; the five
  symbols are present in the DarwinexZero symbol matrix.

There was no competing active agent claim or Q02/Q03 economic verdict for this
EA when the claim was inserted.

## Immutable failure evidence and diagnosis

The latest preserved EURUSD row is
`7a25fdcb-494e-44cd-a534-065bc017c94b`, final state
`failed / INFRA_FAIL`, attempt 3. Its evidence is:

`D:\QM\reports\work_items\7a25fdcb-494e-44cd-a534-065bc017c94b\QM5_11619\20260805_090103\summary.json`

All three attempts are classified `NO_HISTORY`; each produced an empty tester
identity, zero bars, and no valid test interval. The preserved identity proves
that the source and deployed EX5 matched and remained stable at old SHA-256
`e70ca7f4902d662750a6843be7383db8d573af65b62e6c0706068f8f412ed430`.

The prior row `d547c131-5013-49a6-acb8-028d666293c1` was labelled
`ONINIT_FAILED`, but the terminal journal shows the actual boundary:

- `D:\QM\mt5\T5\Tester\logs\20260805.log`, 09:10:58–09:10:59: the tester
  loads the expert, announces the EURUSD H1 interval, then immediately records
  `EURUSD.DWX: history synchronization error`.
- `D:\QM\mt5\T3\Tester\logs\20260805.log`, 11:01:40–11:02:39: three
  consecutive attempts follow the same load/announce/history-error sequence.

No EA initialization message occurs between the test announcement and the host
history error. The apparent ONINIT result is therefore an adjacent-log
classification, while the underlying blocker is terminal/history
infrastructure. There is no strategy-performance evidence to adjudicate.

The old EX5 also predates the current framework's lazy news-calendar
initialization. The existing setfiles did not spell out the news-off baseline,
so rebuilding the current framework and sealing all news axes off removes that
avoidable initialization dependency without altering the approved mechanics.

## Minimal repair

- The `.mq5` strategy source is byte-for-byte unchanged, SHA-256
  `56f300a6548dde24f77ab6508c405781046f890d4742519908b04518e07ad6d7`.
- Rebuilt the EX5 in place against the current V5 framework. New SHA-256:
  `4af188afc102ed145dff707af06680e77fdaa23183f9ba19d6a29d12d4f4a603`.
- Added the explicit structural Q02 baseline to all five backtest setfiles:
  `qm_news_temporal=0`, `qm_news_compliance=0`,
  `qm_news_mode_legacy=0`, `qm_news_stale_max_hours=336`, and
  `qm_news_min_impact=high`.
- Preserved `RISK_FIXED=1000`, `RISK_PERCENT=0`, every strategy parameter,
  symbol, timeframe, magic slot, and portfolio weight.
- Refreshed the standard setfile `build_hash` seals and recorded the repair in
  `SPEC.md`.

Setfile SHA-256 identities after the repair:

| Symbol | SHA-256 |
|---|---|
| AUDUSD.DWX | `2c2121db82ff9f75039a00a9351db9bea2e3fd81bedb7aed7877637482ca519f` |
| EURUSD.DWX | `eaf0f8c74a24a449a9c82a2e2f5752571490ee622567a4ec117566300d7825c8` |
| GBPUSD.DWX | `c5b826e8acc94e716f7ef30f79ffcb4a5bf0dc9c8cda165c159c7321082c6c4a` |
| USDCHF.DWX | `3d9c96dffd04ffeebbdd607aa3082ee94f64a5d4652795f1710fbf472dd91357` |
| USDJPY.DWX | `13763dbae1043cd038b3e8d5098bcf4502110483edad2fae2efd111e28b5d441` |

## Build and static verification

- `validate_spec_doc.py`: `PASS`.
- One strict `build_check.ps1` invocation: compiler `PASS`, 0 errors,
  0 warnings; aggregate build check `PASS`, 0 failures, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260805_151415\QM5_11619_robo-psar01-ema6-11-34-h1.compile.log`,
  SHA-256
  `f97f18f0017819cbdbe0e8fd8b25e90112747baf12bc08ef0419384a958ea530`.
- Compile summary:
  `D:\QM\reports\compile\20260805_151415\summary.csv`, SHA-256
  `69369511da40deb7c6693b05b77bc33bd4cddce484cc884434e89cba781059fd`.
- Build report:
  `D:\QM\reports\framework\21\build_check_20260805_151415.json`, SHA-256
  `b4ce73e0fc199d398a743ae0c48ee43524d0cb4d78cd6d30ca2da6a2966d6899`.

## Q02 queue and CPU boundary

The guarded append-only rerun request against terminal EURUSD row
`7a25fdcb-494e-44cd-a534-065bc017c94b` correctly refused with
`historical_artifact_binding_mismatch`: that historical row is sealed to the
old EX5. The call inserted no row and mutated no historical evidence. It was
not bypassed.

Two non-duplicate pre-binding Q02 rows already remain `pending`, unclaimed, and
without an economic verdict:

- `d53b38ba-221a-41eb-9788-6dc2f6b8805c` — `USDCHF.DWX`, H1.
- `f6227c5b-450d-4cf1-96a4-d05d49f782a1` — `USDJPY.DWX`, H1.

At the queue decision, `farmctl mt5-slots` reported seven running managed
T1–T10 terminals and nine `terminal64.exe` processes in total. That is the
backtest CPU ceiling. No `dispatch-tick`, smoke run, manual terminal launch,
wait loop, duplicate queue row, or pipeline phase was performed. The two
existing pending rows are left to the farm's normal current-artifact binding
and capacity controls.

No T_Live file, process, manifest, portfolio gate, AutoTrading state, deploy
state, or terminal configuration was changed.
