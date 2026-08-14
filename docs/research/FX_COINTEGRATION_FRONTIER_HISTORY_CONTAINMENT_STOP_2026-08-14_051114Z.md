# FX cointegration frontier — signed history-containment stop

Date: 2026-08-14

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; rank-58 logical Q02 remains
PENDING; governed workers are fail-closed on custom-history integrity

## Outcome

No duplicate Card, EA, or Q02 row was created. The committed sign-aware
reconciliation of `analyze_cross_asset_v3.py --include-negative-hedges`
accounts for all 66 scan relationships, so there is no unbuilt relationship
left to mechanize.

The requested anchor repair is not applicable. The exact logical rows show:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.
- Neither anchor has an open Q02 ONINIT or NO_HISTORY blocker.

The existing-pair fallback remains frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in the approved and
built `QM5_1257_lemishko-fx-cointpair` basket. Its exact logical Q02 row is
`d4cd660c-c81a-41d3-8a4c-ad21d3319816`. At `2026-08-14T05:10:14Z` it was
PENDING, unclaimed, at attempt zero, priority-tracked, free of holds and
quarantine, and rank 9 of 1,014 eligible rows. It remains enqueued exactly
once; no enqueue, requeue, priority, or timestamp mutation was made.

## Existing-pair contract

The fallback is bound to the OWNER-approved Lemishko, Landi, and
Caicedo-Llano (2024) SSRN Card with R1-R4 PASS. Its basket manifest declares
`GBPUSD.DWX` and `USDJPY.DWX`; the logical H1 backtest setfile uses
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The frozen rank-58 scan evidence is adverse, so Q02 remains a one-shot
cadence/economics test. No refit, added filter, banned or ML indicator, rescue
tuning, or profitability claim was introduced.

## Binding stop

The prior capacity owner, Q02 work item
`b9bde578-9476-470f-a051-fda0a11116c6`, finished at
`2026-08-14T04:48:19Z` as INFRA_FAIL. The current sample found zero active
work items and zero T1-T10 terminal processes, so the backtest CPU ceiling is
not binding.

Execution is nevertheless forbidden by a stricter signed control. The
custom-history worker gate returned `FAIL_CLOSED` under audit
`e6447376d2440189d64d7fa8504771999f1711f1e1bd2acae94de001d0126392`.
It found nine manifest-bound archives missing across T2, T3, T5, T7, and T9,
producing 18 `MANIFEST_ARCHIVE_FILE_MISSING` /
`TERMINAL_MANIFEST_INCOMPLETE` findings. Automatic containment is engaged for
`custom_history_isolation_gate_failure`, and the watchdog has a
`dispatch_stall` reset pending.

This branch-only mission does not authorize bypassing the signed gate or
restoring terminal archives without a bounded OWNER operations receipt. No
dispatch tick, manual tester, terminal reservation/control, history mutation,
or containment/reset mutation was attempted.

## Verification

- Strategy Card schema lint: PASS, no missing sections or ML hits.
- Basket-manifest regression suite: 44 passed.
- Symbol scope: `BASKET_OK`, zero violations.
- Target build check: PASS, zero failures and zero warnings. Its mechanical
  setfile-header rewrites were reverted, leaving the target EA tree clean and
  byte-identical to the committed Q01/Q02 handoff.
- MQ5, EX5, Card, manifest, and fixed-risk setfile SHA-256 values match the
  prior committed handoff.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_history_containment_stop_20260814T051114Z_board_advisor.json`.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution path, T_Live
manifest or terminal, AutoTrading state, live deployment artifact, registry,
Card, EA, basket manifest, setfile, or external queue row was changed.
Concurrent unrelated worktree changes were not staged or modified.
