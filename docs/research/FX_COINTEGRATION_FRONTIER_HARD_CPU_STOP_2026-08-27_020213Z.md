# FX cointegration frontier: changed fleet state / hard CPU stop

Date: 2026-08-27 UTC (`2026-08-27T02:02:13Z`); 2026-08-27 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `63275601d02a20c1629e0b0fe4d1f4ffdc881182`

Status: the frozen 66-pair frontier remains fully mechanized; neither anchor
has a Q02 infrastructure blocker; the selected existing FX basket already has
its unique Q04 successor pending; stopped at the explicit hard CPU ceiling

## Frontier and anchor decision

The durable sign-aware audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by the frozen scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`: 66 covered and zero
uncovered. The published scan's only strict survivors are already built as
`QM5_12533` and `QM5_12532`. Creating another scan-derived Strategy Card or EA
would duplicate governed work or relax the reputable-source threshold.

The latest canonical anchor evidence remains beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Neither anchor has an `ONINIT` or `NO_HISTORY` Q02 repair to perform.

## Concrete existing-pair fallback

`QM5_20232_USDCHF_NZDUSD_COINTEGRATION_D1` remains the concrete existing
low-frequency fallback. A fresh supported `farmctl work-items --ea` query
found its Q02 row `ca72ac7d-162c-4c54-b2e4-d7765c15efeb` done/PASS and its Q03
row `73d11c4c-0542-4828-9631-1954799a87a5` done/PASS. Its sole Q04 successor
`bfad4436-ae19-4b7d-a7cf-1c02a0324d67` is already pending. Another Q02, Q03,
or Q04 enqueue would be duplicate work.

The unchanged build is structural, fixed-beta, learned-model-free, and D1. It
has an APPROVED Tier-A-source card, a `basket_manifest.json`, and a logical
backtest setfile with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-27T02:01:14Z` observed
three governed factory terminals actively testing: T1, T6, and T10. All ten
terminal-worker daemons were alive, three terminal reservations were active,
and no orphaned factory terminal process was reported. The paced launch gate
remained `1`. `T_Live` and the unrelated FTMO terminal were observed only to
exclude them; neither was controlled.

Five fresh whole-host CPU readings ending at `2026-08-27T02:02:13Z` were
99.61%, 97.33%, 98.54%, 95.51%, and 98.83%. Their average was 97.96% and their
maximum was 99.61%. The binding rule applies when either the average or maximum
reaches 97%; both measurements therefore triggered the mission's immediate
stop condition.

No Card, EA, registry, magic, compile, build check, queue, priority, dispatch,
reservation, terminal, tester, or backtest mutation followed. Machine-readable
evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260827T020213Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt at `2026-08-27T01:17:32Z` observed T1, T6, and T7,
five active reservations, 96.07% average CPU, and a 97.07% maximum. This
receipt records the changed roster T1, T6, and T10, three active reservations,
97.96% average CPU, and a 99.61% maximum. It is changed governed capacity
evidence, not a repeated queue insert.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from this
  receipt.
