# QM5_11908 Diverse-FX Magic Repair and Q02 Requeue

## Outcome

`QM5_11908_davey-dueling-momentum-h1` was claimed as a distinct Q02
infrastructure recovery, repaired for ten registered FX symbols, rebuilt against
the current V5 framework, and returned to the paced Q02 queue. Three stage-one
symbols are pending and the remaining seven are recorded for automatic staged
promotion. No manual backtest was launched.

## Why This EA

- The two diverse pending build cards were not faithfully runnable: QM5_1457
  requires Treasury/bond/cash/commodity series and QM5_1459 requires lumber and
  Treasury series that are absent from approved DWX inputs.
- The other pending builds were in the already saturated index/metal and XNG
  classes.
- QM5_11908 adds ten FX carriers and is based on Kevin J. Davey's deterministic
  “Dueling Momentum” entry from *My 5 Favorite Entries*.
- At claim time the farm had no active/pending row, downstream work, or prior
  repair claim for this EA.

## Diagnosis and Repair

The farm retained 120 Q02 rows for QM5_11908. Every row was an infrastructure
failure; there were no Q02 PASS rows and no open retry. The initialization defect
was deterministic: the EA had an active `ea_id_registry.csv` row but no
`magic_numbers.csv` entries. `QM_FrameworkInit` therefore could not resolve a
registered magic for any of its ten FX symbols, and the legacy setfiles all used
slot 0.

The repair added collision-free magics 119080000–119080009, regenerated the
resolver, and regenerated ten H1 backtest setfiles with unique slots,
`RISK_FIXED=1000`, and `RISK_PERCENT=0`. The source now also uses a magic-scoped
position gate, zero-initializes its entry request, and keeps management and hard
exits above the entry-only news blackout. A complete Q01 `SPEC.md` was added.

| Check | Result |
|---|---|
| SPEC validation | PASS |
| Strict build check | PASS, 0 failures, 0 warnings |
| Build-check report | `D:/QM/reports/framework/21/build_check_20260710_143802.json` |
| Strict compile | PASS, 0 errors, 0 warnings |
| Compile log | `C:/QM/repo/framework/build/compile/20260710_143802/QM5_11908_davey-dueling-momentum-h1.compile.log` |
| MQ5 SHA256 | `2EDB27F0EEBA658F3C03323C42A356AE705683EEF816F0347C0292510E2CC985` |
| EX5 SHA256 | `1FBB3890DC29F1FC2250D7340E8DC1ACA745D7B7B594C0A1698824B83AD0DD86` |

## Paced Q02 Handoff

The standard three-symbol stage-one policy enqueued:

- `AUDJPY.DWX` — `ab24eb1d-9bb3-43ad-ab66-38253758605b`
- `EURUSD.DWX` — `b9bc2085-d3f4-4cb8-84c3-93b73e71396a`
- `USDCAD.DWX` — `79b2b607-802d-4463-adb7-0a99e8c434cc`

The farm sidecar retains GBPUSD, USDJPY, USDCHF, AUDUSD, NZDUSD, EURJPY, and
GBPJPY for automatic promotion after a stage-one PASS or spare queue capacity.
No manual tester process was started; the paced workers own real-evidence
execution.

## Safety Boundary

No `T_Live` file, AutoTrading state, portfolio gate, or live manifest was
touched.

Machine-readable evidence:
`artifacts/qm5_11908_fx_magic_repair_q02_requeue_20260710.json`.
