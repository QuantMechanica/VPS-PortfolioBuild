# QM5_41065 WTI Weekly Sign Handoff: Q01 PASS, Q02 CPU-Ceiling Stop

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_41065_wti-wflip-mom`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED; THIS LANE STOPPED AT TERMINAL AND HOST-CPU CEILINGS`

## Edge And Portfolio Boundary

`QM5_41065` mechanizes one structural, low-frequency WTI stream. On the first
tradable D1 bar of a Monday-anchored broker week, it reconstructs three
consecutive completed week-end closes and two adjacent non-overlapping weekly
log returns. It buys only on a negative-to-positive sign handoff and sells
only on a positive-to-negative handoff, following the newest completed-week
sign until the next broker week. One restart-safe attempt is consumed per
week and one frozen fixed-risk ATR hard stop is mandatory.

This differs from certified `QM5_12567`, a two-day multi-commodity cumulative-
RSI2 pullback, and gives the index/metal/XNG book a distinct direct-WTI
physical-energy research carrier. It also differs from the monthly sign-
handoff identity, prior-week Tuesday-through-Friday closing momentum, within-
week opening/closing agreement, overnight/session-flow opposition, and the
current-week Friday pullback family. Mechanic and carrier difference do not
prove decorrelation. Q09 alone may establish realized book correlation.

## Source, Governance, And Commits

- reputable source: Moskowitz, Ooi, and Pedersen (2012), "Time Series
  Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`;
- source approval:
  `e37db06b813239252e3486425cef01c4f84b004c`;
- deterministic EA reservation:
  `b5584210dc869ecd4a2706480b671c444d198cb2`;
- slot-zero WTI magic/resolver allocation:
  `8137e20971ad3f82de578b992bb15acbb32077a1`;
- approved card and G0 decision:
  `87f01bd106f0296df2c09c04064542f5e472de93`;
- deterministic build:
  `34999ab3820baa4addfa06a0479f2e4c7ab715b4`.

The approved packet discloses that the weekly horizon and adjacent-week sign-
change gate are QM timing hypotheses layered onto peer-reviewed own-return
continuation lineage. No source or sibling return, density, cost, CFD-
equivalence, or portfolio-correlation claim is imported.

## Q01 Evidence

- card schema and prohibited-ML lint: PASS;
- G0 build-readiness guard: PASS;
- deterministic weekly-sign-handoff reference suite: 9 tests, PASS;
- strict MetaEditor compile: PASS, 0 errors, 0 warnings, log
  `framework/build/compile/20260820_093410/QM5_41065_wti-wflip-mom.compile.log`;
- strict targeted V5 build check: PASS, 0 failures, 0 warnings, report
  `D:/QM/reports/framework/21/build_check_20260820_093441.json`;
- static P1 artifact validation: PASS, evidence
  `D:/QM/reports/pipeline/QM5_41065/P1/P1_QM5_41065_result.json`;
- MQ5 SHA-256:
  `AF268DD3DFDF42596174D4AE3580E240707A0186B77CC8A8F03710AF12BE2E64`;
- EX5 SHA-256:
  `083DA3799985784843ABC1449CD2EA461738BCDA92A167C55728B0C42161451D`;
- backtest-set byte SHA-256:
  `1CB646C607F7EBBDB845F440B17937CD596B08D168AD3B54010EA593EEB8D001`;
- normalized set content build hash:
  `57560e7f5941d666da0887de63a14616e4946203c45386e69d641c3bd087a8fb`.

The only preset is exact `XTIUSD.DWX`, D1, backtest, slot zero, with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
and Friday close OFF. No manual tester or smoke run occurred.

## Target-Only Q02 Dry Run

The canonical target-only dry run selected exactly one fresh Q02 row and no
recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41065 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

No `--apply` command followed. Both the immediate and post-capacity read-only
`farmctl.py work-items --ea QM5_41065` queries returned `count=0`. The final
state is therefore `Q02 NOT_ENQUEUED_CPU_CEILING`; no duplicate or hidden row
was created by this lane.

## Binding Capacity Stop

The read-only `farmctl.py mt5-slots` census at
`2026-08-20T09:38:12+00:00` found eight active governed research terminals:
`T2`, `T3`, `T4`, `T5`, `T6`, `T7`, `T8`, and `T9`. That exceeds the seven-
terminal ceiling. The separate `T_Live` and unrelated FTMO terminal were
observed only so they could be excluded; neither was touched.

The binding five-sample whole-host CPU check completed at
`2026-08-20T09:38:53.3023979Z`. Two-second samples were `99.85`, `100.00`,
`99.90`, `98.20`, and `99.95` percent; average was `99.58` and maximum was
`100.00`. The explicit `97%` hard ceiling was therefore active.

Per the mission stop condition, this lane issued no apply command, dispatcher
tick, manual backtest, terminal reservation or control, requeue, priority
change, cancellation, or attempt to accelerate another work item.

## Safety And Handoff

No AutoTrading action, `T_Live` edit, deploy/T_Live manifest change,
portfolio-gate mutation, portfolio admission, decorrelation claim, correlation
waiver, live/demo/shadow/stress/optimization preset, or live use occurred.

A later paced operator may run the same target-only dry run and enqueue once
only after fresh governed-terminal and host-CPU checks pass. It must first
verify that no concurrent row exists and must not enqueue a duplicate. Q02
must retire this identity on zero trades, fewer than five completed positions
per full post-warm-up year, nonpositive governed economics, label/week/
endpoint defect, same-sign or wrong-side entry, current-week leakage,
duplicate attempt, missing hard stop, wrong next-week close, nondeterminism,
or invalid fixed-risk mode. It must not be tuned to escape those retirement
conditions.
