# QM5_20050 zero-trades recovery

- Date: 2026-07-23
- Branch: `agents/board-advisor`
- EA: `QM5_20050_xauxag-xmom12`
- Original Q02 work item: `8a36f351-f5de-40fe-acfc-4b46aff0a4a2`
- Original evidence: `D:\QM\reports\work_items\8a36f351-f5de-40fe-acfc-4b46aff0a4a2\QM5_20050\20260722_225122\summary.json`

## Bound run

The original Model-4 Q02 ran on T2 from 2018-07-02 through 2022-12-31 using
`XAUUSD.DWX` D1. Source and deployed EX5 hashes matched
`08b18d41eaabb2f8b6b6aad87e6c4d391d853a88f4f970c5033b6cb720f48fbf`;
source and deployed setfile hashes matched
`48283795bfd6529eed00d0131324344995498128eeaef5542afc885c04b6c524`.
The report was valid and contained zero trades.

## First failed layer and repair

Classification: deterministic implementation/setup defect before the entry
hook. The approved card and bound setfile specify
`strategy_history_bars=500`, with an authorized retrieval-only range of
`[400, 500, 600]`. `Strategy_NoTradeFilter()` incorrectly rejected every
value outside `[900,1600]`, so the framework returned before every monthly
entry evaluation.

The same-lineage repair changes only that guard to `[400,600]`. It does not
alter the return formula, signal direction, threshold, position sizing, ATR
stop, holding period, market universe, or economic hypothesis.

## Verification and stop condition

- `compile_one.ps1 -Strict`: PASS, 0 errors, 0 warnings.
- Compile log:
  `framework/build/compile/20260723_025009/QM5_20050_xauxag-xmom12.compile.log`.
- Recovery run: not started.
- CPU ceiling at inspection: nine active non-live farm work items across
  T1-T4 and T6-T10; T5 was explicitly disabled.

The OWNER mission requires stopping at the backtest CPU ceiling. Therefore the
repaired build is compile-PASS but not yet trade-capable or Q02-ready. Requeue
the same logical basket only after a T1-T5 terminal is confirmed free. No live
artifact, portfolio gate, deploy manifest, T_Live manifest, or AutoTrading
state was touched.

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| QM5_20050 | Q02 `8a36f351-f5de-40fe-acfc-4b46aff0a4a2` | history-buffer guard contradicted card/setfile and blocked entry hook | guard `[900,1600]` -> `[400,600]` | PASS | 0 before repair; rerun deferred | 0 before repair; rerun deferred | same bound Q02 rerun, cost and later gates |
