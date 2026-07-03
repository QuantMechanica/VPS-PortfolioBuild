# Q07 Seed-Reuse Repair for FX Cointegration - 2026-07-03

Branch: `agents/board-advisor`

## Scope

Mission: grow the V5 forex sleeve book with market-neutral FX cointegration
baskets, preferring `QM5_12532` / `QM5_12533` Q02 repairs if still blocked.

No `T_Live`, AutoTrading, portfolio gate, portfolio admission, portfolio KPI,
Q08 contribution, or deploy manifest files were touched.

## Funnel State

Research source checked:
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.

The two strict 66-pair survivors are no longer Q02 blocked:

| Pair | EA | Current state |
|---|---|---|
| `AUDUSD~NZDUSD` | `QM5_12532` | Q02 `PASS`, Q04 `PASS`, latest Q05 `FAIL` |
| `EURJPY~GBPJPY` | `QM5_12533` | Q02 `PASS`, latest Q04 `FAIL` |

All approved EdgeLab FX cointegration cards visible in
`strategy-seeds/cards/approved/` already have matching EA folders. The latest
non-duplicate pair already on branch, `QM5_12978` (`GBPUSD~USDCAD`), reached
Q02 `PASS`, Q03 `PASS`, and Q04 `FAIL`.

## Work Done

The current actionable forex path is a built basket already in later funnel
stages. `QM5_12772` (`GBPJPY~AUDJPY`) failed Q07 as `INFRA_FAIL` after repeated
work-item retries, but its report root contains valid per-seed smoke evidence.
The runner was repeatedly restarting at seed 42 and burning CPU on the same
successful seeds, then timing out before reaching seed 2026.

I made `framework/scripts/q07_multiseed.py` resumable:

- it scans the isolated work-item report root for existing `summary.json` files;
- it also scans same-work-item `.requeued_*` archived report roots;
- it recovers the seed identity from each raw `tester.ini` seed setfile;
- it reuses only valid seed summaries with PF and trade counts above the Q07
  evidence floor;
- it still reruns missing or invalid seeds, so it cannot turn partial evidence
  into a PASS.

Read-only dry check on failed work item
`0727c6a0-e41f-41b0-bf5a-261a7b80a077` now recovers:

| Seed | PF | Trades |
|---:|---:|---:|
| 17 | 1.01 | 226 |
| 42 | 1.01 | 226 |
| 99 | 1.01 | 226 |

Seeds 7 and 2026 remain missing, so no DB verdict was changed.

## CPU Ceiling

Fresh queue status still showed five active work items. No new Q02/Q07/Q08 row
was enqueued and no manual MT5 backtest was launched.

## Verification

- `python -m unittest framework.scripts.tests.test_q05_q07_verdicts` -> PASS
- `python -m py_compile framework/scripts/q07_multiseed.py` -> PASS
- Read-only actual-root recovery found seeds `[17, 42, 99]` for `QM5_12772`.
