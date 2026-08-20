# QM5_41067 XNG Weekly Sign Handoff: Q01 PASS, Q02 CPU-Ceiling Stop

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_41067_xng-wflip-mom`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED; THIS LANE STOPPED AT THE HOST-CPU CEILING`

## Edge And Portfolio Boundary

`QM5_41067` mechanizes one structural, low-frequency natural-gas stream. On
the first tradable D1 bar of a Monday-anchored broker week, it reconstructs
three consecutive completed week-end closes and two adjacent non-overlapping
weekly log returns. It trades only a fresh sign handoff and follows the newest
completed-week sign until the next broker week. One restart-safe attempt is
consumed per week and one frozen fixed-risk ATR hard stop is mandatory.

This differs from certified `QM5_12567`, a long-only two-day cumulative-RSI2
commodity pullback under a slow trend filter. It is symmetric, oscillator-
free, transition-gated, and owns one full broker week. The canonical pre-card
dedup check was CLEAN, and manual review separated it from XNG weekly-return
threshold, low-volume momentum, monthly trend/contrarian, and weekly NR7
breakout identities. `QM5_41065` is the exact WTI carrier sibling; no WTI
pipeline result transfers to this separately predeclared XNG falsification.

Mechanic difference does not prove decorrelation. Q09 alone may establish
realized correlation with the certified XAU/SP500/NDX/XNG book, and no
portfolio admission occurred here.

## Source, Governance, And Commits

- reputable source: Moskowitz, Ooi, and Pedersen (2012), "Time Series
  Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`;
- source approval: `258db74a0`;
- deterministic EA reservation: `6558066f4`;
- slot-zero XNG magic/resolver allocation: `5258258d0`;
- approved card and G0 decision: `13b40bebe`;
- deterministic build: `a827f244f`.

The approved packet discloses that the weekly horizon and adjacent-week sign-
change gate are QM timing hypotheses layered onto peer-reviewed own-return
continuation lineage. No source or sibling return, density, cost, continuous-
CFD equivalence, or portfolio-correlation claim is imported.

## Q01 Evidence

- card schema/prohibited-ML lint and G0 readiness guard: PASS;
- deterministic weekly-sign-handoff reference suite: 9 tests, PASS;
- strict MetaEditor compile: PASS, 0 errors, 0 warnings, log
  `framework/build/compile/20260820_114547/QM5_41067_xng-wflip-mom.compile.log`;
- strict targeted V5 build check: PASS, 0 failures, 0 warnings, report
  `D:/QM/reports/framework/21/build_check_20260820_114826.json`;
- static P1 artifact validation: PASS, evidence
  `D:/QM/reports/pipeline/QM5_41067/P1/P1_QM5_41067_result.json`;
- MQ5 SHA-256:
  `5093CDF3BCB73575A201643EBD8C7B10E3CF6BC2AB79C5DF14E9AE77D1B79417`;
- EX5 SHA-256:
  `B981A8F91DCD135CD688DB4FA070F56BA97F4CB96815F7A4311292EA174CE842`;
- backtest-set byte SHA-256:
  `69BFC5D06F07B3387ABD5B92E1CCBFD5CD3AFF024F4E4B26BA136FF2A1338BB9`;
- normalized set content build hash:
  `d1b676fbdfd9b94e32a64daa6fa45bcec7c0e85cd92bba6b4f9ade47b7cb8713`.

The only preset is exact `XNGUSD.DWX`, D1, backtest, slot zero, with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
and Friday close OFF. No manual tester or smoke run occurred.

## Target-Only Q02 Dry Run

Both the preflight and post-capacity read-only queries returned zero existing
work items for `QM5_41067`. The canonical target-only dry run selected exactly
one fresh Q02 row and no recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41067 --symbols XNGUSD.DWX --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

No `--apply` command followed. Final `farmctl.py work-items --ea QM5_41067`
state was `count=0`, so no duplicate or hidden row was created by this lane.

## Binding Capacity Stop

The read-only `farmctl.py mt5-slots` census at
`2026-08-20T11:52:53+00:00` found six active governed research terminals:
`T2`, `T3`, `T4`, `T5`, `T9`, and `T10`. This was below the seven-terminal
ceiling. The separate `T_Live` and unrelated FTMO terminal were observed only
so they could be excluded; neither was touched.

The binding five-sample whole-host CPU check completed at
`2026-08-20T11:53:04.9916202Z`. Two-second samples were `100.00`, `100.00`,
`99.95`, `100.00`, and `99.95` percent; average was `99.98` and maximum was
`100.00`. The explicit `97%` hard ceiling was therefore active.

Per the mission stop condition, this lane issued no apply command, dispatcher
tick, manual backtest, terminal reservation or control, requeue, priority
change, cancellation, or attempt to accelerate another work item.

## Safety And Handoff

No AutoTrading action, `T_Live` edit, deploy/T_Live manifest change,
portfolio-gate mutation, portfolio admission, decorrelation claim, correlation
waiver, live/demo/shadow/stress/optimization preset, or live use occurred.

A later paced operator may run the same target-only dry run and enqueue once,
only after fresh governed-terminal and host-CPU checks pass. It must first
verify that no concurrent row exists and must not enqueue a duplicate. Q02
must retire this identity on zero trades, fewer than five completed positions
per full post-warm-up year, nonpositive governed economics, label/week/
endpoint defect, same-sign or wrong-side entry, current-week leakage,
duplicate attempt, missing hard stop, wrong next-week close, nondeterminism,
or invalid fixed-risk mode. It must not be tuned to escape those retirement
conditions.
