# FX cointegration frontier: hard CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T03:46:28Z`); 2026-08-27 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `db5716d48d62f9847d106e377d237fec3e61513e`

Status: the frozen 66-pair frontier remains fully mechanized; neither anchor
has a Q02 infrastructure blocker; stopped at the hard CPU ceiling before any
queue, compile, or test mutation

## Frontier and anchor decision

The durable sign-aware audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by the frozen scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`: 66 covered and zero
uncovered. The published scan's only strict survivors are already built as
`QM5_12533` and `QM5_12532`. Creating another scan-derived Strategy Card or EA
would duplicate governed work or relax the reputable-source threshold.

The latest durable anchor evidence remains beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Neither anchor has an `ONINIT` or `NO_HISTORY` Q02 repair to perform.

## Existing-pair fallback

The preceding FX receipt reconciled
`QM5_20232_USDCHF_NZDUSD_COINTEGRATION_D1` at Q02 PASS, Q03 PASS, with its
unique Q04 successor already pending. The capacity stop bound this run before
a fresh work-item query or selection of another fallback could justify a
non-duplicate enqueue. No duplicate Q02, Q03, or Q04 row was added.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-27T03:46:14Z` observed
six governed factory terminals actively testing: T1, T2, T5, T6, T8, and T9.
All ten terminal-worker daemons were alive, six terminal reservations were
active, and no orphaned factory terminal process was reported. `T_Live` and
the unrelated FTMO terminal were observed only to exclude them; neither was
controlled.

Five fresh whole-host CPU readings ending at `2026-08-27T03:46:28Z` were
100%, 100%, 100%, 97.89%, and 99.9%. Their average was 99.56% and their maximum
was 100%. The binding rule applies when either the average or maximum reaches
97%; both measurements triggered the mission's immediate stop condition.

No Card, EA, registry, magic, compile, build check, queue, priority, dispatch,
reservation, terminal, tester, or backtest mutation followed. Machine-readable
evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260827T034628Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt at `2026-08-27T03:01:34Z` observed T1, T2, T5, T6,
T7, T9, and T10: seven active terminals and seven reservations. The current
snapshot dropped T7 and T10, added T8, and contains six active terminals and
six reservations. CPU remains saturated (99.56% average, 100% maximum). This
changed roster is fresh governed capacity evidence, not a repeated queue
insert.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from this
  receipt.
