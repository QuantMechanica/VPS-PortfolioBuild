# QM5_13117 EURGBP/AUDJPY Q04 Handoff

Date: 2026-07-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Scope: one existing low-frequency FX cointegration basket. No tester dispatch,
live action, or portfolio-gate action.

## Outcome

The deterministic repaired-binary `QM5_13117_eurgbp-audjpy` sleeve now has
exactly one pending Q04 walk-forward item:

- Logical symbol: `QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1`.
- Traded legs: `EURGBP.DWX` and `AUDJPY.DWX`.
- Conversion/history dependencies: `GBPUSD.DWX` and `USDJPY.DWX`.
- Q03 PASS predecessor: `dc01fd4d-0f8f-414a-a6b1-80441204fefc`.
- Q04 work item: `82736cf7-2124-4e92-a54d-3102247f73ef`.
- State at verification: `pending`, unclaimed, attempt 0.
- Q04 OOS window: 2023-2024, clamped to the latest complete basket-history
  year found in the MT5 cache.

The supported enqueue path was used without a dispatch tick:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_13117 --phase Q04
```

## Selection and De-duplication

The source-qualified frontier is exhausted. The published positive-hedge
66-pair scan admitted only two pairs, both already built and beyond Q02:

- `QM5_12532` AUDUSD/NZDUSD: Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY: Q02 PASS, Q04 FAIL.

Neither anchor has an open ONINIT or NO_HISTORY Q02 blocker. The strict
all-sign reproduction adds five rows, but all seven qualifying rows already
have approved cards and EA folders:

| Rank | Pair | EA | Built |
|---:|---|---|---|
| 1 | GBPUSD/USDCAD | `QM5_12978` | yes |
| 2 | EURJPY/GBPJPY | `QM5_12533` | yes |
| 3 | AUDUSD/NZDUSD | `QM5_12532` | yes |
| 4 | USDCAD/NZDUSD | `QM5_13003` | yes |
| 5 | AUDUSD/EURGBP | `QM5_13106` | yes |
| 6 | EURGBP/AUDJPY | `QM5_13117` | yes |
| 7 | USDJPY/EURAUD | `QM5_13119` | yes |

Creating an eighth card would weaken the documented threshold or duplicate a
built sleeve. The mission fallback therefore applied. `QM5_13117` was chosen
because its repaired build had a fresh Q03 PASS and no Q04 row; `QM5_13119`
was already active at Q03 on T3.

The empirical lineage is the OWNER-requested scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced with:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

The reputable method source on the approved card is Ernest P. Chan,
*Quantitative Trading* (Wiley, 2009), Example 3.6 and Chapter 7. The pair's
screen recorded DEV net Sharpe `0.4168`, OOS net Sharpe `0.8919`, OOS return
`4.4752%`, 20 OOS state changes, fixed beta `-0.12202869296345396`, and a
36.84-day half-life. These are screening measurements, not admission claims.

## Build and Risk Preflight

No strategy or build artifact changed. The Q03-tested files remain pinned:

| Artifact | SHA256 |
|---|---|
| MQ5 | `14ddccb7ac7fe8b1c1e9cec4c6a59c7045481de99f15e1728fb38a76cfe6bcd1` |
| EX5 | `aa8ff930a973632b0dbd9b2694ccf20869f441a4fa7c9eac670339800eb199ef` |
| Basket manifest | `e8d1fcf2e2b5cd96258b4c4aef496871c54f247ad671e449a3d2f92a2d186387` |
| Backtest setfile | `c584bcf5b274ae293ebd0ea60ba9ba7ea0ca5a4afda09da2fb50423322531b83` |

The setfile remains structural and fixed-risk: `environment=backtest`,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. It contains no
ML, banned indicator, adaptive refit, grid, martingale, or pyramiding logic.

The Q03 screen completed two identical Model-4 runs with 112 trades, PF 1.46,
net profit 4,991.52, and drawdown 3,049.81 (2.86%) per run. Its aggregate
reported `deterministic=true` and PASS.

## Queue Mutation

An online SQLite backup was taken before the official idempotent cascade
enqueue. The command created one Q04 row and then skipped the second historical
Q02 PASS predecessor because the target row was already pending. This is one
Q04 row, not a duplicate enqueue.

- Work item: `82736cf7-2124-4e92-a54d-3102247f73ef`.
- Enqueue event: `246735` (`cascade_backtest_enqueued`).
- Same-target Q04 rows: 1.
- Same-target open Q04 rows: 1.
- Live database `PRAGMA quick_check`: `ok`.
- Backup `PRAGMA quick_check`: `ok`.
- Backup: `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13117_q04_handoff_20260711T113234Z.sqlite`.

The cascade API models Q04 as a default-parameter probe promoted from a Q02
PASS, so the row payload names repaired Q02 work item
`fb649d4a-3a9e-42e8-ae99-b492d2c65f5e`. The independent Q03 PASS above still
establishes determinism and is the operator reason for advancing this sleeve.

## Capacity and Safety

At the post-enqueue scan, factory terminals T2 and T3 were running, below the
seven-job CPU ceiling. `FACTORY_OFF.flag` remained present. No Q04 tester was
launched; normal paced orchestration may claim the pending row later.

`T_Live` was observed only through the read-only slot scan and was not touched.
No AutoTrading state, live/deploy manifest, portfolio gate,
`portfolio_admission`, portfolio KPI, or Q08 contribution path changed.

Machine-readable evidence:
`artifacts/qm5_13117_q04_handoff_20260711.json`.
