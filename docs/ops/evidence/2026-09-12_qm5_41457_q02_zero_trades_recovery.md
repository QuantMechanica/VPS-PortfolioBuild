# QM5_41457 Q02 Zero-Trades Recovery Classification

Date: 2026-09-12

Branch: `agents/board-advisor`

EA: `QM5_41457_wti-summer-nr2-upweek-fade`

Work item: `898e154f-f42d-4836-b0e2-e37ceb984e77`

## Classification

The governed Q02 was a valid Real-Ticks Model-4 execution, not a harness, report, binary, setfile,
history, or initialization failure. It covered `XTIUSD.DWX` D1 from 2018-07-02 through 2022-12-31,
kept the bound EX5 and setfile stable, emitted `INIT_OK`, and captured 1,163 equity snapshots.

The authenticated logger sample contains zero `STRATEGY_STATE`, entry-attempt, order, or trade
events. The first observable failed layer is `ENTRY_DECISION_CLOCK_UNREACHED`; order-path and
economic quality were never exercised. This is a recovery-required setup/implementation result,
not evidence that the economic hypothesis itself generated and lost trades.

The leading diagnosis is a D1 label-offset mismatch. The locked card and set use
`strategy_label_offset_seconds=86400`, while the runtime's standard D1 timing implies the code's
detected offset is `0`; `Strategy_LabelOffsetSeconds` then returns `-1` before decision-state
logging. This is high-confidence from the code path and run timing, but remains an inference until
an instrumented governed rerun records the detected value explicitly.

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| QM5_41457 | Valid Model-4, XTIUSD.DWX D1, 2018-07-02..2022-12-31 | Decision clock unreachable; likely locked 86400-second D1 label offset versus detected 0 | None applied; mechanics and locked inputs unchanged | Q01 PASS, 0 errors/warnings | 0 | 0 | Governed card/source repair authority, PACER re-audit, recompile, and one exact rerun with offset observability |

## Evidence Identity

- Summary: `D:/QM/reports/work_items/898e154f-f42d-4836-b0e2-e37ceb984e77/QM5_41457/20260912_132946/summary.json`
- Summary SHA-256: `8a05cdc438b7ebbbae7981f9885cdb5255aba056a67da47705969a595c4d7426`
- Logger sample SHA-256: `05c83fce69838e04ab90b499921bffb7a944c062d0b7f4abe43070ed18c76dae`
- Report SHA-256: `bb433f49b59656df332cc7d5ff50479f5185bac721a06565184a980c2ceafa49`
- MQ5 SHA-256: `96bc38013512bf2f24aa9c33a20dff5825918c2fde5f16c1561d4315b1536bbf`
- EX5 SHA-256: `74a78c846ea5398ba45230ee0f9d66a31916553e9e4889ab9c8f8f3bf3b7be95`
- Setfile SHA-256: `005eece3af33b9e38ef64c29d61717e3924d38090750774f5af1237f53cb1454`

## Recovery Boundary

No automatic tuning or strategy-mechanic change is authorized by a zero-trade result. Correcting a
locked card input and recompiling after a completed Q02 needs an explicit governed source-repair
path. No retry was enqueued. No portfolio gate, deploy/T_Live manifest, terminal setting, or
AutoTrading state was touched.
