# QM5_12710 Q02 stale-magic rebuild

Date: 2026-07-24

Branch: `agents/board-advisor`

EA: `QM5_12710_commodity-tsmom-12m-atr`

Farm claim: `71babee8-bc17-45b2-8a84-fb613c32a184`

## Selection

The approved-card build backlog had no unbuilt card. `QM5_12710` was selected
under the diverse-instrument Q02 infrastructure-recovery priority. It is a
single-symbol WTI (`XTIUSD.DWX`) D1 sleeve with:

- peer-reviewed Moskowitz, Ooi, and Pedersen (2012) time-series-momentum
  lineage;
- a deterministic 12-month return-sign signal and fixed ATR-percent
  participation corridor;
- monthly rebalance, approximately 5-9 expected entries per year;
- no ML, grid, martingale, or external runtime feed; and
- a canonical backtest setfile with `RISK_FIXED=1000` and `RISK_PERCENT=0`.

The guarded farm claim found no pending/active work item, downstream verdict,
open agent task, or prior equivalent repair for this EA.

## Failure and root cause

- Source Q02 work item:
  `ecd82fa8-e089-493a-aeec-ee2be79165b3`
- Verdict: `INFRA_FAIL`
- Reason classes: `ONINIT_FAILED`, `INCOMPLETE_RUNS`
- Terminal: `T2`
- Evidence:
  `D:\QM\reports\work_items\ecd82fa8-e089-493a-aeec-ee2be79165b3\QM5_12710\20260724_013055\summary.json`

The retained T2 tester log gives the exact initialization failure:

```text
2018.07.02 00:00:00   EA_MAGIC_NOT_REGISTERED: ea_id=12710 slot=0 magic=127100000
tester stopped because OnInit returns non-zero code 1
```

This was reproducible across prior T2/T4/T6/T9/T10 attempts. The registry now
contains the active mapping `12710 / slot 0 / XTIUSD.DWX / 127100000`, and the
current generated `QM_MagicResolver.mqh` contains magic `127100000`. The failed
binary was built on 2026-06-29 with SHA-256
`62bdda90543d6917f41f69b17955e4974b54165aa03664ff8aac09a9b6091ad6`,
before the current resolver. The cause was therefore a stale EX5 compiled
against an older registry snapshot, not strategy mechanics or missing history.

## Repair and validation

The unchanged MQ5 source was force-recompiled against the current framework
includes. The canonical setfile build binding was refreshed; no alpha,
parameter, registry, or risk-setting change was made.
The deterministic artifact pump captured the rebuilt EX5 and setfile in commit
`fe7370cce`.

- Strict compile: `PASS`, 0 errors, 0 warnings
  - log:
    `C:\QM\repo\framework\build\compile\20260724_204345\QM5_12710_commodity-tsmom-12m-atr.compile.log`
  - summary: `D:\QM\reports\compile\20260724_204345\summary.csv`
- Framework build check: `PASS`, 0 failures, 0 warnings
  - report:
    `D:\QM\reports\framework\21\build_check_20260724_204358.json`
- Build guardrails: `PASS`, no findings
- SPEC validation: `PASS`, 1 of 1
- MQ5 SHA-256:
  `c146523dae18a0bcfd15564c084158b31c4ae47c117929fba8e99718cf98887b`
- rebuilt EX5 SHA-256:
  `14b319183494afcb58b23fe8e7b6db46f9708b9a898addaade9be657ed704213`
- refreshed setfile SHA-256:
  `702b1d39992025a8fc1cc2824caa477c109c76b7c98965d423abfc7cd3691cb5`

The farm database was backed up before the claim and passed
`PRAGMA quick_check`:

```text
D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12710_q02_infra_claim_20260724T204133Z.sqlite
```

## CPU-ceiling stop

At `2026-07-24T20:45:21Z`, `farmctl mt5-slots` showed eight active factory
terminals: `T1`, `T2`, `T3`, `T4`, `T6`, `T7`, `T8`, and `T9`. This is above
the documented seven-job backtest CPU ceiling. `T_Live` was excluded from the
factory count.

Per the mission stop condition, the failed Q02 row was not reopened and no
replacement was inserted or dispatched. The rebuilt package is ready for a
future paced agent to re-enqueue once factory usage is below the ceiling.

No manual smoke, pipeline phase, tester launch, `T_Live`, AutoTrading,
portfolio gate, deploy manifest, or live setfile was touched.
