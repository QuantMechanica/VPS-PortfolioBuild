# FX Cointegration Work-Items Status Helper - 2026-07-02

Branch: `agents/board-advisor`

## Scope

Mission was to grow the V5 book with market-neutral FX cointegration baskets,
preferring `QM5_12532` / `QM5_12533` Q02 unblocks if they were still blocked.
No `T_Live`, AutoTrading, portfolio gate, portfolio KPI, Q08 contribution, or
deploy-manifest files were touched.

## Research State

The controlling scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.
It documents only two strict 66-pair FX cointegration survivors:

| Pair | State |
|---|---|
| `EURJPY~GBPJPY` | built as `QM5_12533` |
| `AUDUSD~NZDUSD` | built as `QM5_12532` |

I did not create a weaker duplicate card from the null-heavy scan.

## Current Funnel State Checked

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Checked at `2026-07-02T21:33:58+02:00`.

| EA | Current relevant state |
|---|---|
| `QM5_12532` | Q02 `PASS`, Q04 `PASS`, Q05 `pending` as `82cab3d1-bf05-4aa4-8278-86c8064b16e7` |
| `QM5_12533` | Q02 `PASS`, later Q04 `FAIL` |
| `QM5_12728` | Q02 `PASS`, Q04 `pending` as `6a1a390b-7380-407e-a75d-6c64cec9a63f` |
| `QM5_12772` | Q02 `PASS`, Q04 `PASS_SOFT`, Q05 `pending` as `dd43c7e2-7351-41e1-a4a4-f667d0789249` |
| `QM5_12778` | Q02/Q03/Q04 `PASS`, Q05 `pending` as `1c0405e7-16d3-40e6-b884-6be1b504dc4c` |
| `QM5_12781` | Q05/Q06 `PASS`, Q07 `active` on `T2` as `38226031-b41f-4f03-ab86-d1697ca5e203` |

The queue had 4 active and 5,224 pending `work_items`. Enqueueing another FX
basket row at this point would be duplicate CPU work without a new runner mode
or timeout budget.

## Work Committed

`framework/scripts/mt5_queue_status.py` previously returned `schema=unknown`
for the live farm DB because it recognized only `jobs` and `mt5_job_queue`.
I added read-only support for the current `work_items` schema:

- status counts from `work_items`
- oldest pending work items in `queued_top`
- active claimed work items in `dispatched_top`

This makes future FX basket triage show whether candidate rows are already
pending or active before any enqueue mutation.

## Verification

- `python -m unittest framework.scripts.tests.test_mt5_queue_status` -> PASS
- `python framework/scripts/mt5_queue_status.py --sqlite D:/QM/strategy_farm/state/farm_state.sqlite --limit 5` -> `schema: work_items`

