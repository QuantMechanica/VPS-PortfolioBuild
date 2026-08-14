# FX cointegration fallback — Q02 runtime-binding stop

**Date:** 2026-08-14 09:35Z

**Branch:** `agents/board-advisor`

**Status:** exact logical Q02 row remains pending; post-DL-085 factory activation is fail-closed on an obsolete signed source binding

## Outcome

No duplicate Strategy Card, EA, setfile, basket manifest, or queue row was
created. The documented sign-aware reconciliation covers all 66 relationships,
so the governed scan has no unbuilt successor. The two requested anchors also
need no Q02 repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The authorized fallback remains frozen-scan rank 58, `GBPUSD.DWX` /
`USDJPY.DWX`, implemented as pair slot 8 in the approved and built
`QM5_1257_lemishko-fx-cointpair` basket. Its manifest declares both traded
legs, and its canonical backtest setfile is `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No refit, new filter, banned or ML
indicator, or strategy-mechanics change was made.

## Non-duplicate queue state

The exact logical Q02 row is
`d4cd660c-c81a-41d3-8a4c-ad21d3319816` for
`QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1`. A read-only query at 09:35Z found:

- `status=pending`, `attempt_count=1`, `claimed_by=NULL`;
- exactly one open row for this `(ea_id, logical symbol, Q02)` identity;
- `priority_track=true`, with the existing board-advisor FX fallback reason;
- prior infrastructure outcome `summary_missing`; and
- T4 excluded from the next attempt.

The row was therefore not enqueued, requeued, reprioritized, or restamped.
Its binary and setfile bindings remain authenticated in the payload.

## Binding stop, not CPU ceiling

Capacity itself was available: 54.31 GiB of 63.12 GiB physical RAM was free,
there were zero active work items and zero T1-T10 factory terminals, and only
the separately excluded `T_Live` terminal plus an unrelated FTMO terminal were
observed. This mission did **not** hit the backtest CPU ceiling.

The fleet is instead stopped by the signed runtime-activation boundary. The
current OWNER decision `RTA-2026-08-14-T8RESTORE-R8` binds the pre-DL-085
`tools/strategy_farm/farmctl.py` SHA-256
`9c463d7479fe8984e52f192abdb6b2a5acd7125539761cf595909ef4c1bf9592`.
HEAD `4b43760ee` contains the ratified DL-085 repair-first implementation and the
current file hashes to
`4da48df4a70859dd03e5e56c05f78e8bb452b980b844530ebe4562a6fc89b4ba`.
The canonical validator exits 1 on that mismatch, and the scheduled
Factory_ON attempt at 11:30 local also exited 1. The watchdog reset-admission
marker remains present while no terminal-worker daemon is running.

Bypassing or rewriting that signed binding would cross the OWNER-governed
factory activation contract. The next valid action is a fresh OWNER-signed
runtime activation decision that binds the post-DL-085 source hashes; once the
factory is restarted, the existing priority row can be claimed without any
queue mutation.

Machine-readable evidence:
`artifacts/fx_cointegration_gbpusd_usdjpy_runtime_binding_stop_20260814T093500Z_board_advisor.json`.

## Safety

- No portfolio admission, KPI, or Q08 contribution path changed.
- No `T_Live` manifest, terminal, AutoTrading state, or deployment artifact changed.
- No Card, EA, registry, magic row, setfile, basket manifest, or external queue row changed.
- No MT5 tester, factory terminal, or terminal worker was launched by this mission.
