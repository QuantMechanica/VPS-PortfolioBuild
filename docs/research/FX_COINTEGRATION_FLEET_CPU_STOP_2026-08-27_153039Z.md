# FX cointegration fleet — rotated-state CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T15:30:39.9025690Z`); 2026-08-27
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `34484b115629c395a311f82c75132e6c42b99686`

Status: the frozen 66-pair frontier remains fully mechanized, both preferred
anchors remain beyond Q02, and the selected existing FX fallback retains one
canonical pending Q04 row. The host CPU ceiling bound before any queue,
worker, terminal, compile, smoke, or backtest mutation.

## Frontier and anchor triage

The durable sign-aware coverage evidence in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
--include-negative-hedges`: 66 covered and zero uncovered. Creating another
scan-derived Card, registry allocation, basket manifest, or EA would duplicate
governed work.

Neither preferred anchor has a current Q02 setup defect:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.

The historical ONINIT and NO_HISTORY attempts are resolved. They do not
authorize another repair or duplicate Q02 enqueue.

## Existing-pair fallback

The concrete fallback is `QM5_20255_USDCHF_EURJPY_COINTEGRATION_D1`, trading
`USDCHF.DWX` and `EURJPY.DWX`. A fresh supported `farmctl work-items --ea
QM5_20255` query returned exactly three canonical rows:

- Q02 `72ca17ca-f9df-40d5-806d-1d815ee4ea08`: PASS.
- Q03 `d50b8721-4691-4ab3-b0b4-14012ecb6f6a`: PASS.
- Q04 `265024c2-9c2c-457e-8696-b22b75b7d722`: pending, unclaimed, attempt 0.

The exact successor already exists, so no duplicate row, priority change,
claim, restamp, or dispatch was made.

## Binding capacity result

Five fresh one-second whole-host CPU readings were `100.000000%`,
`100.000000%`, `100.000000%`, `99.903720%`, and `100.000000%`. Average CPU
was `99.980744%` and maximum CPU was `100.000000%`. Both measures exceed the
governed `CPU_MAX_LOAD_PERCENT = 97.0` tester-admission ceiling in
`tools/strategy_farm/terminal_worker.py`.

The supported `farmctl mt5-slots` snapshot found seven governed factory
terminals actively testing: `T1`, `T2`, `T3`, `T4`, `T6`, `T7`, and `T8`.
Each had a matching reservation, all ten terminal-worker daemons were alive,
and no orphaned factory terminal was reported. `T_Live` and the unrelated
FTMO terminal were observed only to exclude them; neither was controlled.

The farm DB contained eight active rows: one OPT_CENSUS, one Q03, one Q07, one
Q09, and four Q10_NEWS. The Q09 row for `QM5_13036` remained claimed by T5
without a matching process in the point-in-time scan. That observation does
not establish a stale row or authorize reclaim.

Because the explicit ceiling bound, no Q04 advancement, dispatch tick,
compile, smoke, tester, or backtest operation followed the sample.

## Non-duplicate observation delta

The preceding FX receipt at `2026-08-27T14:45:49Z` recorded nine active rows,
including two OPT_CENSUS rows. This snapshot recorded eight active rows and
one OPT_CENSUS row. The census identity rotated to
`50750ca2-4c65-5d38-b7d1-57fa30b2c295` on T4, Q07 is now
`QM5_21501` work item `2f22ea38-4115-4eb5-9d72-ca2887ffccde` on T2, and the
earlier T10 point-in-time mismatch is absent. Average CPU increased from
`99.960990%` to `99.980744%`. This roster and queue-state change is the new
evidence in this handoff; no queue work was duplicated.

## Safety

- No Card, EA, EX5, setfile, basket manifest, registry, magic, or resolver was
  changed.
- No work-item status, priority, claim, verdict, payload, or queue row was
  changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or T_Live manifest
  path was touched.
- No terminal or worker was controlled, and AutoTrading was not toggled.
- Concurrent unrelated QM5_41184 worktree changes were left unstaged and
  untouched.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_cpu_stop_20260827T153039Z_board_advisor.json`.
