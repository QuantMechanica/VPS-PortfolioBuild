# QM5_41079 Q02 CPU-ceiling stop

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41079_xauxag-wclose-extreme-rv`

Outcome: `Q01 PASS`; `Q02 NOT ENQUEUED`; the mandatory tester and host-CPU
capacity gate stopped this lane before queue mutation.

## New commodity sleeve delivered

`QM5_41079` is a new low-frequency XAU/XAG relative-value basket. On the
first tradable D1 bar of a new broker week, it ranks all three to five
synchronized gold-minus-silver log-ratio closes in the immediately completed
week. It fades the final close only when that close is strictly above or
strictly below every earlier close. The legs are opposite-side and target
equal absolute notional, share one fixed-risk budget, carry frozen ATR hard
stops, and close in the next broker week.

The mechanic does not estimate a rolling center, hedge ratio, z-score,
quantile, return streak, return magnitude, or channel failure. The canonical
pre-allocation checker returned `CLEAN` across 4,566 registry rows and 625
root cards. The source boundary treats the weekly closing-rank fade as an
untested QM translation and transfers no efficacy, neutrality, or
decorrelation claim.

## Committed governed build

| Commit | Scope |
|---|---|
| `37d65f4e0` | durable source approval and bounded reputable-source packet |
| `4a7c2d633` | deterministic EA ID 41079 reservation |
| `3e9cd1cd9` | schema-valid approved card and G0 decision |
| `89c51ac42` | active basket magics 410790000/410790001 and regenerated resolver |
| `1b39ab613` | paired MQ5/EX5, basket manifest, fixed-risk setfile, reference suite, and Q01 evidence links |

The only preset is one logical D1 backtest setfile locking
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No live, demo,
shadow, stress, or optimization setfile was created.

## Q01 evidence

- Ten deterministic reference tests passed, covering both strict entry
  directions, equality/interior/invalid/asynchronous flat states, session
  bounds, first-week-bar timing, restart attempt persistence, lifecycle, and
  equal-notional aggregate-risk sizing.
- Card schema and prohibited-signal lint passed with no missing sections and
  no ML or banned-indicator hits.
- Strict compile passed with zero errors and zero warnings.
- Targeted strict build check passed with zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260821_003146.json`.
- Static P1 validation passed:
  `D:/QM/reports/pipeline/QM5_41079/P1/P1_QM5_41079_result.json`.
- MQ5 SHA-256:
  `2F17E1FB8246E80C2F8CD203B365FB4881FFDFE249BAC11D794452B8036E45E2`.
- EX5 SHA-256:
  `4A29B27DD4E1518328EEA6C4E61ED6A932298E2CA1D8167635F4C5B428F8E189`.
- Setfile byte SHA-256:
  `09779539AE6BE2B9F1BB41AFAFE6BBCEBE3006866FBD59D11CCAE08EA105C4F8`.
- Basket-manifest SHA-256:
  `FE14091F674C38D007C94A60B40C4B8CF4DB32063CA7BAB5EFA124FBCBE7D8CA`.

## Target-only queue reconciliation

The supported farm view was queried before any enqueue attempt:

```text
python tools/strategy_farm/farmctl.py work-items --ea QM5_41079
count=0
```

No pending, active, done, or failed Q02 row exists for this EA. Because the
mandatory capacity gate failed, this lane did not run an apply preview,
enqueue, dispatcher tick, reservation, claim, or tester command. The external
state is `Q02_NOT_ENQUEUED_CPU_CEILING`, not a Q02 PASS.

## Binding paced-fleet capacity stop

Five consecutive whole-host `Win32_Processor` samples across 16 logical
processors were:

| Sample UTC | Average | Maximum |
|---|---:|---:|
| `2026-08-21T00:36:50.3610805Z` | 100% | 100% |
| `2026-08-21T00:36:52.5226965Z` | 100% | 100% |
| `2026-08-21T00:36:54.5864090Z` | 100% | 100% |
| `2026-08-21T00:36:56.7644881Z` | 100% | 100% |
| `2026-08-21T00:36:58.7968343Z` | 100% | 100% |

Every sample exceeded the governed 97% hard CPU ceiling.

The canonical `farmctl mt5-slots` census at
`2026-08-21T00:37:17+00:00` independently found eight running governed
research terminals, above the paced terminal ceiling of seven: `T2`, `T3`,
`T4`, `T5`, `T6`, `T7`, `T8`, and `T9`. All eight were reserved. The census
reported zero duplicate terminal workers and zero orphaned terminal
processes. `T_Live` and the unrelated FTMO terminal were observed only by the
read-only census and were excluded from the research count; neither was
accessed or changed.

## Safe handoff

A later paced worker should first repeat the exact target work-item query and
the tester/CPU preflight. Only when both governed ceilings have cleared should
it append exactly one Q02 row for `QM5_41079`; it must reconcile again after
enqueue and must not create a sibling. Normal fleet workers may claim the row.

No smoke or manual backtest was launched and no terminal was controlled. The
portfolio gate, T_Live manifest, T_Live files, and AutoTrading were not
touched. Q02 remains responsible for density and economic falsification; Q09
alone may establish realized portfolio correlation. Machine-readable
evidence is in
`artifacts/qm5_41079_q02_cpu_ceiling_stop_20260821T003650Z_board_advisor.json`.
