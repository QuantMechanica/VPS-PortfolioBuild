# QM5_41062 XAU/XAG Opposed Weekend-Gap Fade: Q01 PASS, Q02 Enqueued, CPU Stop

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_41062_xauxag-wgap-fade`

## Outcome

`QM5_41062` mechanizes one new low-frequency precious-metals relative-value
identity: at a synchronized broker Monday open, compare each metal with its
exact prior-Friday close; trade only when the XAU and XAG log gaps have strict
opposite signs, fade both legs, size the pair to equal entry notional within
the locked tolerance and one aggregate `RISK_FIXED=1000` budget, and exit at
the next synchronized D1 boundary. This is a market-neutral basket candidate,
not a portfolio-admission or realized-decorrelation claim.

The OWNER-approved source decision, canonical duplicate check, approved card,
deterministic build, basket manifest, magic allocation, and fixed-risk
backtest preset are committed on this branch. The edge is mechanically
different from the fixed weekend differential, unconditional Monday,
rolling-ratio, residual/MAD, tail, flow, and cross-momentum XAU/XAG families
already registered.

## Q01 Evidence

- card schema lint: PASS;
- independent Python reference suite: 9 tests, PASS;
- strict MetaEditor compile: 0 errors, 0 warnings;
- strict framework build check: PASS, report
  `D:/QM/reports/framework/21/build_check_20260820_065321.json`;
- static P1 build validation: PASS, evidence
  `D:/QM/reports/pipeline/QM5_41062/P1/P1_QM5_41062_result.json`;
- build commit: `49e84b7d4`.

The only tester preset is the logical-basket D1 backtest setfile with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No live,
demo, shadow, stress, or optimization preset was created.

## Q02 Queue And Capacity Evidence

The target-only canonical dry run was read-only:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41062 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=0 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 0
```

The zero selection was correct because the immediate read-only query found
exactly one already-existing Q02 row and no duplicate:

- work item: `d570870f-d792-4adc-98d6-1ef5b7895b19`;
- created: `2026-08-20T06:52:58+00:00`;
- phase/status: `Q02` / `pending`;
- attempt/claim: `0` / unclaimed;
- logical symbol: `QM5_41062_XAU_XAG_WGAPFADE_D1`.

No `--apply` was issued because a second row would have been a duplicate.

The read-only `farmctl.py mt5-slots` census at
`2026-08-20T06:58:34+00:00` found six active governed research terminals:
`T1`, `T2`, `T4`, `T5`, `T6`, and `T8`, below the seven-terminal ceiling.
The separate `T_Live` and unrelated FTMO terminal were observed solely to
exclude them; neither was touched.

The binding five-sample `GetSystemTimes` whole-host CPU reading ran from
`2026-08-20T06:59:05.320127+00:00` through
`2026-08-20T06:59:15.715424+00:00`. Two-second samples were `100.00`,
`99.95`, `99.95`, `99.66`, and `99.56` percent (average `99.82`, maximum
`100.00`). The explicit `97%` hard host-CPU ceiling was therefore active.

Per the mission stop condition, no queue mutation, dispatcher tick, manual
backtest, terminal action, or attempt to accelerate the pending row followed.
The single pending row remains owned by paced worker admission.

## Safety Boundary

No AutoTrading action, `T_Live` edit, deploy/T_Live manifest change,
portfolio-gate change, portfolio admission, correlation waiver, or live use
occurred. Q02 must retire this identity on zero trades, fewer than five
completed paired packages per full post-warm-up year, nonpositive governed
economics, endpoint or chronology leakage, same-sign/zero gap entry, wrong
fade mapping, duplicate attempt, broken basket repair, aggregate-risk or
notional-tolerance breach, missing hard stop, lifecycle failure,
nondeterminism, or invalid fixed-risk mode. Q09 alone may establish realized
correlation with the certified book.
