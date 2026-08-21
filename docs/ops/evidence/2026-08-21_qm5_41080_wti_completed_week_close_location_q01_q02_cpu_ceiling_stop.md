# QM5_41080 Q01 PASS and Q02 CPU-ceiling stop

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41080_wti-wclose-location-mom`

Outcome: `Q01 PASS`; `Q02 NOT_ENQUEUED_CPU_CEILING`

## New structural energy sleeve

`QM5_41080` is a low-frequency direct-WTI completed-week close-location
momentum strategy on exact `XTIUSD.DWX` D1. On the first tradable bar of a
new Monday-anchored broker week, it aggregates the immediately completed week
and its consecutive parent from completed D1 OHLC. It follows the completed
week only when the parent-to-newest final-close return has a strict sign and
the newest final close lies strictly in the matching outer fifth of that
week's own high-low range. A zero return, zero range, threshold equality,
malformed history, or return/location disagreement consumes the week flat.
An accepted position is held for one broker week with a frozen ATR hard stop.

This is a new direct physical-energy identity outside the certified
XAU/SP500/NDX/XNG book. It does not duplicate the existing XNG logic or the
nearby WTI weekday-segment, outside-settlement, current-week breakout, or
multi-week path mechanics. It makes no ex-ante decorrelation claim; Q09 alone
owns realized portfolio correlation.

## Governance and build trail

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `123294145` |
| deterministic EA reservation | `dfd62d52d` |
| magic allocation and resolver regeneration | `9ce17323a` |
| G0-approved card | `88d878565` |
| canonical backtest setfile | `993b3ee5c` |
| implementation and Q01 build | `4c0f1ef53` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260821_011727.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41080/P1/P1_QM5_41080_result.json` |

Q01 evidence:

- deterministic reference suite: 10 tests passed;
- strict MetaEditor compile: 0 errors, 0 warnings;
- targeted build check: PASS, 0 failures, 0 warnings;
- static P1 validation: PASS;
- card/source schema, build guard, and banned-signal checks: PASS;
- MQ5 SHA-256: `AC1BE954772DDB712CBE1D0C5C26A5CD360800A07763D0DB7F6D0F6DAD5533CD`;
- EX5 SHA-256: `AC9597714EA99E5A44A8E8D0E064C9E4F045C73A7F25F2F5DDC1D8AD77336D5E`;
- setfile byte SHA-256: `696636C147588E927A06EBD24FEC45BA754024EB9A91C30F268A2E8EC9FF241D`;
- normalized set build hash: `47a4c79400148e2f6a4671223b0b9da370ffe7c02569347a1913742d87cf92d5`.

The only preset is the D1 backtest baseline with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close
OFF. No live, demo, shadow, stress, or optimization preset was created.

## Q02 target preflight

The target had no existing work item:

```text
python -m tools.strategy_farm.farmctl work-items --ea QM5_41080
count=0
```

The non-mutating target-only preview found exactly one fresh baseline row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41080 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
part3 deferred: promoted=0 kept=0
priority_track items: 1
```

No `--apply` invocation was made.

## Binding capacity stop

At `2026-08-21T01:23:25+00:00`, the canonical read-only MT5 slot inventory
reported eight running governed research terminals against the paced ceiling
of seven: `T1`, `T4`, `T5`, `T6`, `T7`, `T8`, `T9`, and `T10`. It reported
no duplicate terminal workers and no orphaned terminal processes.

The same inventory observed the separate `T_Live` and FTMO terminal processes
only to exclude them from the research count; neither was controlled or
modified. Because the terminal-count admission ceiling was already binding,
the mission's CPU-ceiling stop rule was applied immediately without another
CPU probe or queue mutation.

Q02 was not enqueued, dispatched, reserved, or run. No terminal was stopped,
no manual backtest was launched, and no work-item state was mutated.

## Safe handoff

After governed terminal occupancy falls below the ceiling, re-run the exact
target work-item check, target-only preview, terminal inventory, and a fresh
whole-host CPU sample before using the target-only `--apply` path for
`QM5_41080`. Do not broaden the sweep.

This record does not authorize AutoTrading, `T_Live`, deploy/T_Live manifest
changes, portfolio-gate changes, portfolio admission, a correlation waiver,
or live use. Q02 must retire the identity on zero trades, fewer than five
completed positions per full post-warm-up year, nonpositive governed
economics, or any hard-rule violation.
