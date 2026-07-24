# QM5_20099 Q02 magic-resolver repair and CPU-ceiling stop

Date: 2026-07-24

Branch: `agents/board-advisor`

EA: `QM5_20099_wti-samecal`

Instrument / timeframe: `XTIUSD.DWX` / `D1`

## Why this unit was selected

The diversity-first build backlog had no eligible unclaimed card:

- `QM5_1459` requires unavailable lumber / IEF inputs and remains R3 `UNKNOWN`.
- `QM5_1457` requires non-Darwinex rates inputs.
- `QM5_20062` was already actively claimed.
- `QM5_20061` is another index sleeve and therefore lower-diversity than this
  WTI infrastructure recovery.

`QM5_20099_wti-samecal` is a structural, low-frequency WTI same-calendar
seasonality sleeve on energy beyond XNG. Its first Q02 attempt failed at
initialization, making it the highest-diversity non-duplicate infrastructure
repair available under mission priority 2.

Farm coordination was claimed atomically before diagnosis:

- task: `23a3297c-b035-46af-9031-448b4c54fc95`
- claim key:
  `manual:codex:agents/board-advisor:QM5_20099:q02-oninit-recovery`
- pre-change online backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20099_q02_oninit_repair_20260724T123548Z.sqlite`

## Failed Q02 evidence and root cause

Source work item:
`cc304262-dbfa-410d-b273-7318751374e5`

Immutable summary:
`D:\QM\reports\work_items\cc304262-dbfa-410d-b273-7318751374e5\QM5_20099\20260724_122632\summary.json`

Tester journal:
`D:\QM\reports\work_items\cc304262-dbfa-410d-b273-7318751374e5\QM5_20099\20260724_122632\raw\run_01\20260724.log`

The journal records:

```text
EA_MAGIC_NOT_REGISTERED: ea_id=20099 slot=0 magic=200990000
tester stopped because OnInit returns non-zero code 1
```

This was an infrastructure failure, not a strategy verdict:

- Q02 verdict: `INFRA_FAIL`
- reason: `ONINIT_FAILED;INCOMPLETE_RUNS`
- the canonical magic row already existed and was active:
  `20099,wti-samecal,0,XTIUSD.DWX,200990000,...,active`
- the same EA existed in `ea_id_registry.csv`
- `QM_MagicResolver.mqh` did not contain magic `200990000`

The EX5 had therefore been compiled against a stale generated resolver even
though both source registries were correct.

## Deterministic repair

The canonical generator was run from `C:\QM\repo`:

```powershell
python framework/scripts/update_magic_resolver.py
```

Result:

- 15,065 rows kept
- the resolver delta added exactly
  `(20099, 0, XTIUSD.DWX, 200990000)`
- no resolver tuple was removed
- the known pre-existing missing-directory warnings for EA IDs 1001, 1015,
  and 1016 remained unchanged

The EA was then rebuilt under the standard build guardrails:

```powershell
pwsh -NoProfile -File framework/scripts/compile_one.ps1 `
  -EAPath framework/EAs/QM5_20099_wti-samecal/QM5_20099_wti-samecal.mq5 `
  -Strict
python framework/scripts/validate_spec_doc.py `
  framework/EAs/QM5_20099_wti-samecal
pwsh -NoProfile -File framework/scripts/build_check.ps1 `
  -EALabel QM5_20099_wti-samecal -SkipCompile
```

Validation:

- strict compile: `PASS`, 0 errors, 0 warnings
- spec validation: `PASS`
- build check: `PASS`, 0 failures, 0 warnings
- build-check report:
  `D:\QM\reports\framework\21\build_check_20260724_124042.json`
- source logic remained unchanged
- canonical backtest set remains `RISK_FIXED=1000` and `RISK_PERCENT=0`

Artifact hashes after repair:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `29789CA132A428F0D90346B42D90F848051786C7DA1C2C81E374CB2309B8A22E` |
| EX5 | `1C2073069227E1DA91D7D9BBB0E99BED0E5EE8266FFBFC6A3E26722C56D63CE8` |
| magic registry | `4CA5A5FF0C9BF90D49A612555918F50B4C8125D75F6646DDD370B49C2656C894` |
| generated resolver | `9669F837A0BBB8BE5507D76A14059A69EDEDEF3DFAC3044E969F9FA3E765D6C7` |
| canonical setfile | `4C944F382BC351E29EC81E8D3C12632382EDCC481E56FA5A8DB730848703EEB5` |

The farm pump's deterministic artifact guard committed the rebuilt EX5 and
resolver together as `2ac160bf469b47c35e4280ba608e4cf70ecc6c4b`.

## CPU-ceiling stop

Immediately before re-enqueue, `farmctl.py mt5-slots` reported nine running
factory terminals:

`T1, T2, T3, T4, T5, T6, T7, T8, T10`

This exceeds the paced fleet ceiling of seven. Per the mission stop
condition:

- no smoke or backtest was launched manually
- no Q02 work item was inserted or reopened
- no terminal was dispatched
- the existing failed Q02 evidence was not overwritten
- no T_Live, AutoTrading, portfolio gate, or deploy manifest was touched

At the stop point, QM5_20099 had no pending or active Q02/Q03 work item. A
later paced agent may re-enqueue the repaired EX5 when factory occupancy is
below the ceiling.
