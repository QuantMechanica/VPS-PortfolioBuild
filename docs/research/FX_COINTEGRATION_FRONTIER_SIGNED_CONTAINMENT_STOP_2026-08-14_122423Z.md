# FX cointegration frontier — signed serial-capacity stop

Date: 2026-08-14

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; rank-58 logical Q02 remains
PENDING exactly once; the signed Custom-history containment lease owns the
effective one-run backtest ceiling

## Outcome

No duplicate Strategy Card, EA, registry row, basket manifest, setfile, or Q02
row was created. The committed sign-aware reconciliation of
`analyze_cross_asset_v3.py --include-negative-hedges` accounts for all 66
relationships, so there is no unbuilt scan relationship left to mechanize.

The two requested anchors remain downstream of Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.
- Neither anchor has an open Q02 ONINIT or NO_HISTORY blocker.

The non-duplicate fallback remains frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in the approved and
built `QM5_1257_lemishko-fx-cointpair` basket. Its exact logical Q02 row is
`d4cd660c-c81a-41d3-8a4c-ad21d3319816`. At `2026-08-14T12:24:23Z` it was
PENDING, unclaimed, at `attempt_count=1`, with no verdict or evidence path.
The exact logical identity still has one row, and its existing priority track
is unchanged. The prior attempt remains classified `summary_missing`, not a
strategy verdict.

## Existing-pair contract revalidation

The fallback remains bound to the OWNER-approved Lemishko, Landi, and
Caicedo-Llano (2024) SSRN Card with R1-R4 PASS. It is a structural,
low-frequency two-leg residual-reversion sleeve with no ML, grid, martingale,
or adaptive refit. The basket manifest declares `GBPUSD.DWX` and
`USDJPY.DWX`; the logical H1 backtest setfile remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Fresh non-mutating validation passed:

- Strategy Card schema lint: PASS, zero missing sections and zero ML hits.
- FX basket/work-item regression tests: 59 passed.
- Symbol-scope validation: `BASKET_OK`, zero violations.
- MQ5, EX5, Card, manifest, and fixed-risk setfile hashes match the preceding
  Q02 handoff.

## Binding stop

The earlier nominal paced-CPU ceiling is no longer binding: the farm database
contained one active work item, below the normal ceiling of seven, and no
active multisymbol item. A newer signed control is binding instead.

`D:/QM/strategy_farm/state/custom_history_containment_mode.json` records
`enabled:true`, reason `runtime_stop_condition:isolation_gate`, at
`2026-08-14T11:18:26.833961Z`, with mode SHA-256
`8c88c4092c25c0cbc16f5b557aae0b755b9b045b611a07d368b4fd76ab8c2f23`.
The global containment lease was write-held by the sole active factory run,
and the other workers reported `custom_history_lease_busy`. This makes one
active run the effective signed backtest ceiling until the lease is released.

Releasing containment requires the governed OWNER recovery-window workflow.
This mission does not authorize fabricating that countersignature, bypassing
the lease, restoring or rewriting terminal archives, or forcing a competing
claim. Therefore no dispatch tick, manual tester, enqueue, requeue, priority
mutation, terminal reservation, or terminal control was attempted.

This is non-duplicate evidence relative to the preceding `11:16:44Z` stop:
the prior record observed seven active items at the nominal paced ceiling,
whereas the signed containment receipt was re-engaged at `11:18:26Z` and the
current farm is serialized at one active item.

## Safety

No portfolio-admission, portfolio-KPI, Q08-contribution, T_Live manifest or
terminal, AutoTrading state, live-deployment artifact, registry, Card, EA,
basket manifest, or setfile was changed. Concurrent unrelated worktree changes
were left unstaged and untouched.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_signed_containment_stop_20260814T122423Z_board_advisor.json`.
