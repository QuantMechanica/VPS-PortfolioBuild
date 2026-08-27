# FX cointegration frontier: Q04 pending / hard CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T13:45:49.0293959Z`); 2026-08-27
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `6ae6f618cb7fb78e75273e6e19832925e94334a3`

Status: the reputable-source 66-pair frontier remains fully mechanized; both
anchor baskets are beyond Q02; the existing fixed-risk FX fallback still has
one pending Q04 successor. The host CPU ceiling bound before any card, build,
queue, worker, terminal, or backtest mutation.

## Frontier and anchor decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` is the controlling
OWNER-requested scan. Its published threshold selected only the already-built
`QM5_12533` and `QM5_12532` anchors. The durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships: 66 covered and zero uncovered. A new
scan-derived card or EA would duplicate governed work or relax the published
reputable-source threshold, so the card-extraction and V5 build gates remained
closed.

Fresh canonical work-item queries confirm that neither preferred anchor has a
current Q02 infrastructure blocker:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS
  (`e4890d77-b865-4a48-b946-315faefca920`), then Q04 PASS and Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS
  (`76cb11ee-7e9d-4d75-be9d-626c205bca62`), then Q04 FAIL.

The historical `ONINIT` / `NO_HISTORY` attempts are resolved and do not
authorize another repair or duplicate Q02 enqueue.

## Existing-pair fallback

The one concrete non-duplicate fallback remains
`QM5_20255_USDCHF_EURJPY_COINTEGRATION_D1`. Its basket trades `USDCHF.DWX`
and `EURJPY.DWX`; `USDJPY.DWX` supplies conversion history only. Read-only
`farmctl work-items --ea QM5_20255` returned exactly three canonical rows:

- Q02 `72ca17ca-f9df-40d5-806d-1d815ee4ea08`: PASS.
- Q03 `d50b8721-4691-4ab3-b0b4-14012ecb6f6a`: PASS.
- Q04 `265024c2-9c2c-457e-8696-b22b75b7d722`: pending, unclaimed, attempt 0.

The backtest setfile remains sealed at `RISK_FIXED=1000` and
`RISK_PERCENT=0`. The existing Q04 row already carries the logical-basket
payload, so no duplicate successor or priority mutation was made. Q04 also
falls outside the autonomous phases permitted by the `qm-run-pipeline-phase`
skill; no direct `run_phase.ps1` invocation was authorized.

## Binding capacity result

Five fresh one-second whole-host CPU readings were `99.8062%`, `100.0000%`,
`98.9286%`, `99.8053%`, and `96.0946%`. Their average was `98.9269%` and
their maximum was `100.0000%`. Both measures meet or exceed the governed
`CPU_MAX_LOAD_PERCENT = 97.0` tester-admission ceiling in
`tools/strategy_farm/terminal_worker.py`.

The supported `farmctl mt5-slots` snapshot at `2026-08-27T13:45:44Z` found
four running factory terminals: T2, T6, T7, and T10, each with a matching
reservation and no orphaned factory terminal process. `T_Live` and the
unrelated FTMO terminal were observed only to exclude them from the factory
count; neither was controlled.

The database view one minute later contained nine active rows: one
OPT_CENSUS, one Q03, one Q07, one Q09, four Q10_NEWS, and one Q11. This is a
materially fresh fleet state relative to the 13:30Z diversity receipt: the
active count rose from eight to nine, Q11 for `QM5_35005` appeared, and the
visible running-terminal set changed from T1/T2/T3/T6/T7/T8 to T2/T6/T7/T10.
The point-in-time process/database differences are observations, not stale-row
verdicts or authority to reclaim work.

Because the explicit capacity condition bound, no dispatch tick, compile,
smoke, tester, or backtest operation followed the sample.

## Safety and handoff

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry, magic,
  or resolver changed.
- No work-item status, priority, payload, claim, verdict, or queue row changed.
- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, or AutoTrading state changed.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_q04_pending_hard_cpu_stop_20260827T134549Z_board_advisor.json`.
