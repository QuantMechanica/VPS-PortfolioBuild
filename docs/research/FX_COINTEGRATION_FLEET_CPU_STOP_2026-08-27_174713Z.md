# FX cointegration fleet — hard CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T17:47:13Z`); 2026-08-27
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `78e9d5992d7886329bffc5b43e2094ab1444db63`

Status: the frozen 66-pair frontier remains fully mechanized, both preferred
anchors remain beyond Q02, and the selected existing FX fallback retains one
canonical pending Q04 row. The explicit host CPU ceiling bound before any
queue, worker, terminal, compile, smoke, or backtest mutation.

## Frontier and anchor triage

The durable sign-aware coverage evidence in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
--include-negative-hedges`: 66 covered and zero uncovered. A fresh comparison
of OWNER-approved forex cointegration cards against EA source and EX5 outputs
also found zero missing builds. Creating another scan-derived Card, registry
allocation, basket manifest, or EA would duplicate governed work.

Neither preferred anchor has a current Q02 setup defect:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.

The historical ONINIT and NO_HISTORY attempts are resolved. They do not
authorize another repair or duplicate Q02 enqueue.

## Existing-pair fallback

The concrete fallback remains `QM5_20255_USDCHF_EURJPY_COINTEGRATION_D1`,
trading `USDCHF.DWX` and `EURJPY.DWX`. A fresh supported `farmctl work-items
--ea QM5_20255` query returned exactly three canonical rows:

- Q02 `72ca17ca-f9df-40d5-806d-1d815ee4ea08`: PASS.
- Q03 `d50b8721-4691-4ab3-b0b4-14012ecb6f6a`: PASS.
- Q04 `265024c2-9c2c-457e-8696-b22b75b7d722`: pending, unclaimed, attempt 0.

The exact successor already exists, so no duplicate row, priority change,
claim, restamp, or dispatch was made.

## Binding capacity result

Five fresh one-second whole-host CPU readings were `100.000000%`,
`100.000000%`, `100.000000%`, `99.902643%`, and `99.121181%`. Average CPU was
`99.804765%` and maximum CPU was `100.000000%`. Both measures exceed the
governed `CPU_MAX_LOAD_PERCENT = 97.0` tester-admission ceiling in
`tools/strategy_farm/terminal_worker.py`.

The supported `farmctl mt5-slots` snapshot found six governed factory
terminals actively testing: `T1`, `T2`, `T3`, `T4`, `T6`, and `T10`. Each had
a matching reservation, all ten terminal-worker daemons were alive, and no
orphaned factory terminal was reported. `T_Live` and the unrelated FTMO
terminal were observed only to exclude them; neither was controlled.

The farm DB contained nine active rows: one OPT_CENSUS, one Q03, one Q07, two
Q09, and four Q10_NEWS. Three claimed rows had no matching factory terminal
process in the point-in-time slot snapshot. That observation does not
establish stale work or authorize reclaim.

Because the explicit ceiling bound, no Q04 advancement, dispatch tick,
compile, smoke, tester, or backtest operation followed the sample.

## Non-duplicate observation delta

The preceding FX receipt at `2026-08-27T16:46:02Z` recorded eight active rows
and three running factory terminals. This snapshot recorded nine active rows
and six running terminals. OPT_CENSUS decreased from two rows to one, Q03
appeared, and Q09 increased from one row to two. Average CPU rose from
`97.509463%` to `99.804765%`; the maximum remained `100.000000%`. This changed
phase mix, terminal roster, and capacity state is the new evidence in this
handoff; no strategy or queue work was duplicated.

## Safety

- No Card, EA, EX5, setfile, basket manifest, registry, magic, or resolver was
  changed.
- No work-item status, priority, claim, verdict, payload, or queue row was
  changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or T_Live manifest
  path was touched.
- No terminal or worker was controlled, and AutoTrading was not toggled.
- Concurrent repository work was left unstaged and untouched.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_cpu_stop_20260827T174713Z_board_advisor.json`.
