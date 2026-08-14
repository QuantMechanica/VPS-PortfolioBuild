# FX cointegration frontier — resource-ceiling stop

Date: 2026-08-14

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; the exact fallback Q02 remains
PENDING once; physical-memory exhaustion and signed Custom-history
containment bind the fleet

## Outcome

No duplicate Strategy Card, EA, registry row, basket manifest, setfile, or Q02
row was created. The committed sign-aware reconciliation of
`analyze_cross_asset_v3.py --include-negative-hedges` covers all 66 frozen
relationships, so there is no unbuilt scan pair left to mechanize.

The two requested anchors remain beyond Q02 and have no open ONINIT or
NO_HISTORY repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The non-duplicate fallback therefore remains frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in approved and built
`QM5_1257_lemishko-fx-cointpair`. Its exact logical Q02 row is
`d4cd660c-c81a-41d3-8a4c-ad21d3319816`.

At the `2026-08-14T21:58:56.432113Z` read-only database sample the row was
PENDING, unclaimed, at `attempt_count=1`, with no verdict or evidence path.
It remained the only row for
`QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1`. The prior attempt is still
infrastructure-incomplete (`summary_missing`), not a strategy verdict.
Enqueueing, requeueing, restamping, or reprioritising it would have been a
duplicate mutation.

## Existing-pair contract

The fallback is bound to the OWNER-approved Lemishko, Landi, and
Caicedo-Llano (2024) SSRN Card with R1-R4 PASS. It is a structural,
low-frequency residual-reversion package with a frozen hedge ratio and no ML,
grid, martingale, adaptive refit, or rescue filter. Its manifest declares
`GBPUSD.DWX` and `USDJPY.DWX`; the logical H1 backtest setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Fresh SHA-256 reads confirmed that its MQ5, EX5, Strategy Card, manifest, and
fixed-risk setfile still match the exact hashes bound into the existing Q02
row. No strategy or build artifact was changed.

## Binding resource stop

At the database sample, two Q02 work items were still active on T3 and T5.
The operating-system sample reported only **1.08 GiB free of 63.12 GiB**
physical memory. A simultaneous `Win32_Process` enumeration failed with:

```text
Not enough memory resources are available to complete this operation.
```

The last successful process sample, at `21:57:26Z`, had observed factory MT5
children on T3, T4, T5, and T10. The first three were work-item-bound; T10 was
a separate pipeline run. `T_Live` and the FTMO terminal were observed only to
exclude them and were not controlled. The later failed enumeration is not
used to infer that any process ended or became orphaned.

Signed Custom-history containment was also enabled at `21:49:45Z`, with
reason `custom_history_isolation_gate_failure`, mode SHA-256
`7762386ccc727229007d46a6ff1244e8dc988669b24a111f71a0cff5385c1740`,
and authorization SHA-256
`61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e`.

This is the mission's explicit backtest CPU/resource-ceiling stop. No dispatch
tick, tester, enqueue, requeue, terminal reservation/control, containment
mutation, Factory recovery, or process cleanup was attempted.

## Non-duplicate delta

This record is materially distinct from the `19:48:20Z` active-basket stop.
That sample had 54.34 GiB free and successful process attribution; the current
sample has 1.08 GiB free, a resource-exhaustion failure during process
enumeration, and a newer signed containment record with an isolation-gate
reason. The target Q02 identity itself remains unchanged and pending exactly
once.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_resource_ceiling_stop_20260814T215856Z_board_advisor.json`.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution path, T_Live manifest
or terminal, AutoTrading state, live-deployment artifact, registry, Card, EA,
basket manifest, setfile, external queue row, history archive, or containment
state was changed. Concurrent unrelated worktree changes were left unstaged
and untouched.
