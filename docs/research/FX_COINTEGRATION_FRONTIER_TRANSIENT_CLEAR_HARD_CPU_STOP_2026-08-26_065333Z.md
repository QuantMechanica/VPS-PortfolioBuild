# FX cointegration frontier: transient capacity clear / hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T06:53:33Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `f4b187ee7f0f70442fca95a7fe1c2c3b526684e1`

Status: no non-duplicate unbuilt scan pair; the selected existing FX basket
remains queued exactly once at Q03; stopped when the explicit backtest CPU
ceiling rebound before any queue or tester mutation

## Frontier and anchor result

The bounded result in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` admitted only the two
original strict survivors. The durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships: 66 covered and zero uncovered. A fresh
scan-derived identity would therefore duplicate governed work or weaken the
reputable-source boundary.

The preferred anchors remain beyond Q02 in the latest canonical durable
evidence: `QM5_12532` reached Q02 PASS and Q04 PASS before Q05 FAIL;
`QM5_12533` reached Q02 PASS before Q04 FAIL. Neither has an ONINIT or
NO_HISTORY Q02 repair to perform.

## Concrete existing-pair continuation

The selected nonterminal fallback remains frozen-scan rank 40,
`USDJPY.DWX` / `NZDUSD.DWX`, implemented as
`QM5_20219_usdjpy-nzdusd`. Its approved card uses the OWNER-ratified Tier-A
Ernest Chan pair-trading method plus the frozen in-house scan. The strategy is
fixed-beta, structural, D1, low-frequency, and contains no ML or banned
indicator. Its package contains `basket_manifest.json`; its logical backtest
setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

A fresh supported work-item query returned exactly three rows:

- Q02 `5eb61981-472e-4f08-82c0-53fbec77d6c8`: DONE / PASS.
- Q03 `4514a6c7-0a2e-4523-a756-b63a232dd8aa`: PENDING, unclaimed,
  zero attempts, v4, and `priority_track=true`.
- Q04 `b721ce82-2d53-46db-b2d0-f20b561a1513`: PENDING, unclaimed,
  zero attempts.

The canonical pending selector placed the Q03 row at rank 39 of 3,558
claimable rows. It has no active hold and is not superseded. Its expected
MQ5, EX5, and fixed-risk setfile hashes still match the sealed row. Q03 is not
an autonomous phase authorized by `run_phase.ps1`; it must remain with the
canonical farm queue. No duplicate enqueue, requeue, priority restamp, or
manual runner was valid.

## Capacity transition and binding stop

The first five one-second whole-host CPU readings were `78.05%`, `76.98%`,
`88.57%`, `71.10%`, and `78.23%` (average `78.59%`, maximum `88.57%`). A
supported MT5 census at `2026-08-26T06:47:28Z` observed four governed factory
terminals actively testing: T3, T5, T6, and T8. Ten terminal-worker daemons
were present, four terminal reservations were active, and no orphaned factory
terminal process was reported.

During that transient clear window, the already-running governed workers
independently claimed and completed additional compile rows. A required
confirmation sample then read `99.81%`, `100.00%`, `99.52%`, `99.81%`, and
`99.71%` (average `99.77%`, maximum `100.00%`). The explicit ceiling binds
when either average or maximum is at least `97%`; both measures triggered the
stop.

Per the mission stop condition, no card or EA creation, compile/build check,
queue mutation, dispatch tick, tester launch, terminal reservation or
control, or backtest followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_transient_clear_hard_cpu_stop_20260826T065333Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt at `2026-08-26T06:01:02Z` recorded five readings at
100%. This run records a materially different transient clear followed by a
fresh saturation rebound, plus the current exact queue rank and hash-bound
state of the selected Q03 row. It does not duplicate a pair or pipeline work
item.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from
  this receipt.
