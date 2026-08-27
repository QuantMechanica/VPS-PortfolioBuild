# FX cointegration frontier: Q04 pending / hard CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T11:46:05.1596433Z`); 2026-08-27
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `ba12ba0c525a29940954d0aba37d23bb2e4a22e1`

Status: the reputable-source 66-pair frontier remains fully mechanized; both
anchor baskets are beyond Q02; the existing fixed-risk FX fallback retains an
unclaimed Q04 successor; stopped before card, build, queue, terminal, or
backtest mutation because the explicit CPU ceiling is binding

## Frontier and anchor decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` is the controlling
OWNER-requested scan. Its published threshold selected only the already-built
`QM5_12533` and `QM5_12532` anchors. The durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships, with 66 covered and zero uncovered. A new
scan-derived card or EA would duplicate governed work or relax the published
reputable-source threshold, so neither the card-extraction gate nor the V5
build preflight was opened.

Neither preferred anchor has a current Q02 infrastructure blocker:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS
  (`e4890d77-b865-4a48-b946-315faefca920`), then Q04 PASS and Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS
  (`76cb11ee-7e9d-4d75-be9d-626c205bca62`), then Q04 FAIL.

The historical `ONINIT` / `NO_HISTORY` attempts are therefore resolved rather
than candidates for another Q02 repair.

## Existing-pair fallback

The governed fallback remains
`QM5_20255_USDCHF_EURJPY_COINTEGRATION_D1`, which trades `USDCHF.DWX` and
`EURJPY.DWX`; `USDJPY.DWX` supplies conversion history only. Q02 work item
`72ca17ca-f9df-40d5-806d-1d815ee4ea08` and Q03 work item
`d50b8721-4691-4ab3-b0b4-14012ecb6f6a` both passed. Its canonical backtest
contract remains `RISK_FIXED=1000` and `RISK_PERCENT=0`.

The pre-existing Q04 successor `265024c2-9c2c-457e-8696-b22b75b7d722` is
still pending, unclaimed, and at attempt zero. It already carries the basket
manifest and logical-symbol payload, so another enqueue would be duplicate
work. No priority, status, payload, verdict, claim, or queue row changed.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-27T11:45:53Z` found
five factory terminals running: T1, T2, T6, T7, and T8. Five matching terminal
reservations were active, with no orphaned factory terminal process. `T_Live`
and the unrelated FTMO terminal were observed only to exclude them from the
factory count; neither was controlled.

Five fresh whole-host CPU readings, sampled two seconds apart, were `94.66%`,
`96.88%`, `86.09%`, `98.74%`, and `99.95%`. Average load was `95.26%` and
maximum load was `99.95%`. The maximum binds the governed
`CPU_MAX_LOAD_PERCENT = 97.0` ceiling in
`tools/strategy_farm/terminal_worker.py`.

This is a fresh coordination snapshot relative to the preceding FX receipt:
T3 released and T1 began unrelated Q07 work. The FX fallback remains safely
queued at Q04, but the CPU admission condition still forbids a new launch.
Per the mission stop condition, no compile, smoke, dispatch, tester, or
backtest operation followed the capacity sample.

## Safety and handoff

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry, magic,
  or resolver changed.
- No work-item status, priority, claim, verdict, payload, or queue row changed.
- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_q04_pending_hard_cpu_stop_20260827T114605Z_board_advisor.json`.
