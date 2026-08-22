# FX cointegration QM5_20208 Q05 stall hard CPU stop

Date: 2026-08-22 UTC (`2026-08-22T17:32:47Z`)

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; completed Q05 artifact still not
reconciled to the canonical work item; stopped at the explicit backtest CPU
ceiling

## Outcome

No new FX Strategy Card or EA was created. The durable sign-aware
reconciliation in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from `analyze_cross_asset_v3.py
--include-negative-hedges`, so another scan-derived identity would be
duplicate work.

The preferred anchors do not need Q02 repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.

## Existing-pair fallback

The rank-27 `NZDUSD.DWX` / `EURAUD.DWX` basket
`QM5_20208_nzdusd-euraud` remains the strongest non-duplicate fallback. Its
Q02 verdict is PASS and its Q04 verdict is PASS_LOWFREQ. Exactly one Q05 row
exists: `1a53b4bd-abbd-4c6e-a13a-5f1a1542bf8d`.

The Q05 aggregate completed at `2026-08-22T10:47:24Z` and reports PASS, but a
fresh canonical read still showed the work item as `active`, claimed by T1,
with no verdict or evidence path. The row's last update remains
`2026-08-22T10:20:45Z`. The aggregate SHA-256 is
`9ccde341daf4dac3efc32e623b58fcbefe31d08b47fafc30dffebbe5a178361b`.

This is a completion-reconciliation stall, not permission to create a second
Q05 row or to skip ahead to Q06.

## Binding CPU stop

The required five one-second total-processor samples were 98.97%, 79.01%,
97.98%, 91.90%, and 79.74%. The maximum was 98.97%, exceeding the explicit
97% hard ceiling.

Per the mission stop condition, no completion reconciliation, Q06 successor,
enqueue, requeue, dispatch tick, tester launch, terminal reservation, terminal
control, or queue mutation followed.

Machine-readable evidence is
`artifacts/fx_cointegration_qm5_20208_q05_stall_hard_cpu_stop_20260822T173247Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry, magic row, or external
  queue row changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
