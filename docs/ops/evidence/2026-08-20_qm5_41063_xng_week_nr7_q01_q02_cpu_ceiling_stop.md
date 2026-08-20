# QM5_41063 XNG Completed-Week NR7: Q01 PASS, Q02 CPU-Ceiling Stop

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_41063_xng-week-nr7-brk`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED - HARD HOST-CPU CEILING`

## Edge And Portfolio Boundary

`QM5_41063` mechanizes one structural, low-frequency XNG stream. It requires
the immediately prior normalized Monday-Friday broker week to be the strict
narrowest by full high-low range among seven valid complete weeks. During the
next week it buys on the first completed D1 close strictly above that range or
sells on the first completed close strictly below it, consumes one restart-
safe attempt per broker week, uses one frozen fixed-risk hard stop, and is flat
by broker Friday 21.

This logic differs materially from certified `QM5_12567`, which is a long-only
two-day cumulative-RSI2 pullback aligned to a slow trend and held at most five
bars. It also differs from thresholded five-D1 return/reversal, daily ID/NR4,
and monthly opening-range XNG families. The same estimator's WTI sibling is a
carrier control only; no sibling result transfers. Mechanic and carrier
difference do not prove decorrelation. Q09 alone may establish realized book
correlation.

## Source, Governance, And Commits

- reputable source: Toby Crabel, *Day Trading with Short-Term Price Patterns
  and Opening Range Breakout*, Traders Press, 1990;
- source approval: `467ec1cdddadd47dbb0d799a6bf11f6f0b1c6324`;
- deterministic EA reservation: `bce2cfbeea40f4a9818e0d350c78536dd607fec8`;
- slot-0 XNG magic/resolver allocation: `58960ed9641ba4ea9e1b037cd3c0e8a554534a73`;
- approved card and G0 decision: `6fcabca10b3e648c1486ea38826a345cf9ded1e1`;
- deterministic build: `a4f75758e39e3ddd92b5045d7b0928840e0be80a`.

The approved packet discloses both weekly time-aggregation and continuous-XNG
CFD carrier risk. No source return, density, cost, CFD-equivalence, or
portfolio-correlation claim is imported.

## Q01 Evidence

- card schema and prohibited-ML lint: PASS;
- G0 card readiness lint: PASS;
- independent deterministic weekly-NR7 reference suite: 13 tests, PASS;
- strict MetaEditor compile: PASS, 0 errors, 0 warnings, log
  `framework/build/compile/20260820_073038/QM5_41063_xng-week-nr7-brk.compile.log`;
- strict targeted V5 build check: PASS, 0 failures, 0 warnings, report
  `D:/QM/reports/framework/21/build_check_20260820_073038.json`;
- static P1 artifact validation: PASS, evidence
  `D:/QM/reports/pipeline/QM5_41063/P1/P1_QM5_41063_result.json`;
- MQ5 SHA-256:
  `C5584C74CF276E366510112169552C2E63745D792A989FF230A4B318811F294A`;
- EX5 SHA-256:
  `445344418E73C29BD4184F728DD43C89D09664B66B425695EC353C099DF50F9B`;
- backtest-set byte SHA-256:
  `27B3FA8EBA00837A2CFA502F5ADC51A436BCBD26417758853315AD42640A6725`;
- normalized set content build hash:
  `8132622c6d6454fb0673c0e291570b5e392594a87177004d22287d24dace115d`.

The only preset is exact `XNGUSD.DWX`, D1, backtest, slot 0, with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
and Friday close ON. No manual tester or smoke run occurred.

## Target-Only Q02 Dry Run

The canonical dry run selected exactly one fresh Q02 row and no recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41063 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

No `--apply` command followed. The immediate read-only
`farmctl.py work-items --ea QM5_41063` query returned `count=0`, proving that
no Q02 row was created.

## Binding Capacity Stop

The read-only `farmctl.py mt5-slots` census at
`2026-08-20T07:33:43+00:00` found four active governed research terminals:
`T3`, `T5`, `T6`, and `T8`, below the seven-terminal ceiling. The separate
`T_Live` and unrelated FTMO terminal were observed only so they could be
excluded; neither was touched.

The binding five-sample whole-host CPU check completed before
`2026-08-20T07:34:27.8099172Z`. Two-second samples were `98.94`, `95.44`,
`99.90`, `98.78`, and `99.66` percent; average was `98.54` and maximum was
`99.90`. The explicit `97%` hard ceiling was therefore active.

Per the mission stop condition, there was no queue mutation, dispatcher tick,
manual backtest, terminal reservation or control, requeue, priority change, or
attempt to accelerate another item.

## Safety And Handoff

No AutoTrading action, `T_Live` edit, deploy/T_Live manifest change,
portfolio-gate mutation, portfolio admission, decorrelation claim, correlation
waiver, live/demo/shadow/stress/optimization preset, or live use occurred.

A later paced operator may repeat the exact target-only dry run and apply once
only after fresh governed-terminal and host-CPU checks both pass. Q02 must
retire this identity on zero trades, fewer than five completed positions per
full post-warm-up year, nonpositive governed economics, label or complete-week
defect, non-strict range rank, wrong breakout side, current-bar leakage,
duplicate attempt, missing hard stop, weekend hold, nondeterminism, or invalid
fixed-risk mode. It must not be tuned to escape those retirement conditions.
