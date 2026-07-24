# QM5_12822 XTIUSD Q02 magic-binary recovery

Date: `2026-07-24`

Branch: `agents/board-advisor`

EA: `QM5_12822_eia-jetfuel-pb`

Farm claim: `eb0d6f31-b529-44c3-b9a6-2f6c633bc6d3`

## Selection

No unclaimed approved diversity build cleared the build gate: the rates and
lumber candidates require series absent from the governed DWX matrix, while
the remaining feasible backlog item was another index sleeve.

`QM5_12822` was selected under mission priority 2. It is a low-frequency D1
WTI summer jet-fuel-demand pullback sleeve, distinct from the existing WTI
breakout and natural-gas sleeves. Its approved Strategy Card cites official
U.S. Energy Information Administration jet-fuel production and consumption
research. Runtime is price/calendar-only, and its backtest setfile uses
`RISK_FIXED=1000` with `RISK_PERCENT=0`.

## Failure and root cause

The EA had 13 Q02 attempts and no strategy verdict; all 13 ended as
infrastructure failures. The latest failed attempt was:

- Work item: `d883dd4f-51ab-464c-8b5e-00e3a0abc36f`
- Verdict: `INFRA_FAIL`
- Reason classes: `ONINIT_FAILED`, `INCOMPLETE_RUNS`
- Summary:
  `D:\QM\reports\work_items\d883dd4f-51ab-464c-8b5e-00e3a0abc36f\QM5_12822\20260724_064522\summary.json`
- Tester log:
  `D:\QM\mt5\T9\Tester\logs\20260724.log`, line 1412000

The tester log gives the exact initialization failure:

```text
EA_MAGIC_NOT_REGISTERED: ea_id=12822 slot=0 magic=128220000
```

The governed registry currently has the active row
`12822,eia-jetfuel-pb,0,XTIUSD.DWX,128220000,...,active`, and the generated
`QM_MagicResolver.mqh` contains `128220000`. The failed binary hash
`7857f88662940bd5f81463882243142136a753e925c5079dc26266b78ff8dd77`
therefore represented a stale resolver snapshot.

## Repair and validation

The unchanged EA source was rebuilt against the current generated resolver.
The strict framework build gate regenerated only the binary and the setfile
build binding.

- Specification validation: PASS
- Strict compile: PASS, 0 errors, 0 warnings
- Framework build check: PASS, 0 failures, 0 warnings
- Compile log:
  `C:\QM\repo\framework\build\compile\20260724_084323\QM5_12822_eia-jetfuel-pb.compile.log`
- Compile summary:
  `D:\QM\reports\compile\20260724_084323\summary.csv`
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260724_084323.json`
- MQ5 SHA-256:
  `9ae744286f7d0895a39bd0ef3265dc5c2e6674a2f4ab4b7838f7e98760f74e99`
- Rebuilt EX5 SHA-256:
  `80a6352963f665fb53a38d8ca6d9bf3dd1a2a39912b7a19331fca795b852e283`
- Refreshed setfile SHA-256:
  `f8d3641b6bbd8ec1d3f5f8220db70c21c9f9293111da8510e38c9c8013fdeda6`

The source hash is unchanged. The setfile remains `RISK_FIXED`; its generated
build hash was refreshed to bind it to the rebuilt artifact.

## Farm handoff

The failed work item was atomically reactivated as the single evidence-bound
Q02 retry. At enqueue it was `pending`, unclaimed, and reset to attempt 0.
Its payload binds the MQ5, rebuilt EX5, and refreshed setfile hashes above and
retains the prior failure evidence.

The capacity check showed four active factory terminals (`T2`, `T4`, `T6`,
and `T8`), below the seven-terminal backtest CPU ceiling. No backtest was
launched manually; the paced dispatcher owns execution.

No `T_Live` artifact, AutoTrading setting, portfolio gate, live manifest, or
strategy mechanic was touched.
