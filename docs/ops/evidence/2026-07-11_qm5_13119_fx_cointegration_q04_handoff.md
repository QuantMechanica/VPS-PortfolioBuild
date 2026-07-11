# QM5_13119 USDJPY/EURAUD Q04 Handoff

Date: 2026-07-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Scope: one existing low-frequency FX cointegration basket. No tester dispatch,
live action, or portfolio-gate action.

## Outcome

The repaired and deterministic `QM5_13119_usdjpy-euraud` sleeve now has
exactly one pending Q04 walk-forward item:

- Logical symbol: `QM5_13119_USDJPY_EURAUD_COINTEGRATION_D1`.
- Traded legs: `USDJPY.DWX` and `EURAUD.DWX`.
- Conversion/history dependencies: `AUDUSD.DWX` and `EURUSD.DWX`.
- Q03 PASS predecessor: `e786ef7d-aaf8-4813-aae1-1e2f34f62ccb`.
- Q04 work item: `addea337-31f5-4267-b002-1281eaf9f94c`.
- State at verification: `pending`, unclaimed, attempt 0.
- Q04 OOS window: 2023-2024, clamped to the latest complete basket-history
  year found in the MT5 cache.

The supported enqueue path was used without a dispatch tick:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_13119 --phase Q04
```

## Selection and De-duplication

The source-qualified frontier is exhausted. The published positive-hedge
66-pair scan admitted only two pairs, both already built and beyond Q02:

- `QM5_12532` AUDUSD/NZDUSD: Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY: Q02 PASS, Q04 FAIL.

Neither anchor has an open ONINIT or NO_HISTORY Q02 blocker. The strict
sign-aware reproduction adds five rows, but all seven qualifying rows already
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
built sleeve. The mission fallback therefore applied: advance `QM5_13119`,
the final strict row, from its fresh Q03 PASS to Q04.

The empirical lineage is the OWNER-requested scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced with:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

The reputable method source on the approved card is Ernest P. Chan,
*Quantitative Trading* (Wiley, 2009), Example 3.6 and Chapter 7. The pair's
screen recorded DEV net Sharpe `0.5059`, OOS net Sharpe `0.8837`, OOS return
`16.0148%`, 23 OOS state changes, fixed beta `-1.4182482311707278`, and a
77.46-day half-life. These are screening measurements, not admission claims.
The negative beta makes both legs point in the same direction, so regression
neutrality does not imply currency, directional, carry, or portfolio
neutrality.

## Build and Risk Preflight

No strategy or build artifact changed. The Q03-tested files remain pinned:

| Artifact | SHA256 |
|---|---|
| MQ5 | `7aacf8d12b90d3838c70d18984556df5060864c182281e31a1bafbfac6a947f1` |
| EX5 | `a3988df814790762be229b84e3483ae460128f6e6a056a673a74edd544834a5e` |
| Basket manifest | `718150ded145287458aed5f0376ca5fe22377949cc00f2941f1a1604f59f6e90` |
| Backtest setfile | `5dfdda38d1a2edf21cb78ab4174c5c75300160d87f91d8271e4673c384b008c5` |

The setfile remains structural and fixed-risk: `environment=backtest`,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. It contains no
ML, banned indicator, adaptive refit, grid, martingale, or pyramiding logic.
The approved card and allocated registry/magic rows remain unchanged.

The Q03 screen completed two identical Model-4 runs with 136 trades, PF 1.06,
net profit 966.39, and drawdown 3,033.82 (2.92%) per run. Its aggregate
reported `deterministic=true` and PASS.

## Queue Mutation

An online SQLite backup was taken before the official idempotent cascade
enqueue. The command created one Q04 row and skipped the second historical
Q02 PASS predecessor after finding that new pending row. This is one Q04 row,
not a duplicate enqueue.

- Work item: `addea337-31f5-4267-b002-1281eaf9f94c`.
- Enqueue event: `246748` (`cascade_backtest_enqueued`).
- Same-target Q04 rows: 1.
- Same-target open Q04 rows: 1.
- Live database `PRAGMA quick_check`: `ok`.
- Backup `PRAGMA quick_check`: `ok`.
- Backup: `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13119_q04_handoff_20260711T130155Z.sqlite`.

The cascade API models Q04 as a default-parameter probe promoted from Q02
PASS work item `77ec9572-e064-44bd-a756-51647aa383b9`. The independent Q03 PASS
above establishes determinism and is the operator reason for advancing the
sleeve.

## Capacity and Safety

At the post-enqueue scan, no factory terminal or MetaTester process was
running, below the seven-job CPU ceiling. No dispatch was requested; normal
paced orchestration may claim the pending row later.

`T_Live` was observed only through a read-only process scan and was not
touched. No AutoTrading state, live/deploy manifest, portfolio gate,
`portfolio_admission`, portfolio KPI, or Q08 contribution path changed.

Machine-readable evidence:
`artifacts/qm5_13119_q04_handoff_20260711.json`.
