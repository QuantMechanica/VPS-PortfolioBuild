# FX cointegration fleet — rotated hard CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T23:32:21.1720482Z`); 2026-08-28
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `dc1dac060ccba14ad5d88a9bb2432cacdcdcf38a`

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
restamp, dispatch tick, or direct phase run was performed.

## Binding capacity result

Five fresh one-second whole-host CPU readings were `99.804906%`, `99.810496%`,
`94.930048%`, `91.415780%`, and `99.036108%`. Average CPU was `96.999468%`,
just below the governed `CPU_MAX_LOAD_PERCENT = 97.0` threshold, but maximum
CPU was `99.810496%`. The tester-admission rule in
`tools/strategy_farm/terminal_worker.py` binds when either the average or the
maximum reaches the ceiling, so the maximum was decisive.

The supported `farmctl mt5-slots` snapshot found four governed factory
terminals actively testing: `T1`, `T3`, `T6`, and `T10`. Each had a matching
reservation, all ten terminal-worker daemons were alive, and no orphaned
factory terminal was reported. The paced launch gate in
`D:/QM/strategy_farm/state/launch_gate_max.txt` is `1`, so four running
factory terminals also exceeded available launch capacity. `T_Live` and the
unrelated FTMO terminal were observed only to exclude them; neither was
controlled.

The supported active-work-item query returned seven rows: two OPT_CENSUS, one
Q03, one Q09, and three Q10_NEWS. Three active rows claimed by T5, T8, and T9
had no matching process in the point-in-time slot snapshot; that observation
does not establish stale work or authorize reclaim.

Because the explicit CPU ceiling bound, the mission's stop condition applied
and no FX Q04 advancement or tester operation followed the sample.

## Non-duplicate observation delta

The preceding FX receipt at `2026-08-27T22:46:05Z` recorded seven active rows
with one OPT_CENSUS, one Q02, one Q09, and four Q10_NEWS. This snapshot still
recorded seven rows, but Q02 left the active set, Q03 entered, OPT_CENSUS
increased to two, and Q10_NEWS decreased to three. The process roster rotated
from `T1`, `T3`, `T4`, and `T10` to `T1`, `T3`, `T6`, and `T10`. Average CPU
moved from `99.962001%` to `96.999468%`, while the maximum moved from
`100.000000%` to `99.810496%` and remained above the ceiling. This changed
phase mix, terminal roster, and CPU sample is the new evidence in this
receipt.

## Safety

- No Card, EA, EX5, setfile, basket manifest, registry, magic, or resolver was
  changed.
- No work-item status, priority, claim, verdict, payload, or queue row was
  changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or T_Live manifest
  path was touched.
- No terminal or worker was controlled, and AutoTrading was not toggled.
- Concurrent unrelated worktree changes were left unstaged and untouched.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_cpu_stop_20260827T233221Z_board_advisor.json`.
