# QM5_41094 XNG Weekly Body-Dominance Q01 / Q02 CPU-Ceiling Stop

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41094_xng-wbody-dominance-mom`

Outcome: `Q01 PASS; Q02 NOT_ENQUEUED_CPU_CEILING`

## Completed new sleeve

`QM5_41094` is a low-frequency, symmetric direct-natural-gas continuation
candidate on exact `XNGUSD.DWX` D1. At the first tradable bar of a normalized
Monday-anchored broker week, it aggregates the immediately completed three-
to-five-session weekly OHLC package. It follows the completed body's sign only
when `3*abs(close-open) > 2*(high-low)` is strictly true; equality and invalid
states consume the week flat. A survivor closes at the next weekly boundary.

This logic differs from certified `QM5_12567`, which is a long-only two-day
cumulative-RSI2 pullback under a slow mean. The new identity is a
diversification hypothesis only; Q09 alone may establish realized book
correlation.

## Q01 result

The approved card, source packet, governed EA/slot/magic identity, compiled
binary, deterministic reference suite, and single `RISK_FIXED` backtest preset
are committed through build commit `ae134a70a`. Full Q01 evidence is
`docs/ops/evidence/2026-08-21_qm5_41094_xng_weekly_body_dominance_q01_build.md`.

- reference suite: 11/11 PASS;
- strict compile: PASS, zero errors and zero warnings;
- target build check: PASS, zero failures;
- static P1 artifact validation: PASS;
- magic: `410940000` on `XNGUSD.DWX`, slot zero;
- risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, frozen `3.5*ATR(20,D1)` stop, no target; and
- only one backtest D1 preset; no live/demo/shadow/stress/optimization set.

## Target-only Q02 preflight

The canonical work-item query returned no existing row before the capacity
decision:

```text
python tools/strategy_farm/farmctl.py work-items --ea QM5_41094
count=0
```

The exact target-only, non-mutating preview selected one fresh baseline and no
stranded item:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py \
  --ea QM5_41094 --symbols XNGUSD.DWX --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

This establishes eligibility, not admission. No `--apply` command was issued,
so the work-item count remains zero and no duplicate exists.

## Binding capacity stop

Read-only `farmctl mt5-slots` at `2026-08-21T18:34:54Z` reported four active
governed terminals:

| Terminal | Phase | EA | Symbol |
|---|---|---|---|
| T1 | Q02 | QM5_20202 | QM5_20202_XAU_XAG_REV18_D1 |
| T4 | Q09_NEWS | QM5_11294 | XAUUSD.DWX |
| T5 | Q02 | QM5_37007 | EURUSD.DWX |
| T7 | Q02 | QM5_36007 | EURUSD.DWX |

It reported no duplicate terminal workers and no orphaned terminal process.
The separate `T_Live` and FTMO processes were observed only to exclude them;
neither was accessed or controlled.

Five whole-host CPU samples at four-second spacing were:

| Sample UTC | CPU |
|---|---:|
| 2026-08-21T18:35:05.351Z | 100.00% |
| 2026-08-21T18:35:09.362Z | 100.00% |
| 2026-08-21T18:35:13.364Z | 100.00% |
| 2026-08-21T18:35:17.377Z | 100.00% |
| 2026-08-21T18:35:21.404Z | 98.69% |

Average CPU was `99.74%`; maximum CPU was `100.00%`. Every sample exceeded
the explicit `97%` hard ceiling. Per the mission stop condition, this lane
stopped without Q02 admission.

## Safety and handoff

No enqueue apply, dispatcher tick, backtest, terminal reservation/control,
requeue, priority change, cancellation, AutoTrading action, `T_Live` edit,
deploy/T_Live-manifest change, portfolio-gate mutation, portfolio admission,
decorrelation claim, correlation waiver, or live use occurred.

A later paced worker may rerun the exact work-item query, target-only preview,
terminal census, and CPU samples. It may enqueue one fresh Q02 row only when
the target still has zero work items and all capacity ceilings pass. Q02 must
retire this identity on zero trades, fewer than five completed positions in
any full post-warm-up year, nonpositive governed economics, or any label,
anchor, session-count, strict-body, side, attempt, risk, or lifecycle defect.
