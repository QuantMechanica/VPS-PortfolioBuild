# QM5_41002 Q01 loss-limit repair and Q02 handoff

- Date: 2026-08-21
- Branch: `agents/board-advisor`
- Agent task: `5d5cc9f6-e096-44a3-af78-99abc2d9e7ed`
- EA: `QM5_41002_robert-pardo-checkmate-breakout-engine`
- Scope: one H4 structural FX unit (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`)

## Selection and preflight

The farm claim identifies this as the highest-diversity unclaimed low-frequency
approved backlog item after excluding concurrently claimed cross-asset cards.
The approved card is sourced to Robert Pardo, *The Evaluation and Optimization
of Trading Strategies* (Wiley, 2008), carries `g0_status: APPROVED`, and passes
R1 through R4 with `ml_required: false`. The repo and runtime approved-card
copies matched SHA-256
`12643A9AA1741AF86783D5731EE0055E38D7B78DE70881AA1D1ECDFE16BE3F2B`.

Registry preflight found active EA identity `41002` and active magic slots:

| Slot | Symbol | Magic |
| ---: | --- | ---: |
| 0 | `EURUSD.DWX` | 410020000 |
| 1 | `GBPUSD.DWX` | 410020001 |
| 2 | `USDJPY.DWX` | 410020002 |

All three symbols are present in the governed DWX matrix. No registry or
resolver edit was required. There were no existing work items or sibling
claims for this EA when the task was claimed.

## Repair

The approved card has two separate broker-day controls: a 2.0% entry halt and
a 2.5% hard stop. The prior EA wired the 2.0% value directly to the framework
kill switch, which both collapsed the layered contract and failed the hardened
strict-build loss-limit check.

The repaired EA:

1. blocks only new entries at a 2.0% equity loss using the framework's
   restart-safe broker-day equity anchor;
2. continues managing existing exposure until the distinct 2.5% framework
   hard stop closes and halts it;
3. preserves the card's 5.0% total-drawdown threshold;
4. converts broker time to UTC before evaluating the 23:55-00:05 GMT rollover
   blackout; and
5. preserves the independently verified post-cache live-spread recheck.

No entry threshold, channel period, ATR rule, stop multiple, take-profit
multiple, or universe was changed.

## Build and fixed-risk artifacts

The governed generator produced one canonical `environment: backtest`,
`risk_mode: FIXED` setfile for every registered symbol. Each has
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

`validate_spec_doc.py` passed. Exactly one strict build invocation was made:

- report: `D:\QM\reports\framework\21\build_check_20260821_172305.json`
- result: `PASS`
- strict failures: 0
- strict warnings: 0
- compiler errors: 0
- compiler warnings: 0
- compile log: `C:\QM\repo\framework\build\compile\20260821_172305\QM5_41002_robert-pardo-checkmate-breakout-engine.compile.log`

Post-build artifact SHA-256 values:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `5DB2D150331F4349202103EC0C5ADC63EB797581692361E73BCC0A3AAEE02363` |
| EX5 | `470B551481AB5D22499FFF841436659026A7FB88C4F1C1C62B4D0B23B13DB57B` |
| EURUSD setfile | `6C867731D7BDE97B1BCC7CDBE9F5B0100E5033EAB97243C201283FAB10001264` |
| GBPUSD setfile | `D2E8E9AA0F9DEC3BF19D5E4B87CE2A44ED038C1C2E03BCB1F052FB7E2A984FCC` |
| USDJPY setfile | `D66981B1765917B0737DAE06574B7E56C1B63ED7962343D2662CE1FC8F9E9FCB` |

## Smoke disposition

The CPU preflight was below the ceiling (five-sample average 47.1%, maximum
74.8%). A first launcher call was rejected during argument resolution because
the caller supplied the wrong generated setfile directory; it allocated no
terminal and ran no test. The corrected single test submission was scheduled
on T8 but was refused by the Custom-history admission gate before EX5 deploy or
MT5 launch:

`active Custom-history isolation requires a worker-bound work item whose archives were privatized before run_smoke`

This is an infrastructure handoff condition, not an EA, trade-generation, or
CPU result. Farm recording therefore uses the supported
`smoke_result: deferred_p2_smoke` disposition so the first real test executes
inside Q02 with a worker-bound work item and privatized archives. No smoke
retry, parameter tuning, manual tester run, live terminal, AutoTrading change,
portfolio-gate change, or deploy-manifest change was made.

