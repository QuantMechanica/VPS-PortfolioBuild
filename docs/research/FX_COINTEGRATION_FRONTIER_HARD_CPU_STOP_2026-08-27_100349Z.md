# FX cointegration frontier: active fallback / hard CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T10:03:49.9145627Z`); 2026-08-27
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `fbcdbc0632780255e451a430a05ceb17e81dc7d8`

Status: the reputable-source 66-pair frontier remains fully mechanized; both
anchor baskets are beyond Q02; an existing fixed-risk FX basket is actively
advancing at Q03; stopped before any card, build, queue, worker, or backtest
mutation because the explicit CPU ceiling is binding

## Frontier and build decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` is the controlling
OWNER-requested scan. It hard-selected only two of 66 relationships:

- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`
- `QM5_12532_AUDNZD_COINTEGRATION_D1`

The durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships, with 66 covered and zero uncovered. A new
card or EA from this frozen scan would therefore duplicate governed work or
relax the reputable-source threshold. The card-extraction gate was not opened,
and the build preflight was not entered.

The anchors have resolved Q02 evidence rather than a current `ONINIT` or
`NO_HISTORY` blocker:

- `QM5_12532`: Q02 PASS (`e4890d77-b865-4a48-b946-315faefca920`), then Q04
  PASS and Q05 FAIL.
- `QM5_12533`: Q02 PASS (`76cb11ee-7e9d-4d75-be9d-626c205bca62`), then Q04
  FAIL.

## Existing-pair fallback

The governed fallback has advanced to the already-built
`QM5_20255_USDCHF_EURJPY_COINTEGRATION_D1`. Its basket manifest trades
`USDCHF.DWX` and `EURJPY.DWX`; `USDJPY.DWX` is conversion history only. Q02
passed under work item `72ca17ca-f9df-40d5-806d-1d815ee4ea08`.

Q03 work item `d50b8721-4691-4ab3-b0b4-14012ecb6f6a` is active on T10 with
canonical `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the basket manifest bound in
its payload. The supported slot snapshot at `2026-08-27T10:01:42Z` showed the
matching T10 terminal process and reservation, so no duplicate enqueue or
reclaim was performed.

This is a fresh coordination state relative to the preceding FX receipt:
`QM5_20250` on T9 has cleared, `QM5_20255` is now running on T10, and the live
factory topology is T2, T3, T6, T8, and T10. The immediately preceding
diversity receipt had identified the Q03 row before its T10 process or
reservation was visible; both are visible now.

## Binding capacity stop

Five fresh whole-host CPU readings, sampled two seconds apart, were `99%`,
`100%`, `100%`, `100%`, and `100%`. Average load was `99.8%` and maximum load
was `100%`. Both exceed the governed `CPU_MAX_LOAD_PERCENT = 97.0` admission
ceiling in `tools/strategy_farm/terminal_worker.py`.

The slot snapshot reported five running factory terminals and six active
terminal reservations, with no orphaned factory process. `T_Live` and the
unrelated FTMO terminal were observed only to exclude them from the factory
count; neither was controlled. Per the mission stop condition, no compile,
smoke, dispatch, tester, or backtest operation followed the capacity sample.

## Stop disposition and safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry, magic,
  or resolver changed.
- No Q02 or later-phase row, priority, claim, verdict, reservation, worker, or
  terminal state changed.
- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, or AutoTrading state changed.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260827T100349Z_board_advisor.json`.
