# QM5_41082 Q01 PASS and Q02 CPU-ceiling stop

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41082_wti-wrunbreak-dom`

Outcome: `Q01 PASS`; `Q02 NOT_ENQUEUED_CPU_CEILING`

## New structural energy sleeve

`QM5_41082` is a low-frequency direct-WTI completed-week run-break momentum
strategy on exact `XTIUSD.DWX` D1. On the first tradable bar of a new Monday-
anchored broker week, it reconstructs four consecutive completed week-end
closes and three adjacent weekly log returns. The two older returns must share
a strict sign; the newest must oppose them and have an absolute move strictly
larger than the two older moves combined. The EA follows the newest sign,
which the inequality proves is also the cumulative three-week sign, for one
broker week with a frozen ATR hard stop.

This is a new direct physical-energy identity outside the certified
XAU/SP500/NDX/XNG book. It does not duplicate the incumbent XNG RSI pullback,
generic two-week WTI sign handoff, smaller weekly pullback, same-sign
acceleration/deceleration, outer-middle-restoration, weekly range/settlement,
three-week streak, or volatility-ranked families. It makes no ex-ante
decorrelation claim; Q09 alone owns realized portfolio correlation.

## Governance and build trail

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `f02d2a56e` |
| G0 card, deterministic EA/magic allocation, and resolver regeneration | `35c14eac4` |
| implementation and compiled binary | `4eedfeb69` |
| strict compile summary | `D:/QM/reports/compile/20260821_032202/summary.csv` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260821_032255.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41082/P1/P1_QM5_41082_result.json` |

Q01 evidence:

- deterministic reference suite: 9 tests passed;
- strict MetaEditor compile: 0 errors, 0 warnings;
- targeted build check: PASS, 0 failures, 0 warnings;
- static P1 validation: PASS;
- card/source schema, G0, registry, resolver, setfile, build guard, performance,
  and prohibited-signal checks: PASS;
- MQ5 SHA-256: `B0300A10983446C9D9EA7022FFA1D778661685DF1F43CA9CE37ED48E8D2F57EB`;
- EX5 SHA-256: `B60D73226B0A3A87F6D9975628FF0093A38B58B1B669FCD4E1A342911AEFBAE9`;
- setfile byte SHA-256: `4490DCC4CE6CE593A93527F531BBF818E35A3E428D6DE5C306A7A7AE0982CFBB`;
- normalized set build hash: `03a2c2e61e65afcc38784cf84ad4f31392bed9a19e3fdc378cf6b793ce63f9da`;
- strict build-report SHA-256: `8BA291F4187D98F8E88545832A9C07DC6243BB3CDA8817BFB2508B685B58DAEC`;
- static P1-report SHA-256: `4F5302C265CF74DCC50C5ED09C2402C95F8AA620EEEA7874F71386FC90620161`.

The only preset is the D1 backtest baseline with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close
OFF. No live, demo, shadow, stress, or optimization preset was created.

## Q02 target preflight

The supported farm view had no existing work item:

```text
python -m tools.strategy_farm.farmctl work-items --ea QM5_41082
count=0
```

The non-mutating target-only preview found exactly one fresh baseline row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41082 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
part3 deferred: promoted=0 kept=0
priority_track items: 1
```

No `--apply` invocation was made.

## Binding capacity stop

At `2026-08-21T03:20:22+00:00`, the canonical read-only MT5 slot inventory
reported seven running governed research terminals, the full paced ceiling:
`T3`, `T4`, `T5`, `T6`, `T7`, `T8`, and `T10`. All seven had active
reservations. The active work items were:

| Terminal | EA | Phase | Symbol |
|---|---|---|---|
| T3 | `QM5_11172` | Q07 | `XAUUSD.DWX` |
| T4 | `QM5_20234` | Q03 | `QM5_20234_XAU_XAG_RSJ_D1` |
| T5 | `QM5_10248` | Q07 | `NDX.DWX` |
| T6 | `QM5_20176` | Q05 | `USDJPY.DWX` |
| T7 | `QM5_20188` | Q07 | `USDJPY.DWX` |
| T8 | `QM5_12484` | Q07 | `XAUUSD.DWX` |
| T10 | `QM5_11205` | Q07 | `XAUUSD.DWX` |

The census reported zero duplicate terminal workers and zero orphaned terminal
processes. It observed the separate `T_Live` and FTMO terminals only to
exclude them from the governed research count; neither was controlled or
modified. Because the terminal-count admission ceiling was already binding,
the mission's capacity-stop rule was applied immediately without a redundant
host-CPU probe or queue mutation.

Q02 was not enqueued, dispatched, reserved, or run. No terminal was stopped,
no manual backtest was launched, and no work-item state was mutated.

## Safe handoff

After governed terminal occupancy falls below seven, re-run the exact target
work-item check, target-only preview, terminal inventory, and a fresh whole-
host CPU sample before using the target-only `--apply` path for `QM5_41082`.
Do not broaden the sweep.

This record does not authorize AutoTrading, `T_Live`, deploy/T_Live manifest
changes, portfolio-gate changes, portfolio admission, a correlation waiver,
or live use. Q02 must retire the identity on zero trades, fewer than two
completed positions per full post-warm-up year, nonpositive governed
economics, or any hard-rule violation.
