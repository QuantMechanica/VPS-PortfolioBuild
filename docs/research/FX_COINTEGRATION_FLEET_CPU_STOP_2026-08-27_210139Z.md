# FX cointegration fleet — hard CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T21:01:39Z`); 2026-08-27
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `b2ad122644a21102d9997bd5ecc4c5d7e40eba56`

Status: the reputable-source 66-pair frontier has no eligible unbuilt sleeve,
both preferred anchors remain beyond Q02, and the selected existing FX
fallback retains one exact pending Q04 successor. The explicit host CPU
ceiling bound before any queue, worker, terminal, compile, smoke, or backtest
mutation.

## Frontier and anchor triage

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` is the controlling
OWNER-requested scan. Its published acceptance threshold selected only two of
66 relationships: `QM5_12532` and `QM5_12533`. Both are already built. The
durable sign-aware audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships, with 66 covered and zero uncovered. A new
scan-derived Card or EA would duplicate governed coverage or relax the
published reputable-source criterion.

Neither preferred anchor has a current Q02 setup defect:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, then Q04 PASS and Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The historical ONINIT and NO_HISTORY attempts are resolved, so neither anchor
was requeued or modified.

## Existing-pair fallback

The concrete fallback remains `QM5_20255_USDCHF_EURJPY_COINTEGRATION_D1` in
`framework/EAs/QM5_20255_usdchf-eurjpy`. Its manifest trades `USDCHF.DWX` and
`EURJPY.DWX`; `USDJPY.DWX` supplies conversion history only. A fresh supported
`farmctl work-items --ea QM5_20255` query returned exactly three rows:

- Q02 `72ca17ca-f9df-40d5-806d-1d815ee4ea08`: PASS.
- Q03 `d50b8721-4691-4ab3-b0b4-14012ecb6f6a`: PASS.
- Q04 `265024c2-9c2c-457e-8696-b22b75b7d722`: pending, unclaimed, attempt 0.

Both canonical backtest setfiles remain worktree-clean and sealed at
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The exact Q04
successor already exists, so no duplicate enqueue, priority change, claim,
restamp, or direct phase run was performed.

## Binding capacity result

Five fresh one-second whole-host CPU readings were all `100.000000%`. Average
CPU and maximum CPU were both `100.000000%`, above the governed
`CPU_MAX_LOAD_PERCENT = 97.0` tester-admission ceiling in
`tools/strategy_farm/terminal_worker.py`.

The supported `farmctl mt5-slots` snapshot found six governed factory
terminals actively testing: `T1`, `T2`, `T6`, `T7`, `T8`, and `T10`. Each had
a matching reservation, all ten terminal-worker daemons were alive, and no
orphaned factory terminal was reported. `T_Live` and the unrelated FTMO
terminal were observed only to exclude them; neither was controlled.

The farm DB contained eight active rows: two OPT_CENSUS, one Q03, one Q07, one
Q09, and three Q10_NEWS. The Q09 row claimed by T5 and one newly active
OPT_CENSUS row claimed by T9 had no matching process in the point-in-time slot
snapshot; that observation does not establish stale work or authorize
reclaim.

Because the explicit CPU ceiling bound, the mission's stop condition applied
and no Q04 advancement or tester operation followed the sample.

## Non-duplicate observation delta

The preceding FX receipt at `2026-08-27T19:31:02Z` recorded seven active rows
with no OPT_CENSUS and four Q10_NEWS rows. This snapshot recorded eight active
rows after two OPT_CENSUS rows appeared and Q10_NEWS decreased to three. The
running factory count remained six, but T3 left the roster and T6 joined. All
five CPU samples remained saturated at `100.000000%`. This changed phase mix
and terminal roster is the new evidence in this receipt; no strategy or queue
work was duplicated.

## Safety

- No Card, EA, EX5, setfile, basket manifest, registry, magic, or resolver was
  changed.
- No work-item status, priority, claim, verdict, payload, or queue row was
  changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or T_Live manifest
  path was touched.
- No terminal or worker was controlled, and AutoTrading was not toggled.
- Concurrent repository edits were left unstaged and untouched.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_cpu_stop_20260827T210139Z_board_advisor.json`.
