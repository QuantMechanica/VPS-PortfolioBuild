# QM5_41091 WTI weekly inside-body Q01 and Q02 CPU-ceiling stop

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41091_wti-winside-body-mom`

Outcome: `Q01 PASS`; `Q02 NOT_ENQUEUED_CPU_CEILING`

## New structural energy sleeve

`QM5_41091` is a low-frequency, symmetric direct-WTI continuation strategy on
exact `XTIUSD.DWX` D1. At the first tradable bar of each normalized broker
week it reconstructs the two immediately completed consecutive weekly OHLC
packages, requiring three to five unique sessions in each. It trades only
when the newest package is strictly inside its parent range, buying a strict
bullish newest-week body and selling a strict bearish body. Equal endpoints,
an equal open and close, non-inside geometry, malformed history, or late
attachment consume the week flat.

Each accepted position has one frozen `3.5 * ATR(20,D1)` hard stop, no target,
one durable attempt per week, and a normal next-week exit with ten-day stale
repair. Direct WTI and the inside-week/body mechanic are diversification
hypotheses only. Q09 alone may establish realized portfolio correlation.

## Governance, novelty, and build trail

Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, supplies the
peer-reviewed own-price continuation lineage and explicitly includes WTI
futures. The weekly inside-range/body translation is disclosed as an untested
QM hypothesis; no source performance or continuous-CFD equivalence transfers.

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `9f47d0a0d` |
| bounded source extraction | `70ab22cd8` |
| deterministic EA-ID reservation | `df65b49a4` |
| G0-approved card | `8ba0e1d6a` |
| slot-zero magic and resolver | `c306a8718` |
| implementation and Q01 build | `79b2045c4` |
| strict compile summary | `D:/QM/reports/compile/20260821_132211/summary.csv` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260821_132505.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41091/P1/P1_QM5_41091_result.json` |

The fail-closed canonical pre-allocation check used the actual Company
Reference Wiki root and returned `CLEAN` across 4,580 registry rows, 1,253
repository cards, and 45 Wiki strategy nodes. Manual review separated the
identity from WTI inside-week breakouts, NR7, outside settlement, range
migration, midpoint overlap, close-location, and XNG cumulative-RSI2 families.

## Q01 evidence

- approved-card schema and prohibited-ML lint: PASS;
- governed card/build prerequisite guard: PASS;
- deterministic reference suite: 13 tests PASS;
- strict MetaEditor compile: PASS, 0 errors and 0 warnings;
- strict V5 build check: PASS, 0 failures and two non-fatal card-discovery
  advisories; the explicit approved-card lint passed independently;
- static P1 artifact validation: PASS;
- MQ5 SHA-256:
  `238b3edba58601e5660077da47fae940fb805cc8bf431eb9f44f655f1c32a965`;
- EX5 SHA-256:
  `850cfbf98d966873b792bd1fb7d93a0c4af1231e7ca9019a78f65e809f873c71`;
- setfile byte SHA-256:
  `33b56373ae212a7f73a34b5b4c393b12d363fdae0b0aea481a8d4b3a9b6f0f6c`;
- normalized set build hash:
  `793f2d5798ef1e123b2d2af83470370a4545fbc2442195f494a872d9e078e9f9`;
- strict build-report SHA-256:
  `7274d67e3f9064500471d58b8b7796f3344465c7f73322b56d9f0424dc4e590f`;
- static P1-report SHA-256:
  `a04b3144f16e7ae7d1fd03a3ee2b7327f9d1787964c0425f0cd58a93f42906c9`.

The sole preset is the exact D1 backtest baseline with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close
OFF. No smoke, manual tester, or backtest run was started.

## Q02 target and fleet preflight

The canonical supported farm view returned zero existing work items for the
exact EA:

```text
python tools/strategy_farm/farmctl.py work-items --ea QM5_41091
count=0
```

At `2026-08-21T13:29:43Z`, read-only `farmctl mt5-slots` reported three
running governed research terminals (`T2`, `T3`, and `T8`) and five resident
worker slots (`T2`, `T3`, `T4`, `T6`, and `T8`). It reported zero duplicate
terminal workers and zero orphaned terminal processes. The separate `T_Live`
and FTMO processes were observed only so they could be excluded; neither was
accessed or changed.

Five whole-host CPU samples at four-second spacing then produced:

| Sample UTC | CPU |
|---|---:|
| `2026-08-21T13:29:58.4989359Z` | 36.74% |
| `2026-08-21T13:30:03.6102437Z` | 100.00% |
| `2026-08-21T13:30:08.6158406Z` | 52.09% |
| `2026-08-21T13:30:13.6188802Z` | 64.67% |
| `2026-08-21T13:30:18.6208856Z` | 32.34% |

The average was 57.17 percent and the maximum was 100.00 percent. The paced
fleet's hard rule binds when either average or maximum reaches 97 percent, so
the maximum sample fired the mission's explicit CPU-ceiling stop.

No `--apply`, `enqueue-backtest`, `seed-fresh-q02`, dispatcher, reservation,
terminal control, smoke, or tester command was issued. Q02 remains unqueued
with zero work items.

## Safe handoff

After a fresh sample keeps both average and maximum below 97 percent and the
governed terminal count remains below seven, repeat the exact work-item query,
target-only preview, and capacity check before using the target-only apply path
for `QM5_41091`. Do not broaden the sweep.

Q02 must retire the identity on zero trades, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, or any
label, anchor, OHLC, containment, body-side, attempt, or lifecycle defect. It
may not be rescued by accepting equality, changing containment to overlap,
adding a breakout/current-week filter, reversing the side, or tuning the hold.

This record does not authorize AutoTrading, `T_Live`, deploy/T_Live manifest
changes, portfolio-gate changes, portfolio admission, a decorrelation claim,
a correlation waiver, or live use.

Machine-readable evidence:
`artifacts/qm5_41091_q02_cpu_ceiling_stop_20260821T133018Z_board_advisor.json`.
