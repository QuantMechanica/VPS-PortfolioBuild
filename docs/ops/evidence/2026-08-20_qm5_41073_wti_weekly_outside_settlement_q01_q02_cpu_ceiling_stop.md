# QM5_41073 Q01 PASS and Q02 CPU-ceiling stop

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_41073_wti-woutside-settle`

Outcome: `Q01 PASS`; `Q02 NOT_ENQUEUED_CPU_CEILING`

## New structural energy sleeve

`QM5_41073` is a low-frequency direct-WTI completed-week
outside-settlement continuation strategy on exact `XTIUSD.DWX` D1. On the
first tradable bar of a new Monday-anchored broker week, it aggregates the
immediately completed week and its consecutive parent from completed D1 OHLC.
It trades only when the newer week has a strict higher high and lower low,
then settles beyond the matching parent extreme, in its own matching outer
quartile, and on the matching side of its first-session open. It follows that
completed price-discovery direction for one broker week.

This is a new direct physical-energy identity outside the certified
XAU/SP500/NDX/XNG book. It makes no ex-ante decorrelation claim; Q09 alone owns
realized portfolio correlation.

## Governance and build trail

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `c276afbdd` |
| deterministic EA reservation | `1990ead14` |
| magic allocation and resolver regeneration | `c6e44efa9` |
| G0-approved card | `a004906e1` |
| implementation and Q01 build | `99ab5c800` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260820_180908.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41073/P1/P1_QM5_41073_result.json` |

Q01 evidence:

- deterministic reference suite: 9 tests passed;
- strict MetaEditor compile: 0 errors, 0 warnings;
- targeted build check: PASS, 0 failures, 0 warnings;
- static P1 validation: PASS;
- card/source schema and banned-signal checks: PASS;
- MQ5 SHA-256: `56F35F4F357118569FC22710BC8CDFE4081FEC29A604F01DAE33EABFE55BCD24`;
- EX5 SHA-256: `8F8DF70B6C9CB49B872F251A27C631A2E6585432E4F51C196E0BA4904D4CA44A`;
- setfile byte SHA-256: `87600D61AA33921BD25DFE60A0B5F4C101A320883769375A09E6F81F4A1D259E`;
- normalized set build hash: `0a99a1a86dc292112a5ea724b2dc674809166e5adefc3d5e1b2872bdaf6a54ad`.

The only preset is the D1 backtest baseline with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close
OFF. No live, demo, shadow, stress, or optimization preset was created.

## Q02 target preflight

The target had no existing work item:

```text
python -m tools.strategy_farm.farmctl work-items --ea QM5_41073
count=0
```

The non-mutating target-only preview found exactly one fresh baseline row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41073 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
part3 deferred: promoted=0 kept=0
priority_track items: 1
```

No `--apply` invocation was made.

## Binding capacity stop

At `2026-08-20T18:10:57+00:00`, the canonical read-only MT5 slot inventory
reported nine running governed research terminals against the paced ceiling
of seven: `T1`, `T2`, `T4`, `T5`, `T6`, `T7`, `T8`, `T9`, and `T10`. It
reported no duplicate workers and no orphaned terminal processes.

The same inventory observed the separate `T_Live` and FTMO terminal processes
only to exclude them from the research count; neither was controlled or
modified. Because the terminal-count admission ceiling was already binding,
the mission's stop rule was applied immediately without another CPU probe or
queue mutation.

Q02 was not enqueued, dispatched, reserved, or run. No terminal was stopped,
no manual backtest was launched, and no work-item state was mutated.

## Safe handoff

After governed terminal occupancy falls below the ceiling, re-run the exact
target work-item check, target-only preview, terminal inventory, and a fresh
whole-host CPU sample before using the target-only `--apply` path for
`QM5_41073`. Do not broaden the sweep.

This record does not authorize AutoTrading, `T_Live`, deploy/T_Live manifest
changes, portfolio-gate changes, portfolio admission, a correlation waiver,
or live use. Q02 must retire the identity on zero trades, fewer than three
completed positions per full post-warm-up year, nonpositive governed
economics, or any hard-rule violation.
