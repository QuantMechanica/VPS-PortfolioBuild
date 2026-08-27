# FX cointegration frontier: Q04 pending / hard CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T12:46:45.2364201Z`); 2026-08-27
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `3388595da7a35eee71b2d3c95bda2bef248dbc99`

Status: the reputable-source 66-pair frontier remains fully mechanized; both
anchor baskets are beyond Q02; the existing fixed-risk FX fallback retains one
unclaimed Q04 successor. The host CPU ceiling bound before any card, build,
queue, terminal, or backtest mutation.

## Frontier and anchor decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` is the controlling
OWNER-requested scan. Its published threshold selected only the already-built
`QM5_12533` and `QM5_12532` anchors. The durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships: 66 covered and zero uncovered. Creating a
new scan-derived card or EA would therefore duplicate governed work or relax
the published reputable-source threshold, so the card-extraction and V5 build
gates remained closed.

Neither preferred anchor has a current Q02 infrastructure blocker:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS
  (`e4890d77-b865-4a48-b946-315faefca920`), then Q04 PASS and Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS
  (`76cb11ee-7e9d-4d75-be9d-626c205bca62`), then Q04 FAIL.

The historical `ONINIT` / `NO_HISTORY` failures are resolved and do not justify
another Q02 repair or enqueue.

## Existing-pair fallback

The non-duplicate fallback remains
`QM5_20255_USDCHF_EURJPY_COINTEGRATION_D1`, trading `USDCHF.DWX` and
`EURJPY.DWX` with `USDJPY.DWX` used only for conversion history. Read-only
`farmctl work-items --ea QM5_20255` reconfirmed:

- Q02 `72ca17ca-f9df-40d5-806d-1d815ee4ea08`: PASS.
- Q03 `d50b8721-4691-4ab3-b0b4-14012ecb6f6a`: PASS.
- Q04 `265024c2-9c2c-457e-8696-b22b75b7d722`: pending, unclaimed, attempt 0.

The canonical backtest contract remains `RISK_FIXED=1000` and
`RISK_PERCENT=0`. The existing Q04 row already carries the logical-basket
payload, so no duplicate successor was enqueued and no queue field changed.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-27T12:45:33Z` found six
factory terminals running: T1, T3, T6, T7, T8, and T10. Six matching terminal
reservations were active and there were no orphaned factory terminal
processes. `T_Live` and the unrelated FTMO terminal were observed only to
exclude them from the factory count; neither was controlled.

Five fresh whole-host CPU readings were `100.00%`, `98.73%`, `98.83%`,
`96.71%`, and `96.05%`. Average load was `98.06%` and maximum load was
`100.00%`. The fresh average binds the governed sustained-load
`CPU_MAX_LOAD_PERCENT = 97.0` ceiling in
`tools/strategy_farm/terminal_worker.py`; the peak corroborates saturation.

This is a non-duplicate fleet observation relative to the preceding FX
receipt: T2 released, while T3 and T10 began unrelated Q10_NEWS work, raising
the running factory count from five to six. The FX Q04 successor remains safely
queued. Per the mission stop condition, no compile, smoke, dispatch, tester, or
backtest operation followed the capacity sample.

## Safety and handoff

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry, magic,
  or resolver changed.
- No work-item status, priority, claim, verdict, payload, or queue row changed.
- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- Concurrent unrelated worktree edits were preserved and excluded from this
  receipt commit.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_q04_pending_hard_cpu_stop_20260827T124645Z_board_advisor.json`.
