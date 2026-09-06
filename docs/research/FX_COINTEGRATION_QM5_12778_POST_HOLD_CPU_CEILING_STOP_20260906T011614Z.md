# QM5_12778 post-hold FX continuation / hard CPU stop

Recorded: 2026-09-06T01:16:14Z (03:16 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `42430a7b33e0fe7a9f7dc41e35651abef7ab1e51`

## Outcome

The concrete existing FX continuation is the low-frequency D1
`QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1` basket. Its repaired Q09_NEWS
work item remains uniquely pending, priority-bound, unclaimed, unsuperseded,
and free of active holds. A fresh static qualification confirmed that the
approved Card, two-leg basket manifest, and fixed-risk backtest package remain
valid.

No tester was started because the explicit 97% backtest CPU ceiling bound:
five one-second whole-host samples were all 100%. No duplicate queue row or
priority write was made.

## Why no new Card or anchor repair was made

The durable sign-aware reconciliation of the 66-pair FX discovery scan already
accounts for every relationship with a built identity. Creating another Card,
EA, or basket manifest from that scan would duplicate governed work.

The two preferred anchors also have real logical-basket Q02 passes rather than
current ONINIT or NO_HISTORY blockers:

- `QM5_12532` AUDUSD/NZDUSD: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY: Q02 PASS, then Q04 FAIL.

The mission's existing-card fallback therefore applies.

## Selected continuation

- EA: `QM5_12778_edgelab-audusd-eurjpy-cointegration`
- Traded relationship: `AUDUSD.DWX` / `EURJPY.DWX`
- Logical symbol: `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`
- Timeframe and expected cadence: D1, approximately 4-8 logical packages/year
- Work item: `24acc5d4-3e34-526e-a7a8-12640a2e759f`
- Phase/state: Q09_NEWS, pending, unclaimed, attempt 0, no verdict
- Duplicate guard: exactly one open identical `(EA, phase, host symbol)` row
- Holds/supersession: zero active holds and no supersession row
- Risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- Basket scope: AUDUSD and EURJPY are traded; EURUSD and EURAUD are conversion-history dependencies only

The prior `NEWS_CALENDAR_TIMESTAMP_DEFECT` hold remains correctly inactive
after the governed release recorded at 2026-09-05T23:22:04Z. This wake did not
repeat that release or modify the work-item payload.

## Static qualification

- Approved-card schema lint: PASS, no missing sections and no ML hits.
- FX basket-manifest regression: 47 passed in 1.25 seconds.
- Card source: Ernest P. Chan's cointegration method plus the OWNER-requested,
  reproducible Darwinex `.DWX` 66-pair scan.
- The EA remains fixed-beta structural spread reversion with no adaptive
  refit, learned model, grid, or martingale.

Sealed artifact SHA-256 values at inspection:

| Artifact | SHA-256 |
| --- | --- |
| Approved Card | `5878c99d9cef732642f99961556dd8bd049e14b42292b61aa72a047b4558134a` |
| MQ5 | `132a501d94685f013cc62a8b3c2de111d0a8b1e616a8656d2c61b061a754c146` |
| EX5 | `2a105cfbb364142c96c552136bb450162c142845665ce3366d0c045248c17a01` |
| Basket manifest | `0ce25d17ebe7c3664e4acdb6c1d302b28b1f40710301189cc633e44f25854d57` |
| Logical backtest setfile | `0e7949276927c8c5355c413c631e7b67f684e757892de59fa2cff5521836c8e9` |

## Capacity stop and safety

The CPU sample window ended at 2026-09-06T01:16:14Z with average 100% and
maximum 100%. At the accompanying state read, the farm had five active and
12,650 pending work items; five factory terminal processes were observed one
minute later. Per the mission's hard stop, there was no claim, dispatch,
compile, backtest, terminal control, queue mutation, or re-enqueue.

No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
T_Live manifest/file, live/deploy, or AutoTrading surface was touched.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12778_post_hold_cpu_ceiling_stop_20260906T011614Z_board_advisor.json`.

## Resume contract

After host CPU clears the 97% ceiling, re-read the same work item and let the
ordinary paced worker consume it if it remains unique, pending, unheld, and
unclaimed. Do not append a duplicate or rewrite its sealed Q09_NEWS order.
