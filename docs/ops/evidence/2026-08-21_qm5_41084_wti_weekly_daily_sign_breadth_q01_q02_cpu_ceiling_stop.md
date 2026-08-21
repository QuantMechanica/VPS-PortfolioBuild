# QM5_41084 Q01 PASS and Q02 capacity-ceiling stop

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41084_wti-wdaybreadth-mom`

Outcome: `Q01 PASS`; `Q02 NOT_ENQUEUED_CPU_CEILING`

## New structural energy sleeve

`QM5_41084` is a low-frequency direct-WTI completed-week directional-breadth
strategy on exact `XTIUSD.DWX` D1. At the first tradable bar of a new broker
week, it reconstructs the parent week's final close and exactly five closes in
the immediately completed week. It follows the week only when at least four of
the five adjacent daily log returns share a strict sign and the complete weekly
net return has that same strict sign. Zero returns count toward neither side.

The identity is mechanically different from the certified XNG cumulative-RSI2
pullback and from WTI weekly close-location, fixed-weekday, multi-week path,
flow-decomposition, monthly-sign, and volatility-ranked families reviewed at
G0. The difference is a diversification hypothesis, not proof of low realized
correlation; Q09 alone owns portfolio-correlation admission.

## Reputable-source and governance trail

The source basis is Moskowitz, Ooi, and Pedersen (2012), *Time Series
Momentum*, *Journal of Financial Economics* 104(2), DOI
`10.1016/j.jfineco.2011.11.003`. The bounded packet records a complete-paper
read and WTI membership. The weekly clock, exact five daily intervals,
four-of-five breadth, and weekly-net conjunction are disclosed QM hypotheses,
not claims transferred from the paper.

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `8ca5ed7fa` |
| deterministic EA-ID reservation | `d34837b3e` |
| G0-approved card | `8e002c82e` |
| magic allocation and resolver regeneration | `bd3b1d83a` |
| implementation and Q01 build | `09069cef4` |
| strict compile summary | `D:/QM/reports/compile/20260821_050727/summary.csv` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260821_050727.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41084/P1/P1_QM5_41084_result.json` |

Q01 evidence:

- canonical pre-allocation dedup: CLEAN after repository-wide family review;
- deterministic reference suite: 10 tests passed;
- strategy-card schema, G0, and spec-document lints: PASS;
- strict MetaEditor compile: 0 errors, 0 warnings;
- targeted build check: PASS, 0 failures, 0 warnings;
- static P1 validation: PASS;
- MQ5 SHA-256: `48EF17F2346CA841DC7248D4A9091253ADD8FD226C4937804EED76BDB47FAB3F`;
- EX5 SHA-256: `26027CF2A264838D2FDC5E4C1E69614140A769BD5E96575A57C4CF6275111D20`;
- setfile byte SHA-256: `FC00B518510054E06F9112D779BC582286919C78DE80D0B3C7D5C88C3453FAB3`;
- normalized set build hash: `b63bde279f2077cad9baf76ec6836c3ec87280f13b7b23fdb70fe55b39cbabf4`;
- strict build-report SHA-256: `8A2328F1D2905C2DAF2D55E9FF17AC03133992FEADE105BCA69FC06A101CBCCA`;
- static P1-report SHA-256: `48074DAF7828A7B53974D1D863ED78246783C86B69D7990CB87C37D4F4935A1B`.

The only preset is the D1 backtest baseline with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close
OFF. No live, demo, shadow, stress, or optimization preset was created.

## Q02 target preflight

The supported farm view had no existing work item:

```text
python -m tools.strategy_farm.farmctl work-items --ea QM5_41084
count=0
```

The non-mutating target-only preview found exactly one fresh baseline row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41084 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
part3 deferred: promoted=0 kept=0
priority_track items: 1
```

The preview carried no `--apply` flag. No farm row or priority was mutated.

## Binding capacity stop

At `2026-08-21T05:09:32Z`, the canonical read-only `farmctl mt5-slots`
inventory reported seven running governed research terminals, the full paced
ceiling: `T1`, `T2`, `T3`, `T4`, `T5`, `T7`, and `T8`.

| Terminal | EA | Phase | Symbol / label |
|---|---|---|---|
| T1 | `QM5_12935` | Q07 | `XAUUSD.DWX` |
| T2 | `QM5_10796` | Q07 | `XAUUSD.DWX` |
| T3 | `QM5_10135` | Q08 | `pipeline_run` baseline; no work-item row |
| T4 | `QM5_20234` | Q03 | `QM5_20234_XAU_XAG_RSJ_D1` |
| T5 | `QM5_12350` | Q07 | `USDJPY.DWX` |
| T7 | `QM5_10248` | Q07 | `NDX.DWX` |
| T8 | `QM5_11167` | Q07 | `XAUUSD.DWX` |

The census reported zero duplicate terminal workers and zero orphaned terminal
processes. It observed the separate `T_Live` and FTMO terminals only to
exclude them from the governed research count; neither was accessed or
changed. Its reservation list also observed a concurrent `T9` reservation
created five seconds after the process-scan timestamp, reinforcing rather than
relaxing the capacity stop.

Because the terminal-count admission ceiling was already binding, the
mission's capacity-stop rule was applied immediately without a redundant
whole-host CPU probe or queue mutation. Q02 was not enqueued, dispatched,
reserved, or run. No terminal was stopped or controlled, and no manual
backtest was launched.

## Safe handoff

After governed terminal occupancy falls below seven, repeat the exact target
work-item query, target-only preview, terminal census, and a fresh whole-host
CPU sample before using the target-only `--apply` path for `QM5_41084`. Do not
broaden the sweep.

This record does not authorize AutoTrading, `T_Live`, deploy/T_Live manifest
changes, portfolio-gate changes, portfolio admission, a correlation waiver,
or live use. Q02 must retire the identity on zero packages, fewer than five
completed positions per full post-warm-up year, nonpositive governed
economics, or any hard-rule violation.

Machine-readable evidence:
`artifacts/qm5_41084_q02_cpu_ceiling_stop_20260821T050932Z_board_advisor.json`.
