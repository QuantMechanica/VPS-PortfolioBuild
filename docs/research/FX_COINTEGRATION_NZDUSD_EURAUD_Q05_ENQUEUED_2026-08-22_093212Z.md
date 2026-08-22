# QM5_20208 NZDUSD/EURAUD Q05 enqueue

Date: 2026-08-22 UTC (`2026-08-22T09:32:12Z`)

Branch: `agents/board-advisor`

Status: existing non-duplicate FX basket advanced from Q04 to Q05

## Outcome

The frozen 66-pair FX cointegration frontier remains fully mechanized, so no
duplicate Strategy Card, registry identity, basket manifest, or EA was
created. The preferred anchors are not blocked at Q02: `QM5_12532` has Q02
PASS and Q04 PASS followed by Q05 FAIL, while `QM5_12533` has Q02 PASS
followed by Q04 FAIL.

The existing rank-27 market-neutral basket `QM5_20208_nzdusd-euraud` was
advanced instead. Its Q04 `PASS_LOWFREQ` predecessor is terminal, no Q05 row
existed at preflight, the five-sample CPU gate passed, and the canonical
enqueue created exactly one Q05 work item:

- EA: `QM5_20208_nzdusd-euraud`
- Logical basket: `QM5_20208_NZDUSD_EURAUD_COINTEGRATION_D1`
- Traded legs: `NZDUSD.DWX` and `EURAUD.DWX`
- Q04 predecessor: `3703d3fd-6e3a-4fc2-bc4a-20b2984479b2`
- New Q05 work item: `1a53b4bd-abbd-4c6e-a13a-5f1a1542bf8d`
- Post-enqueue state: `pending`, attempt count `0`, no verdict

The paced fleet may claim the row normally. No tester was launched manually.

## Non-duplicate basis

The durable scan reconciliation in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 sign-aware relationships. Creating another scan-derived
card would duplicate an existing identity. The selected fallback has one
approved card, one EA directory, one logical basket, and now one Q05 successor.

The approved card is
`strategy-seeds/cards/approved/QM5_20208_nzdusd-euraud_card.md`, backed by the
Tier-A Chan cointegration-family extraction at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. The strategy
is structural D1 relative value with a fixed beta; no ML, grid, martingale,
parameter refit, or rescue filter was introduced.

## Bound build contract

- EX5 SHA-256:
  `31d4460df6cd3e9ef579d8ed4e3849e62b3423ef0e942f6703122e2245988bc4`
- Setfile SHA-256:
  `f6ae2633e6ec4e54a7e14835c16c50c231c4135495abf7f3cdb00eaf5346ae04`
- Basket-manifest SHA-256:
  `ed2fac5d413a6a4665388f73d22606408e51a7e317136e4ac8ed0a8369aa8796`
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- Active magics: NZDUSD slot 0 / `202080000`; EURAUD slot 1 / `202080001`

AUDUSD and EURUSD remain conversion-history dependencies only. The Q05 row
binds the canonical `basket_manifest.json`, all four history symbols, a USD
tester account, and the 2017-2022 test window.

## CPU gate and enqueue evidence

At `2026-08-22T09:31:55Z`, five one-second total-processor samples were:

`[89.16, 88.92, 74.85, 93.07, 86.33] %`

The maximum was `93.07%`, below the binding `97%` ceiling. The exact mutation
was:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_20208 --phase Q05 --from-work-item-id 3703d3fd-6e3a-4fc2-bc4a-20b2984479b2
```

`farmctl.py work-items --ea QM5_20208` then returned exactly three rows: Q02
`done/PASS`, Q04 `done/PASS_LOWFREQ`, and the new Q05 `pending` row. The
machine-readable handoff is
`artifacts/fx_cointegration_nzdusd_euraud_q05_enqueue_20260822T093212Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA source, EX5, setfile, basket manifest, registry, or magic row
  changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
