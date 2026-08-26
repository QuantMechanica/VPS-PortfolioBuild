# FX cointegration frontier: changed cohort / hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T14:01:07Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `916c484799b9fcc160a016ff6d74825fe36295b4`

Status: no reputable, non-duplicate unbuilt frozen-scan pair; the last durable
anchor and fallback lineage is already beyond Q02; stopped at the explicit
backtest CPU ceiling

## Governed pair decision

The bounded OWNER-requested source
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` was read completely. Its
66-pair scan admits only `AUDUSD.DWX` / `NZDUSD.DWX` and `EURJPY.DWX` /
`GBPJPY.DWX` under the stated reputable-source criteria. Both already have
approved cards and built basket EAs as `QM5_12532` and `QM5_12533`. The durable
sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 frozen relationships, with zero uncovered. A new
scan-derived identity would duplicate governed work or promote a row that
failed the admitted evidence bar.

## Anchor and fallback reconciliation

Fresh supported `farmctl work-items` queries were attempted for `QM5_12532`,
`QM5_12533`, and the existing-pair fallback `QM5_20219_usdjpy-nzdusd`. Each
read stopped in `init_db` with `sqlite3.OperationalError: database is locked`;
no database mutation was performed.

The most recent durable canonical receipt remains
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T131637Z_board_advisor.json`:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS before Q05
  FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS before Q04 FAIL.
- `QM5_20219_usdjpy-nzdusd` has Q02 PASS and already owns a single pending Q03
  successor.

The live database lock does not authorize a duplicate repair or successor.
No card, EA, queue row, priority, dispatch, or terminal state was changed.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-26T14:00:41Z` observed
six governed factory terminals actively testing: T1, T2, T6, T7, T8, and T9.
Ten terminal-worker daemons were alive, six reservations were active, and no
orphaned factory terminal process was reported. `T_Live` and the unrelated
FTMO terminal were observed only to exclude them; neither was controlled. The
paced launch gate remained `1`.

Five fresh one-second whole-host CPU readings were all `100.00%`. Their average
and maximum were therefore both `100.00%`. The explicit ceiling binds when
either the average or maximum is at least `97%`; both measures triggered the
stop.

Per the mission stop condition, no card or EA creation, registry or magic
mutation, compile, build check, queue mutation, dispatch tick, tester launch,
terminal reservation, terminal control, or backtest followed. Machine-readable
evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T140107Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt observed seven factory terminals (T1, T2, T4, T5,
T7, T8, and T9). This receipt records a changed six-terminal cohort: T6 is
newly active while T4 and T5 are no longer active. It also records a flat
100-percent CPU sample, up from the prior 99.52-percent average, and the fresh
canonical lineage read lock. It does not duplicate a pair, card, EA, or queue
item.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from this
  receipt.
