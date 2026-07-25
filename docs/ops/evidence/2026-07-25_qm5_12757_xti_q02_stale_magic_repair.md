# QM5_12757 XTI Q02 stale-magic repair

Date: 2026-07-25

Branch: `agents/board-advisor`

EA: `QM5_12757_abraham-xti-pb`

Farm claim: `ff308ec8-8b93-400a-8c64-396e51c8095f`

## Selection

No distinct, buildable higher-diversity card was available. The open rates
card requires unavailable Treasury/bond data and has no complete magic
allocation; the fresh WTI build was already being handled by another paced
worker. `QM5_12757` was therefore selected under the diverse-instrument Q02
infrastructure-recovery priority.

This is an approved, non-duplicate `XTIUSD.DWX` D1 sleeve with:

- Andrew Abraham's Wiley-published trend-following book as its R1 source;
- a deterministic 20-day breakout, later boundary pullback, MACD-zero regime
  check, structural stop, ATR trail, and time exit;
- approximately 4–8 expected entries per year, with a card baseline of six;
- no ML, adaptive fitting, grid, martingale, banned indicator, or external
  runtime feed; and
- a canonical backtest setfile with `RISK_FIXED=1000` and `RISK_PERCENT=0`.

The guarded farm claim found 12 Q02 infrastructure-only outcomes but no
economic verdict, Q03 row, pending/active Q02 or Q03 work, agent claim, or
prior equivalent repair.

## Failure and root cause

- Source Q02 work item:
  `9416cfa4-a1a9-4660-b2b2-e6a477f5b360`
- Verdict: `INFRA_FAIL`
- Reason classes: `ONINIT_FAILED`, `INCOMPLETE_RUNS`
- Evidence:
  `D:\QM\reports\work_items\9416cfa4-a1a9-4660-b2b2-e6a477f5b360\QM5_12757\20260724_025602\summary.json`
- Retained tester log:
  `D:\QM\mt5\T9\Tester\logs\20260724.log`

The retained T9 log gives the exact initialization failure:

```text
2018.07.02 00:00:00   EA_MAGIC_NOT_REGISTERED: ea_id=12757 slot=0 magic=127570000
tester stopped because OnInit returns non-zero code 1
```

The same initialization-only class appeared across 12 attempts on T2, T4, T6,
T7, T9, and T10. The failed binary had SHA-256
`5217e2737f05c0dd6171c231171f7eae8c3e7d743926fb1171485cbf263f3d02`
and was compiled for the initial EA commit `ecd687355`. That commit added the
registry mapping `12757 / slot 0 / XTIUSD.DWX / 127570000` but did not update
the generated resolver. Commit `bf4d2d56d`, approximately 37 minutes later,
first added `127570000` to `QM_MagicResolver.mqh`.

The failure was therefore a stale compiled dependency, not missing XTI
history or an economic strategy verdict.

## Repair and static validation

The unchanged MQ5 strategy was recompiled against the current generated magic
resolver. The old pre-Q01 SPEC was migrated to the current seven-section
contract, and the canonical fixed-risk setfile build binding was refreshed.
No entry, exit, sizing, parameter, registry, or risk-setting change was made.

- SPEC validation: `PASS`, 1 of 1
- Strict compile: `PASS`, 0 errors, 0 warnings
  - log:
    `C:\QM\repo\framework\build\compile\20260725_045111\QM5_12757_abraham-xti-pb.compile.log`
  - summary: `D:\QM\reports\compile\20260725_045111\summary.csv`
- Framework build check: `PASS`, 0 failures, 0 warnings
  - report:
    `D:\QM\reports\framework\21\build_check_20260725_045111.json`
- Build guardrails: `PASS`, no findings
- MQ5 SHA-256:
  `7996ea6a412bf7328398a05a58d3e6307ca868e4a1b46085afbe87f2aabc46a8`
- rebuilt EX5 SHA-256:
  `21c4cdaf155cc3700c88f9e3db31366f2ef0540580546cb1fb86a01b9cacdb03`
- refreshed setfile SHA-256:
  `4e884e4e9e6d7b6e2beaaceef9fd5ebf1fd67b04051a4024e7917c002e6df574`

## Q02 enqueue

At the enqueue check, `farmctl mt5-slots` reported zero running factory test
terminals. The only observed `terminal64.exe` belonged to the path-anchored
`T_Live` terminal and was excluded. The seven-job backtest CPU ceiling was
therefore not hit.

One fresh, dispatcher-controlled Q02 row was inserted:

- work item: `eb76e076-3163-4e38-beae-c9ba19baa505`
- symbol / timeframe: `XTIUSD.DWX / D1`
- status: `pending`
- phase: `Q02`
- risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- evidence binding: exact MQ5, EX5, and setfile SHA-256 values above

The row is queued only. No manual smoke, backtest, dispatch tick, or terminal
launch was performed.

## Database and safety

SQLite backups were taken before the guarded claim and before the Q02 insert:

```text
D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12757_q02_repair_20260725T044735Z.sqlite
D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12757_q02_requeue_20260725T045422Z.sqlite
```

The live DB and both backups passed `PRAGMA quick_check`.

No `T_Live` file or process, AutoTrading setting, portfolio gate, deploy
manifest, live setfile, or manual pipeline phase was touched.
