# FX cointegration frontier: recovered lineage / hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T15:46:21Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `4a224d35d24a3f5bd6fcd8192018a603f12833da`

Status: no reputable, non-duplicate unbuilt frozen-scan pair; the selected
existing FX fallback already has canonical successors; stopped at the explicit
backtest CPU ceiling

## Governed pair decision

The bounded OWNER-requested source
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` was read completely. Its
66-pair scan admits only `AUDUSD.DWX` / `NZDUSD.DWX` and `EURJPY.DWX` /
`GBPJPY.DWX` under the stated reputable-source criteria. Both already have
approved cards and built basket EAs as `QM5_12532` and `QM5_12533`. The durable
sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 frozen relationships, with zero uncovered. Creating a new
scan-derived identity would duplicate governed work or promote a row that did
not meet the source's admission bar.

## Anchor and fallback reconciliation

Fresh supported `farmctl work-items` reads succeeded for both anchors and the
selected existing-pair fallback:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` remains Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` remains Q02 PASS, Q04 FAIL.
- `QM5_20219_USDJPY_NZDUSD_COINTEGRATION_D1` has Q02 PASS plus an existing
  pending Q03 row (`4514a6c7-0a2e-4523-a756-b63a232dd8aa`) and an older pending
  Q04 row (`b721ce82-2d53-46db-b2d0-f20b561a1513`).

The recovered read is a material change from the preceding receipt, whose
canonical query was database-locked and therefore recorded only the last
durable Q03 successor. No successor, repair, priority change, or dispatch was
inserted: both next-phase rows already exist, and another would be duplicate
work. Their out-of-order pending state is recorded without queue mutation
because the CPU ceiling binds.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-26T15:45:54Z` observed
four governed factory terminals actively testing: T2, T5, T7, and T9. Ten
terminal-worker daemons were alive, five reservations were active, and no
orphaned factory terminal process was reported. `T_Live` and the unrelated
FTMO terminal were observed only to exclude them; neither was controlled. The
paced launch gate remained `1`.

Five fresh one-second whole-host CPU readings were `99.12%`, `99.90%`,
`94.63%`, `90.95%`, and `88.22%`. Their average was `94.56%` and their maximum
was `99.90%`. The explicit ceiling binds when either measure is at least 97%;
the maximum therefore triggered the stop.

Per the mission stop condition, no card or EA creation, registry or magic
mutation, compile, build check, queue mutation, dispatch tick, tester launch,
terminal reservation, terminal control, or backtest followed. Machine-readable
evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T154621Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt observed T1, T2, T6, T7, T8, and T9. This receipt
records a changed four-terminal cohort: T5 is newly active while T1, T6, and
T8 are no longer active. It also records recovered canonical reads and the
previously obscured pending Q04 fallback row. This does not duplicate a pair,
card, EA, or queue item.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from this
  receipt.
