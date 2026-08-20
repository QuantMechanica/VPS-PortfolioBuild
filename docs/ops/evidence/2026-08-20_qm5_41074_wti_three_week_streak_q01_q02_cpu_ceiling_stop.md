# QM5_41074 Q01 PASS and Q02 CPU-ceiling stop

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_41074_wti-wstreak3-mom`

Outcome: `Q01 PASS`; `Q02 NOT_ENQUEUED_CPU_CEILING`

## New structural energy sleeve

`QM5_41074` is a low-frequency direct-WTI completed-week continuation
strategy on exact `XTIUSD.DWX` D1. On the first tradable bar of a new
Monday-anchored broker week, it reconstructs five consecutive completed
week-ending closes and their four adjacent log returns. It follows only the
fresh transition into three same-sign completed weeks when the immediately
preceding week had the opposite strict sign (`-+++` buys; `+---` sells), then
holds for one broker week. The opposite predecessor prevents rolling entry on
a fourth same-sign week.

This is a new direct physical-energy carrier outside the certified
XAU/SP500/NDX/XNG book and a different mechanic from the incumbent XNG
cumulative-RSI2 edge. It makes no ex-ante decorrelation claim; Q09 alone owns
realized portfolio correlation.

## Governance and build trail

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `c0fe1591d` |
| deterministic EA reservation | `15884df96` |
| magic allocation and resolver regeneration | `b4ef324e0` |
| G0-approved card | `7a114c1e9` |
| implementation and Q01 build | `e9a875595` |
| strict compile log | `C:/QM/repo/framework/build/compile/20260820_194641/QM5_41074_wti-wstreak3-mom.compile.log` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260820_194801.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41074/P1/P1_QM5_41074_result.json` |

Q01 evidence:

- deterministic reference suite: 11 tests passed;
- strict MetaEditor compile: 0 errors, 0 warnings;
- targeted build check: PASS, 0 failures, 0 warnings;
- static P1 validation: PASS;
- card schema, G0, source, and banned-signal checks: PASS;
- MQ5 SHA-256: `0E33399911C597FFED0D577D1260551330AD06175041A3FDCE1AC74FC9F10469`;
- EX5 SHA-256: `F823AB1AF7795C9DCCA4A1ED7ADFD6F14EE83DC3D3D8AAC18825D68D1C087520`;
- setfile byte SHA-256: `DC6BDE665A31783F2593013B368FA8AEFA646CA747640D0073CE35DD925C6538`;
- normalized set build hash: `b5de7f994a0be406fddbf10cfab08bd951ec6048de55a84f4f75aa2426089184`.

The only preset is the D1 backtest baseline with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close
OFF. No live, demo, shadow, stress, or optimization preset was created.

## Q02 target preflight

The target had no existing work item:

```text
python tools/strategy_farm/farmctl.py work-items --ea QM5_41074
count=0
```

The non-mutating target-only preview found exactly one fresh baseline row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41074 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
part3 deferred: promoted=0 kept=0
priority_track items: 1
```

No `--apply` invocation was made.

## Binding capacity stop

At `2026-08-20T19:51:02+00:00`, the canonical read-only MT5 slot inventory
reported six running governed research terminals against the paced terminal
ceiling of seven: `T2`, `T4`, `T6`, `T8`, `T9`, and `T10`. It reported no
duplicate workers and no orphaned terminal processes.

The required whole-host CPU probe then sampled five two-second intervals from
`2026-08-20T19:52:41.106470+00:00` through
`2026-08-20T19:52:49.112245+00:00`:

```text
98.4375, 90.673828125, 95.41015625, 95.41015625, 99.658203125 percent
average=95.91796875 percent
maximum=99.658203125 percent
hard ceiling=97 percent
```

Two samples exceeded the hard ceiling, so the mission's CPU stop rule bound
before queue mutation. The inventory observed separate `T_Live` and FTMO
processes only to exclude them from the governed research count; neither was
controlled or modified.

Q02 was not enqueued, dispatched, reserved, or run. No terminal was stopped,
no manual backtest was launched, and no work-item state was mutated.

## Subsequent shared-farm state

This statement is scoped to the originating unit. A later read-only query found
that the shared farm had acquired one Q02 `pending` row at
`2026-08-20T19:52:58+00:00`. The reconciled DB-backed snapshot and duplicate
guard are recorded in
`docs/ops/evidence/2026-08-20_qm5_41074_q02_queue_reconciliation_cpu_stop_2000z.md`.

## Safe handoff

The exact Q02 row now exists. Let the paced farm claim that row when capacity
permits; do not use the target-only `--apply` path or enqueue a sibling.

This record does not authorize AutoTrading, `T_Live`, deploy/T_Live manifest
changes, portfolio-gate changes, portfolio admission, a correlation waiver,
or live use. Q02 must retire the identity on zero trades, fewer than three
completed positions per full post-warm-up year, nonpositive governed
economics, or any hard-rule violation.
