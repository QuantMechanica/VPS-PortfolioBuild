# FX cointegration GBPUSD/USDJPY — active Q02 resource stop

Date: 2026-08-15

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; the exact non-duplicate fallback is
now ACTIVE at Q02; fleet memory is exhausted

## Outcome

No duplicate Strategy Card, EA, registry row, basket manifest, setfile, or Q02
row was created. The committed sign-aware reconciliation of
`analyze_cross_asset_v3.py --include-negative-hedges` covers all 66 frozen
relationships, so there is no unbuilt scan pair left to mechanize.

The two requested anchors remain beyond Q02 and have no open ONINIT or
NO_HISTORY repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The governed fallback remains frozen-scan rank 58, `GBPUSD.DWX` /
`USDJPY.DWX`, implemented as pair slot 8 in approved and built
`QM5_1257_lemishko-fx-cointpair`. Its exact logical Q02 row is
`d4cd660c-c81a-41d3-8a4c-ad21d3319816`.

At the current read-only sample, that existing row had advanced from PENDING
to ACTIVE, remained at `attempt_count=1`, and was claimed by T8. The
path-anchored process scan tied PID 15028 to
`D:\QM\mt5\T8\terminal64.exe` and to the exact work-item UUID through its
tester configuration. It remains the only governed logical Q02 identity for
`QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1`; no enqueue, requeue, priority
mutation, tester launch, or terminal action is warranted.

## Existing-pair contract

The fallback remains bound to the OWNER-approved Lemishko, Landi, and
Caicedo-Llano (2024) SSRN Card with R1-R4 PASS. It is a structural,
low-frequency residual-reversion basket with a frozen hedge ratio and no ML,
grid, martingale, adaptive refit, or rescue filter. Its manifest declares
`GBPUSD.DWX` and `USDJPY.DWX`; the logical H1 backtest setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Fresh SHA-256 reads confirmed that the MQ5, EX5, Strategy Card, manifest, and
fixed-risk setfile are unchanged from the prior committed handoff.

## Binding resource stop

The canonical database reported nine active work items: eight at Q02 and one
at Q08. They were claimed across T2 through T10, including the selected FX
basket on T8. The path-aware scan observed tester children on T2 through T9;
T5 was a separate pipeline run. Every T1-T10 worker daemon was present, and
there were no orphaned factory tester processes in the snapshot.

At `2026-08-15T08:37:30.927009Z`, Windows reported only 566,536 KiB
(approximately 0.54 GiB) free of 63.12 GiB physical memory. Custom-history
containment was disabled under its signed recovery record, so containment is
not the blocker; the independently observed physical-memory exhaustion is.

This meets the mission's explicit backtest CPU/resource-ceiling stop. No
dispatch tick, tester, enqueue, requeue, terminal reservation/control,
containment mutation, Factory recovery, or process cleanup was attempted.
The separately observed `T_Live` and FTMO terminals were excluded and
untouched.

## Non-duplicate delta

This record is materially distinct from the 2026-08-14 resource stop. The
selected row has advanced from PENDING/unclaimed to ACTIVE/claimed by T8 and
has a path- and UUID-bound tester child. The prior signed containment stop has
been released, while current free memory has fallen from 1.08 GiB to 0.54 GiB
and nine canonical work items are active. The correct contribution is a
durable handoff, not another queue or strategy artifact.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_active_resource_stop_20260815T083730Z_board_advisor.json`.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution path, T_Live
manifest or terminal, AutoTrading state, live-deployment artifact, registry,
Card, EA, basket manifest, setfile, external queue row, history archive, or
containment state was changed.
