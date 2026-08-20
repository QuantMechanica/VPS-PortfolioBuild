# QM5_41066 XAU/XAG Weekly Deceleration Reversion: Q01 PASS, Q02 CPU-Ceiling Stop

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_41066_xauxag-wdecay-rv`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED; THIS LANE STOPPED AT THE HOST-CPU CEILING`

## Edge And Portfolio Boundary

`QM5_41066` mechanizes one low-frequency structural precious-metals relative-
value candidate. On the first tradable D1 bar of a Monday-anchored broker
week, it reconstructs three consecutive synchronized completed XAU/XAG week-
end close pairs and two adjacent changes in `ln(XAU)-ln(XAG)`. When both
changes have the same strict sign but the newest absolute move is strictly
smaller, it fades that waning direction for one broker week with opposite
XAU/XAG legs.

The package targets equal absolute entry notionals and shares one aggregate
fixed-risk budget. This construction is not a neutrality or decorrelation
claim. Q02 alone may establish baseline density and economics, and unchanged
Q09 alone may establish realized correlation with the certified book.

## Source, Governance, And Commits

- source lineage: Schweikert (2018), *Journal of Banking & Finance* 88,
  44-51, DOI `10.1016/j.jbankfin.2017.11.010`, plus CME Group's official
  Gold & Silver Ratio Spread education;
- source approval and bounded child packet: `064e189bc`;
- deterministic EA reservation: `2475a7269`;
- two-leg magic/resolver allocation: `9b61b28c1`;
- approved card and G0 decision: `e1bbd0185`;
- deterministic paired build: `fb44a5fa8`.

The packet explicitly discloses the adjacent-week same-sign deceleration fade
as an untested QM translation. No source return, density, hedge ratio, CFD
equivalence, neutrality, or portfolio-correlation result transfers.

## Q01 Evidence

- card schema and prohibited-ML lint: PASS;
- G0 build-readiness guard: PASS;
- deterministic weekly-deceleration reference suite: 9 tests, PASS;
- strict MetaEditor compile: PASS, 0 errors, 0 warnings, log
  `framework/build/compile/20260820_105858/QM5_41066_xauxag-wdecay-rv.compile.log`;
- strict targeted V5 build check: PASS, 0 failures, 0 warnings, report
  `D:/QM/reports/framework/21/build_check_20260820_105857.json`;
- static P1 artifact validation: PASS, evidence
  `D:/QM/reports/pipeline/QM5_41066/P1/P1_QM5_41066_result.json`;
- MQ5 SHA-256:
  `76F3419243A082CAB19CB47061437BE3CCED9A82393255FD3C6EE3EACF6E7A8C`;
- EX5 SHA-256:
  `51B5643264292F96733412D907C3E59E159A2608C2C955F7AA60A164F4E5113C`;
- backtest-set byte SHA-256:
  `058B4F440EE5CDA97CCFE09C522BF191FD36BA302F448FBC962798E39B0D1B94`;
- stamped set content build hash:
  `5849294948155d8af6d46028b169f535c334f1460268771820e7c35805e644da`.

The only preset is the logical `QM5_41066_XAU_XAG_WDECAY_RV_D1` basket on
host `XAUUSD.DWX`, D1, slot zero, with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close OFF. No manual
tester or smoke run occurred.

## Target-Only Q02 Dry Run

The canonical target-only dry run selected exactly one fresh Q02 row and no
recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41066 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

No `--apply` command followed. Both the immediate pre-check and final read-
only `farmctl.py work-items --ea QM5_41066` queries returned `count=0`.
Therefore no duplicate, hidden, pending, or active work item was created.

## Binding Capacity Stop

The read-only `farmctl.py mt5-slots` census at
`2026-08-20T11:04:01+00:00` found six active governed research terminals:
`T1`, `T2`, `T4`, `T5`, `T9`, and `T10`. This is within the seven-terminal
ceiling. The separate `T_Live` and unrelated FTMO terminal were observed only
so they could be excluded; neither was touched.

The binding five-sample whole-host CPU check completed at
`2026-08-20T11:04:44.9755754Z`. Two-second samples were `96.68`, `100.00`,
`97.47`, `98.15`, and `99.42` percent; average was `98.34` and maximum was
`100.00`. The explicit `97%` hard ceiling was active.

Per the mission stop condition, this lane issued no apply command, dispatcher
tick, manual backtest, terminal reservation or control, requeue, priority
change, cancellation, or attempt to accelerate another work item.

## Safety And Handoff

No AutoTrading action, `T_Live` edit, deploy/T_Live manifest change,
portfolio-gate mutation, portfolio admission, decorrelation claim,
correlation waiver, live/demo/shadow/stress/optimization preset, or live use
occurred.

A later paced operator may repeat the target-only dry run and enqueue exactly
once only after fresh governed-terminal and host-CPU checks pass. It must
first verify that no concurrent row exists. Q02 must retire this identity on
zero packages, fewer than five completed packages per full post-warm-up year,
nonpositive governed economics, asynchronous or nonconsecutive week
endpoints, same-sign-rule or inverse-side defect, current-week leakage,
duplicate attempt, one-leg survivor, aggregate-risk breach, missing stop,
wrong next-week close, nondeterminism, or invalid fixed-risk mode. It must not
be tuned to escape those retirement conditions.
