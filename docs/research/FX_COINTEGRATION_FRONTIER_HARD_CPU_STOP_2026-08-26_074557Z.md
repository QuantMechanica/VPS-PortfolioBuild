# FX cointegration frontier: mixed-load hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T07:45:57Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `55e5a03d2a96fa86dafbe0268775e83e1bb3ca57`

Status: no non-duplicate unbuilt frozen-scan pair; the selected existing FX
basket already has one canonical Q03 successor; stopped at the explicit
backtest CPU ceiling before any card, build, queue, dispatch, or tester action

## Governed pair decision

The bounded OWNER-requested result in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` was read completely. It
admits only two strict scan survivors: `AUDUSD.DWX` / `NZDUSD.DWX` and
`EURJPY.DWX` / `GBPJPY.DWX`. They were already carded as `QM5_12532` and
`QM5_12533`; the source rejects or declines to card its other tested FX,
triangular, and cross-asset forms.

The durable sign-aware audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 frozen relationships: 66 covered and zero uncovered. A
new scan identity would therefore duplicate governed work, while creating a
card outside the two strict survivors would overstate the source result and
fail the reputable-source gate.

The preferred anchors require no Q02 infrastructure repair. Canonical durable
evidence records `QM5_12532` at Q02 PASS and Q04 PASS before Q05 FAIL, and
`QM5_12533` at Q02 PASS before Q04 FAIL. Neither has an ONINIT or NO_HISTORY
Q02 blocker.

## Existing-pair fallback

The latest durable nonterminal continuation remains frozen-scan rank 40,
`USDJPY.DWX` / `NZDUSD.DWX`, implemented as
`QM5_20219_usdjpy-nzdusd`. Its approved, structural D1 fixed-beta card has a
two-leg `basket_manifest.json`, no ML or banned indicator, and a canonical
backtest contract of `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The preceding supported reconciliation records Q02 PASS and exactly one
unique Q03 successor pending. Because the ceiling bound first, no fresh queue
query or mutation was performed. A duplicate enqueue, requeue, or priority
restamp was not valid.

## Binding capacity stop

Five fresh one-second whole-host readings were `90.64%`, `97.90%`, `99.32%`,
`92.77%`, and `87.01%` (average `93.53%`, maximum `99.32%`). The explicit
ceiling binds when either the average or maximum is at least `97%`; the
maximum triggered the stop. Five `metatester64` processes were present at the
end of the sample.

Per the mission stop condition, no Strategy Card or EA was created, no
registry or magic row changed, no compile or build check ran, and no queue,
dispatch, reservation, terminal, or tester action followed. Machine-readable
evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T074557Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt captured a transient clear followed by a `99.77%`
average / `100.00%` maximum confirmation with four tester processes. This
fresh sample has a materially lower mixed-load average, a still-binding
`99.32%` maximum, and five tester processes. It records that changed capacity
state without duplicating a pair or pipeline row.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from
  this receipt.
