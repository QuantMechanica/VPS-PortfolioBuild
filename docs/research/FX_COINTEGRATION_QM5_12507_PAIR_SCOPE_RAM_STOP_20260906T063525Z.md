# FX cointegration QM5_12507 pair-scope RAM stop

Recorded: 2026-09-06T06:35:25Z (08:35 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `3ad5179892`

## Outcome

No new Strategy Card or EA was created. The frozen 66-pair FX discovery is
fully represented by existing builds, and the two preferred anchors are past
Q02: `QM5_12532` has logical-basket Q02 PASS followed by Q05 FAIL, while
`QM5_12533` has logical-basket Q02 PASS followed by Q04 FAIL. Neither anchor
has a current Q02 ONINIT or NO_HISTORY defect.

The concrete non-duplicate fallback remains the existing `QM5_12507`
EURUSD/GBPUSD H1 logical cointegration basket. Its unique current Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` is pending, unclaimed, attempt zero,
unheld, and already carries `priority_track=true`. It is claimable at rank 143
of 8,916 rows in the canonical hold-filtered order. Appending another Q02 row,
restamping the existing priority mark, or directly claiming around the
resident terminal workers would not be a legitimate advancement.

## Pair-scope guard

A source-level audit closes the apparent shortcut of reducing the manifest
from four symbols to the two traded FX legs merely to obtain the worker's
two-leg FX RAM class:

- `Strategy_EnsureBasketScope()` in
  `framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5` explicitly
  selects and warms `EURUSD.DWX`, `GBPUSD.DWX`, `NDX.DWX`, and `WS30.DWX`.
- `test_qm5_12507_manifest_declares_all_warmed_pair_symbols` in
  `tools/strategy_farm/tests/test_fx_basket_manifests.py` enforces that every
  warmed symbol remains declared by `basket_manifest.json`.
- The authenticated logical Q01 PASS and its Q02 successor are hash-bound to
  the current source, binary, setfile, and four-symbol history scope.

Therefore a two-symbol manifest edit alone would be a false setup repair and
could recreate NO_HISTORY/partial-history behavior. Pair-selective warmup would
require a new binary and fresh authenticated Q01 lineage before a successor
Q02; it is not authorized as an in-place queue repair.

## Capacity stop

The explicit CPU ceiling did not bind. Five one-second whole-host samples were
80.191%, 77.691%, 78.717%, 78.034%, and 71.588% (average 77.244%, maximum
80.191%) against the 97% ceiling. Free physical memory was 30.712 GiB of
63.120 GiB.

The resident worker's drain-window tracker still names priority FX basket
`QM5_10718` as the non-winnable head. Its governed admission requires a 44 GiB
reservation plus the 14 GiB post-reservation floor, or 58 GiB available. The
same four-symbol manifest shape keeps `QM5_12507` in the 44 GiB heavy/unknown
multisymbol class. It must not bypass the head or the RAM gate. The supported
slot census observed three factory MT5 terminals (`T3`, `T9`, and `T10`) and
the separately excluded `T_Live`; no terminal was controlled.

## Preserved continuation

| Field | Value |
| --- | --- |
| EA | `QM5_12507_pair-coint-z` |
| Pair | `EURUSD.DWX` / `GBPUSD.DWX` |
| Logical symbol | `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` |
| Work item | `547c4fd3-f3fd-4c59-b9dc-654e96521251` |
| State | pending, unclaimed, attempt 0, no verdict, no active hold |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |
| Manifest | `framework/EAs/QM5_12507_pair-coint-z/basket_manifest.json` |
| Setfile | `framework/EAs/QM5_12507_pair-coint-z/sets/QM5_12507_pair-coint-z_QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1_H1_backtest.set` |

No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
`T_Live` manifest, live/deploy, AutoTrading, queue payload, hold, priority,
claim, tester, EA, setfile, manifest, or registry state was changed.

Resume only through the resident worker's canonical claim path after the RAM
drain becomes winnable. Do not shrink the manifest without a reviewed
pair-selective-warmup build and fresh Q01 lineage, and never append a duplicate
logical Q02 row.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_pair_scope_ram_stop_20260906T063525Z_board_advisor.json`.
