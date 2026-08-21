# QM5_41093 WTI weekly closing-breakout Q01 and Q02 enqueue

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41093_wti-wclose-breakout-mom`

Outcome: `Q01 PASS`; `Q02 ENQUEUED_PENDING`

## New structural energy sleeve

`QM5_41093` is a low-frequency, symmetric direct-WTI continuation strategy on
exact `XTIUSD.DWX` D1. At the first tradable bar of a normalized
Monday-anchored broker week, it reconstructs the exact two immediately
completed three-to-five-session weekly OHLC packages. It buys only when the
newest chronological final close is strictly above the parent aggregate high,
or sells only when it is strictly below the parent aggregate low. Endpoint
equality, an inside-range close, malformed or nonadjacent history, and late
attachment consume the week flat.

Each accepted position uses `RISK_FIXED=1000`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, one durable attempt per week, and a
normal next-week exit with ten-day stale repair. Direct WTI and this mechanic
are diversification hypotheses only. Q02 owns activity/economics and Q09
alone may establish realized portfolio correlation.

## Governance and build trail

Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, supplies the
peer-reviewed own-price continuation lineage and explicitly includes WTI
futures. Szakmary, Shen, and Sharma (2010) supplies peer-reviewed commodity
completed-extrema channel lineage. The exact parent-week range versus
newest-week final-close rule is a disclosed QM translation; no source
performance, standalone continuous-CFD result, or book-correlation claim
transfers.

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `f0d8fe585` |
| bounded source extraction | `cfaabdb97` |
| deterministic EA-ID reservation | `2a20468ce` |
| G0-approved card | `04cbd4f8f` |
| slot-zero magic and resolver | `d904213d2` |
| implementation and Q01 build | `11334990b` |
| strict compile summary | `D:/QM/reports/compile/20260821_160343/summary.csv` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260821_160421.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41093/P1/P1_QM5_41093_result.json` |

The canonical pre-allocation duplicate check returned no exact identity across
4,582 registry rows, 1,255 cards, and 45 Strategy Wiki nodes. Manual family
review separated this final-close-versus-parent-range rule from inside-body,
close-location, both-sided outside-settlement, endpoint-migration, NR7,
monthly three-close, one-week body-dominance, and XNG RSI2 identities. In
particular, `QM5_41092` uses one week's own two-thirds real-body share and has
no parent range; `QM5_41093` ignores own-body direction and requires its final
close beyond a separate parent week.

## Q01 evidence

- card schema and prohibited-ML lint: PASS;
- deterministic reference suite: 13 tests PASS;
- strict MetaEditor compile: PASS, zero errors and zero warnings;
- strict V5 build check: PASS, zero failures and two non-fatal approved-card
  discovery advisories; explicit approved-card lint passed independently;
- SPEC validator: PASS;
- static P1 artifact validation: PASS;
- MQ5 SHA-256:
  `a08d389fc6c6d59acdf2bd8334ef122ff74227a3cb3eae7bb21f39366cfbf63d`;
- EX5 SHA-256:
  `2e2988a0b87c4d9616bcf92a0ced83d45b94e75288814eb8c9a2d00ae29a8aee`;
- setfile byte SHA-256:
  `f49034b680a88f0589be29e50cce5c61c5dd5a8541e96b61c73ad6a687684ecc`;
- normalized set build hash:
  `234c1d9263097b7a2cd70bb79d8dbc181f38ce0d1e55a0866253dfc322d86eeb`.

The single preset is exact D1 backtest scope with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close
OFF. No manual tester or smoke backtest ran.

## Q02 target and paced admission

The canonical target query returned zero pre-existing work items. The exact
target-only, non-mutating preview selected one fresh baseline and nothing
stranded:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41093 --symbols XTIUSD.DWX --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

Read-only `farmctl mt5-slots` at `2026-08-21T16:11:00Z` reported two active
governed terminals (`T3`, `T4`), four resident worker slots (`T1` through
`T4`), zero duplicate terminal workers, and zero orphaned tester processes.
The separate `T_Live` and FTMO processes were excluded; neither was accessed
or controlled.

Five whole-host CPU samples at four-second spacing stayed below the 97 percent
hard ceiling:

| Sample UTC | CPU |
|---|---:|
| `2026-08-21T16:11:22.9094799Z` | 76.49% |
| `2026-08-21T16:11:26.9691798Z` | 89.05% |
| `2026-08-21T16:11:30.9736732Z` | 81.56% |
| `2026-08-21T16:11:34.9748061Z` | 71.93% |
| `2026-08-21T16:11:38.9754011Z` | 78.67% |

Average CPU was 79.54 percent and maximum CPU was 89.05 percent. Governed
terminal occupancy was 2/7, so the paced capacity gate admitted one target.

## Queue result

The same target-only command with `--apply` enqueued one item and skipped
zero. Post-apply reconciliation returned exactly one work item:

| Field | Value |
|---|---|
| work item | `be766bd9-7310-45bc-8cbc-c2fdbe90b00b` |
| phase | `Q02` |
| kind | `backtest` |
| symbol | `XTIUSD.DWX` |
| status | `pending` |
| attempt count | `0` |
| claimed by | `null` |
| created UTC | `2026-08-21T16:11:49Z` |

No dispatcher tick, reservation, tester process, terminal control, manual
backtest, or duplicate queue item was started.

## Safe handoff

Allow the paced fleet to claim the one pending Q02 item. Q02 must retire this
identity on zero trades, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, or any label, anchor,
session-count, parent-extrema, final-close, strict-comparison, side, attempt,
risk, or lifecycle defect. It may not be rescued by accepting equality,
adding a breakout buffer, substituting the newest high/low, reversing the
side, changing the hold, or adding a body, close-location, outside-expansion,
migration, calendar, volatility, volume, moving-average, inventory, or
external-data filter.

This record does not authorize AutoTrading, `T_Live`, live/demo/shadow/stress/
optimization presets, deploy or T_Live manifest changes, portfolio-gate
changes, portfolio admission, a decorrelation claim, or a correlation waiver.

Machine-readable evidence:
`artifacts/qm5_41093_q02_enqueue_20260821T161149Z_board_advisor.json`.
