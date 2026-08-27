# FX cointegration frontier: Q03 PASS / hard CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T11:03:05.4988694Z`); 2026-08-27
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `8bdfadeaa274ed03aa0fcc33bb6d58538f740b16`

Status: the reputable-source 66-pair frontier remains fully mechanized; both
anchor baskets are beyond Q02; the existing fixed-risk FX fallback completed
Q03 PASS and already has a Q04 successor; stopped before queue or backtest
mutation because the explicit CPU ceiling is binding

## Frontier and anchor decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` is the controlling
OWNER-requested scan. Its published threshold selected only the already-built
`QM5_12533` and `QM5_12532` anchors. The durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships, with 66 covered and zero uncovered. A new
scan-derived card or EA would therefore duplicate governed work or relax the
reputable-source threshold.

Current canonical work-item queries also confirm that neither anchor needs the
preferred Q02 repair path:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS
  (`e4890d77-b865-4a48-b946-315faefca920`), then Q04 PASS and Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS
  (`76cb11ee-7e9d-4d75-be9d-626c205bca62`), then Q04 FAIL.

The historical failed and infrastructure attempts remain in the ledger, but
the later logical-basket PASS rows resolve the `ONINIT` / `NO_HISTORY` triage.
No card-extraction or build preflight gate was opened.

## Existing-pair fallback advanced

The governed fallback `QM5_20255_USDCHF_EURJPY_COINTEGRATION_D1` completed its
deterministic Q03 work item `d50b8721-4691-4ab3-b0b4-14012ecb6f6a` with PASS
at `2026-08-27T10:08:22Z`. Both runs were OK and identical: 122 trades,
profit factor 0.60, and 9.77% drawdown. Q03 is the reproducibility gate; these
adverse economics remain for Q04 to judge and were not reinterpreted as edge.

The basket trades `USDCHF.DWX` and `EURJPY.DWX`; `USDJPY.DWX` is declared only
for conversion history. Its canonical backtest setfile remains sealed at
`RISK_FIXED=1000` and `RISK_PERCENT=0`. Existing Q04 work item
`265024c2-9c2c-457e-8696-b22b75b7d722` is pending, so no duplicate enqueue or
priority mutation was made.

This is a material change from the preceding FX receipt, which observed Q03
active on T10. The fallback is now Q03-cleared and T10 has been released.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-27T11:01:33Z` found
five factory terminals running: T2, T3, T6, T7, and T8. Five matching terminal
reservations were active, and no orphaned factory terminal process was found.
`T_Live` and the unrelated FTMO terminal were observed only to exclude them;
neither was controlled.

Five fresh whole-host CPU readings, sampled two seconds apart, were `99%`,
`97%`, `100%`, `100%`, and `99%`. Average load was `99%` and maximum load was
`100%`, both binding the governed `CPU_MAX_LOAD_PERCENT = 97.0` ceiling in
`tools/strategy_farm/terminal_worker.py`.

Per the mission stop condition, no compile, smoke, dispatch, tester, queue,
reservation, worker, terminal, or backtest mutation followed the capacity
sample. The already-pending Q04 row was left for the paced fleet.

## Safety and handoff

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry, magic,
  or resolver changed.
- No work-item status, priority, claim, verdict, or queue row changed.
- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_q03_pass_hard_cpu_stop_20260827T110233Z_board_advisor.json`.
