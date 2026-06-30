# QM5_12532 Q05 CPU Ceiling Stop

## Scope

Branch: `agents/board-advisor`.

Mission constraints honored:

- No `T_Live` access.
- No AutoTrading change.
- No portfolio gate edits.
- No manual MT5 tester launch.

## Pair Selection Audit

The controlling scan remains `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
plus the local `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`
logic over the 12-symbol Darwinex D1 export.

Read-only rerun of the local scan logic showed no unbuilt positive-hedge FX
cointegration pair left from the 66-pair universe. The apparent unbuilt
`AUDUSD~NZDUSD` row is already built as the special slug
`QM5_12532_edgelab-audnzd-cointegration`.

Current highest-ranked scan rows:

| Rank | Pair | Built state |
|---|---|---|
| 1 | `EURUSD~AUDUSD` | built as `QM5_12747` |
| 2 | `EURJPY~GBPJPY` | built as `QM5_12533` |
| 3 | `AUDUSD~NZDUSD` | built as `QM5_12532` |
| 4-29 | remaining positive-hedge scan rows | built through `QM5_12803` |

Per mission fallback, work focused on advancing an existing forex basket.

## Existing Basket State

`QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` is not Q02-blocked:

- latest logical-basket Q02: `PASS`
- later Q04: `FAIL`

`QM5_12532_AUDNZD_COINTEGRATION_D1` is the higher-quality existing target:

- latest logical-basket Q02: `PASS`
- latest Q04: `PASS`
- latest Q05: `INFRA_FAIL`

Latest Q05 row:

- work item: `82cab3d1-bf05-4aa4-8278-86c8064b16e7`
- phase: `Q05`
- symbol: `QM5_12532_AUDNZD_COINTEGRATION_D1`
- host symbol: `AUDUSD.DWX`
- status: `done`
- verdict: `INFRA_FAIL`
- evidence: `D:/QM/reports/work_items/82cab3d1-bf05-4aa4-8278-86c8064b16e7/QM5_12532/Q05/AUDUSD_DWX/aggregate.json`

## Stop Reason

The prior repair increased the Q05 tester budget to `-TimeoutSeconds 3300`
with wrapper headroom `3420` seconds. The requeued worker-owned run still hit
the tester timeout:

- run-smoke summary: `D:/QM/reports/work_items/82cab3d1-bf05-4aa4-8278-86c8064b16e7/QM5_12532/20260630_041853/summary.json`
- result: `FAIL`
- reason classes: `TIMEOUT`, `METATESTER_HUNG`, `INCOMPLETE_RUNS`, `MODEL4_MARKER_REQUIRED`
- report size: `0` bytes
- generated Q05 aggregate reason: `invalid_summary:INCOMPLETE_RUNS,TIMEOUT`
- Q05 runner timeout: `3420`

This is a backtest CPU ceiling condition for `QM5_12532` Q05. I did not enqueue
another Q05 run because it would duplicate the same worker-owned timeout path
and consume another paced terminal slot without a new fix.

## Queue Snapshot

No new queue rows were inserted in this pass. Current relevant active/pending
forex work observed during triage:

- `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1` Q02 active on `T5`
- `QM5_12758_GBPUSD_EURAUD_COINTEGRATION_D1` Q02 pending
- `QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1` Q06 pending
- `QM5_12821_twin-csm-basket` Q02 rows active/pending

## Outcome

Stopped under the mission CPU-ceiling instruction. The next useful action is an
owner/infra decision on whether Q05 may use a narrower validated window, a
longer worker envelope, or a different stress execution mode for low-frequency
D1 basket EAs. Without that decision, another enqueue is duplicate CPU work.
