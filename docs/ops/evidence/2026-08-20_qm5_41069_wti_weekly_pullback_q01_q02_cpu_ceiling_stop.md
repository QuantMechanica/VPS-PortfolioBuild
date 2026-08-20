# QM5_41069 WTI Weekly Pullback: Q01 PASS, Q02 Held At CPU Ceiling

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_41069_wti-wpull-trend`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED; HARD HOST-CPU STOP`

## Edge And Portfolio Boundary

`QM5_41069` mechanizes one structural, low-frequency WTI trend re-entry. On
the first tradable `XTIUSD.DWX` D1 bar of a Monday-anchored broker week, it
reconstructs three consecutive completed week-end closes and two adjacent,
non-overlapping weekly log returns. It trades only when the returns have
strict opposite signs and the newest absolute move is strictly smaller than
the older move. An older positive week followed by a smaller negative week
buys; an older negative week followed by a smaller positive week sells. The
position closes at the first later broker week and has one frozen fixed-risk
ATR hard stop.

For positive prices under sign opposition, the implementation compares the
newest and oldest endpoints (`C1>C3` long, `C1<C3` short). This is
algebraically equivalent to strict absolute-log-return comparison and makes
`C1=C3` deterministically flat rather than exposing equality to independent
logarithm rounding.

The candidate carries direct WTI physical-energy risk outside the certified
XAU/SP500/NDX/XNG book. It differs from certified `QM5_12567`, a long-only
two-day cumulative-RSI2 commodity pullback. It also differs from
`QM5_41065`, which follows the newest sign after a weekly handoff, and
`QM5_41068`, which follows same-sign weekly acceleration. The canonical
pre-card dedup check was CLEAN across 4,556 registry rows and 625 cards.

Carrier and mechanic difference do not prove decorrelation. Q09 alone may
establish realized correlation with the certified book, and no portfolio
admission occurred here.

## Source, Governance, And Commits

- reputable source: Moskowitz, Ooi, and Pedersen (2012), "Time Series
  Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`;
- complete-read parent packet SHA-256:
  `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`;
- source approval and bounded translation: `c655c2d6a`;
- deterministic EA reservation: `af2e427b6`;
- slot-zero WTI magic/resolver allocation: `734c0f565`;
- approved card and G0 decision: `0145f1f5b`;
- deterministic build: `0947d081c`.

The approved packet discloses that the weekly horizon, opposed-sign state,
strict smaller-countermove gate, and older-sign direction are QM timing
hypotheses layered onto the peer-reviewed own-return-continuation lineage. No
source or sibling return, frequency, cost, CFD-equivalence, or portfolio-
correlation result is imported.

## Q01 Evidence

- card schema and prohibited-ML lint: PASS;
- G0 build-readiness guard and targeted registry/magic/resolver identity:
  PASS;
- deterministic weekly-pullback reference suite: 10 tests, PASS;
- strict MetaEditor compile: PASS, 0 errors, 0 warnings, log
  `framework/build/compile/20260820_134707/QM5_41069_wti-wpull-trend.compile.log`;
- strict targeted V5 build check: PASS, 0 failures, 0 warnings, report
  `D:/QM/reports/framework/21/build_check_20260820_134707.json`;
- static P1 artifact validation: PASS, evidence
  `D:/QM/reports/pipeline/QM5_41069/P1/P1_QM5_41069_result.json`;
- MQ5 SHA-256:
  `564A88B8514D8DA499E5F2FB44371EC0855D73D2D8981A3F3B7EB5111818EADE`;
- EX5 SHA-256:
  `582F707E5D5E79DE0FE3A84899BE8E07EA7AD97059D147AA1E35B8E756472F0A`;
- backtest-set byte SHA-256:
  `6C7EBC9FACE2F9E9F50A7AA95DBD5DC7B4703B7A4DECF33C45694F0DA163C360`;
- normalized set content build hash:
  `a0255d34bbf1a81d415b7996f1eefe628a1439be2db00e919d826c7de7b3b1ba`.

The only preset is exact `XTIUSD.DWX`, D1, backtest, slot zero, with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
and Friday close OFF. No manual tester or smoke run occurred.

## Target-Only Q02 Admission Check

The canonical target-only dry run selected exactly one fresh Q02 row and no
recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41069 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

Read-only `farmctl.py work-items --ea QM5_41069` queries immediately before
and after the capacity check both returned `count=0`. No `--apply` command was
issued, so the final external state is `Q02 NOT_ENQUEUED_CPU_CEILING` with no
duplicate row.

## Binding Capacity Stop

The read-only `farmctl.py mt5-slots` census at
`2026-08-20T13:49:50+00:00` found six active governed research terminals:
`T1`, `T4`, `T5`, `T6`, `T8`, and `T9`. The separate `T_Live` and unrelated
FTMO terminal were observed only so they could be excluded. No orphaned or
duplicate tester process was reported, and none was touched.

The binding five-sample `GetSystemTimes` whole-host CPU check ran from
`2026-08-20T13:50:24.235900+00:00` through
`2026-08-20T13:50:34.325145+00:00`. Two-second samples were `97.11`, `86.03`,
`97.45`, `93.36`, and `98.44` percent; average was `94.48` and maximum was
`98.44`. Three samples crossed the explicit `97%` hard CPU ceiling.

Per the mission stop condition, this lane issued no apply command, dispatcher
tick, manual backtest, terminal reservation or control, requeue, priority
change, cancellation, or attempt to accelerate the candidate.

## Safety And Handoff

No AutoTrading action, `T_Live` edit, deploy/T_Live manifest change,
portfolio-gate mutation, portfolio admission, decorrelation claim,
correlation waiver, live/demo/shadow/stress/optimization preset, or live use
occurred.

A later paced worker may rerun the exact target-only dry run and enqueue one
fresh row only after a fresh governed-terminal and host-CPU check is below all
ceilings. It must first confirm `work-items --ea QM5_41069` is still empty and
must not enqueue a duplicate. Q02 must retire this identity on zero trades,
fewer than five completed positions per full post-warm-up year, nonpositive
governed economics, label/week/endpoint defect, same-sign entry, equal or
larger countermove, wrong-side entry, current-week leakage, duplicate attempt,
missing hard stop, wrong next-week close, nondeterminism, or invalid fixed-risk
mode. It must not be tuned to escape those retirement conditions.
