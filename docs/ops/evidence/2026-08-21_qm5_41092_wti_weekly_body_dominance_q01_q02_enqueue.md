# QM5_41092 WTI weekly body-dominance Q01 and Q02 enqueue

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41092_wti-wbody-dominance-mom`

Outcome: `Q01 PASS`; `Q02 ENQUEUED_PENDING`

## New structural energy sleeve

`QM5_41092` is a low-frequency, symmetric direct-WTI continuation strategy on
exact `XTIUSD.DWX` D1. At the first tradable bar of a normalized
Monday-anchored broker week, it reconstructs only the immediately completed
three-to-five-session weekly OHLC package. It buys a positive completed body
or sells a negative completed body only when
`3*abs(close-open) > 2*(high-low)` holds strictly. Exact threshold equality,
body equality, malformed or nonadjacent history, and late attachment consume
the week flat.

Each accepted position uses `RISK_FIXED=1000`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, one durable attempt per week, and a
normal next-week exit with ten-day stale repair. Direct WTI and this mechanic
are diversification hypotheses only. Q02 owns activity/economics and Q09
alone may establish realized portfolio correlation.

## Governance and build trail

Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, supplies the
peer-reviewed own-price continuation lineage and explicitly includes WTI
futures. The weekly two-thirds body condition is a disclosed QM translation;
no source performance, standalone continuous-CFD result, or book-correlation
claim transfers.

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `06f2ed136` |
| bounded source extraction | `069b4af00` |
| deterministic EA-ID reservation | `1a02d01dd` |
| G0-approved card | `6d185e5bc` |
| slot-zero magic and resolver | `a1f576e5c` |
| implementation and Q01 build | `aed1d6072` |
| strict compile summary | `D:/QM/reports/compile/20260821_142311/summary.csv` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260821_142337.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41092/P1/P1_QM5_41092_result.json` |

The canonical pre-allocation duplicate check returned clean before identity
allocation across 4,581 registry rows, 1,254 cards, and 45 Strategy Wiki
nodes. Manual family review separated the load-bearing one-week body-share
rule from WTI parent-close return, range-rank, endpoint-migration,
midpoint-overlap, inside-parent, close-location, and XNG RSI2 identities.

## Q01 evidence

- card schema and prohibited-ML lint: PASS;
- deterministic reference suite: 11 tests PASS;
- strict MetaEditor compile: PASS, zero errors and zero warnings;
- strict V5 build check: PASS, zero failures and two non-fatal approved-card
  discovery advisories; explicit approved-card lint passed independently;
- SPEC validator: PASS;
- static P1 artifact validation: PASS;
- MQ5 SHA-256:
  `8ab57c0fede965dcdf4435dd3e153725f1a8525b340bcf31ba78859dee55f14f`;
- EX5 SHA-256:
  `da0e57dee8b4b16887ee74f5ce2627a1b029553d489fbdd2cb43862a8fb9e224`;
- setfile byte SHA-256:
  `1ab7ce5e4ebd8019b08295bcccc5f689dd2a8f8888fc86a186c8152c22d145bc`;
- normalized set build hash:
  `1e2f782016e8a2a81e403c8940d2a971cb182af90fda43e4657b5d5b36adaefb`.

The single preset is exact D1 backtest scope with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close
OFF. No manual tester or smoke backtest ran.

## Q02 target and paced admission

The canonical target query returned zero pre-existing work items. The exact
target-only, non-mutating preview selected one fresh baseline and nothing
stranded:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41092 --symbols XTIUSD.DWX --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

Read-only `farmctl mt5-slots` at `2026-08-21T14:31:03Z` reported two active
governed terminals (`T1`, `T2`), four resident worker slots (`T1` through
`T4`), zero duplicate terminal workers, and zero orphaned tester processes.
The separate `T_Live` and FTMO processes were excluded; neither was accessed
or controlled.

Five whole-host CPU samples at four-second spacing stayed below the 97 percent
hard ceiling:

| Sample UTC | CPU |
|---|---:|
| `2026-08-21T14:31:47.3100000Z` | 68.36% |
| `2026-08-21T14:31:51.3120000Z` | 67.27% |
| `2026-08-21T14:31:55.3130000Z` | 75.96% |
| `2026-08-21T14:31:59.3130000Z` | 63.09% |
| `2026-08-21T14:32:03.3140000Z` | 74.35% |

Average CPU was 69.81 percent and maximum CPU was 75.96 percent. Governed
terminal occupancy was 2/7, so the paced capacity gate admitted one target.

## Queue result

The same target-only command with `--apply` enqueued one item and skipped
zero. Post-apply reconciliation returned exactly one work item:

| Field | Value |
|---|---|
| work item | `1c0dcc3a-69cf-46dc-96fb-e8f111c949ac` |
| phase | `Q02` |
| kind | `backtest` |
| symbol | `XTIUSD.DWX` |
| status | `pending` |
| attempt count | `0` |
| claimed by | `null` |
| created UTC | `2026-08-21T14:32:19Z` |

No dispatcher tick, reservation, tester process, terminal control, manual
backtest, or duplicate queue item was started.

## Safe handoff

Allow the paced fleet to claim the one pending Q02 item. Q02 must retire this
identity on zero trades, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, or any label, anchor,
session-count, body-threshold, side, attempt, risk, or lifecycle defect. It may
not be rescued by accepting equality, lowering the threshold, adding a parent,
wick, current-week, return-size, calendar, volatility, volume, moving-average,
inventory, or external-data filter, reversing the side, or tuning the hold.

This record does not authorize AutoTrading, `T_Live`, live/demo/shadow/stress/
optimization presets, deploy or T_Live manifest changes, portfolio-gate
changes, portfolio admission, a decorrelation claim, or a correlation waiver.

Machine-readable evidence:
`artifacts/qm5_41092_q02_enqueue_20260821T143219Z_board_advisor.json`.
