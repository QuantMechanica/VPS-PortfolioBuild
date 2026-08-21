# QM5_41081 Q01 PASS and Q02 CPU-ceiling stop

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41081_xng-wclose-location-mom`

Outcome: `Q01 PASS`; `Q02 NOT_ENQUEUED_CPU_CEILING`

## New structural energy sleeve

`QM5_41081` is a low-frequency `XNGUSD.DWX` completed-week close-location
momentum strategy. On the first tradable D1 bar of a new Monday-anchored
broker week, it aggregates the immediately completed week and its consecutive
parent from completed D1 OHLC. It follows the completed week only when the
parent-to-newest final-close return has a strict sign and the newest final
close lies strictly in the matching outer fifth of that week's own high-low
range. A zero return, zero range, threshold equality, malformed history, or
return/location disagreement consumes the week flat. An accepted position is
held for one broker week with a frozen ATR hard stop.

This is mechanically different from certified
`QM5_12567_cum-rsi2-commodity`: symmetric completed-week trend confirmation
and a one-week lifecycle versus a long-only two-day cumulative-RSI2 pullback,
slow-mean filter, and five-bar maximum hold. The shared XNG carrier and logic
difference do not prove decorrelation; Q09 alone owns realized portfolio
correlation.

## Governance and build trail

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `2f2604d49` |
| deterministic EA reservation | `fe2015ce2` |
| magic allocation and resolver regeneration | `b76ba3d42` |
| G0-approved card | `63c08bcaf` |
| implementation and Q01 build | `6971a0537` |
| strict compile summary | `D:/QM/reports/compile/20260821_021545/summary.csv` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260821_021952.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41081/P1/P1_QM5_41081_result.json` |

Q01 evidence:

- deterministic reference suite: 10 tests passed;
- strict MetaEditor compile: 0 errors, 0 warnings;
- targeted build check: PASS, 0 failures, 0 warnings;
- static P1 validation: PASS;
- card/source schema, G0, build guard, and prohibited-signal checks: PASS;
- MQ5 SHA-256: `29EBCA369972F352D67C3642271A912B79721F38E1E9A99B4BC561A73C1EC1E5`;
- EX5 SHA-256: `DA2EC2E642A3FA6FD5FAC58CA4EA8E314FFE4390AAE15BAEDF85B89D3F9E6E16`;
- setfile byte SHA-256: `566FD525C68D85BF598D2D835BED72B27F31ACB0EF335A3FD6FC8E817548AF6F`;
- normalized set build hash: `5aa25ac7330c67c05b7235afb03662c3ec5c92bba76bf6ab525c81475ab3292b`.

The only preset is the D1 backtest baseline with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close
OFF. No live, demo, shadow, stress, or optimization preset was created.

## Q02 target reconciliation

The supported farm view was queried before any enqueue mutation:

```text
python -m tools.strategy_farm.farmctl work-items --ea QM5_41081
count=0
```

No pending, active, done, or failed row exists for this EA. A target-only
non-apply sweep preview was invoked alongside the capacity checks; it carried
no `--apply` flag and its output was not used because the binding CPU ceiling
required an immediate stop. No queue row or priority was mutated.

## Binding capacity stop

Five consecutive whole-host `Win32_Processor` samples across 16 logical
processors were:

| Sample UTC | Average | Maximum |
|---|---:|---:|
| `2026-08-21T02:23:23.7414234Z` | 100% | 100% |
| `2026-08-21T02:23:28.4194052Z` | 100% | 100% |
| `2026-08-21T02:23:31.8470976Z` | 100% | 100% |
| `2026-08-21T02:23:35.1168244Z` | 100% | 100% |
| `2026-08-21T02:23:38.3336639Z` | 100% | 100% |

Every sample exceeded the governed 97% hard CPU ceiling.

The canonical `farmctl mt5-slots` census at
`2026-08-21T02:23:27+00:00` found seven running governed research terminals,
the full paced ceiling: `T3`, `T4`, `T5`, `T7`, `T8`, `T9`, and `T10`. All
seven were reserved. The census reported zero duplicate terminal workers and
zero orphaned terminal processes. `T_Live` and the unrelated FTMO terminal
were observed only by the read-only census and excluded from the research
count; neither was accessed or changed.

Because both host CPU and paced terminal capacity were binding, the mission's
CPU-ceiling stop rule was applied before queue mutation. Q02 was not enqueued,
dispatched, reserved, or run. No terminal was stopped or controlled, and no
manual backtest was launched.

## Safe handoff

After governed terminal occupancy falls below seven and a fresh whole-host
CPU sample is below the hard ceiling, repeat the exact target work-item query,
the target-only preview, and the capacity census before using the target-only
`--apply` path for `QM5_41081`. Do not broaden the sweep.

This record does not authorize AutoTrading, `T_Live`, deploy/T_Live manifest
changes, portfolio-gate changes, portfolio admission, a correlation waiver,
or live use. Q02 must retire the identity on zero trades, fewer than five
completed positions per full post-warm-up year, nonpositive governed
economics, or any hard-rule violation.

Machine-readable evidence:
`artifacts/qm5_41081_q02_cpu_ceiling_stop_20260821T022323Z_board_advisor.json`.

