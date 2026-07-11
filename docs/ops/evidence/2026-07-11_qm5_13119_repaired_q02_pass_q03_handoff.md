# QM5_13119 Repaired USDJPY/EURAUD Q02 PASS to Q03 Handoff

Date: 2026-07-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Scope: one existing low-frequency FX cointegration basket. No live, portfolio-gate, or tester-dispatch action.

## Outcome

The repaired `QM5_13119_usdjpy-euraud` binary already had a fresh real-tick Q02 PASS but no downstream handoff. One Q03 row now exists for the same logical basket and canonical setfile:

- Logical symbol: `QM5_13119_USDJPY_EURAUD_COINTEGRATION_D1`.
- Traded legs: `USDJPY.DWX` and `EURAUD.DWX`.
- Conversion/history dependencies: `AUDUSD.DWX` and `EURUSD.DWX`.
- Q02 predecessor: `77ec9572-e064-44bd-a756-51647aa383b9`.
- Q03 work item: `e786ef7d-aaf8-4813-aae1-1e2f34f62ccb`.
- Q03 parent task: `490a1cbf-1d27-4109-b324-158e44c18500`.
- State: `pending`, unclaimed, attempt 0.

The Q03 row was enqueued only. Factory OFF remained asserted and no MT5 tester was launched.

## Selection and De-duplication

The source-qualified frontier is exhausted rather than merely hard to find. The published positive-hedge 66-pair scan has two survivors, both already built and past Q02:

- `QM5_12532` AUDUSD/NZDUSD: Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY: Q02 PASS, Q04 FAIL.

The strict sign-aware reproduction adds GBPUSD/USDCAD, USDCAD/NZDUSD, AUDUSD/EURGBP, EURGBP/AUDJPY, and USDJPY/EURAUD. All seven strict rows have approved cards and EA folders (`QM5_12978`, `QM5_12533`, `QM5_12532`, `QM5_13003`, `QM5_13106`, `QM5_13117`, and `QM5_13119`). Creating another card would weaken the documented threshold or duplicate a built pair, so the mission fallback applied: advance the final strict existing sleeve.

The empirical lineage is the OWNER-requested scan in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced with:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

The reputable method source is Ernest P. Chan, *Quantitative Trading* (Wiley, 2009), Example 3.6 and Chapter 7.

## Build and Risk Preflight

The repaired build from commit `b92667599587ad889b24f4be4d25427981b9a0d3` remains the promoted artifact:

| Check | Result |
|---|---|
| MQ5 SHA256 | `7aacf8d12b90d3838c70d18984556df5060864c182281e31a1bafbfac6a947f1` |
| EX5 SHA256 | `a3988df814790762be229b84e3483ae460128f6e6a056a673a74edd544834a5e` |
| Basket manifest SHA256 | `718150ded145287458aed5f0376ca5fe22377949cc00f2941f1a1604f59f6e90` |
| Q02-deployed setfile SHA256 | `b4ad75aa7e65a22e57e384d1a7841880bac1bddc317d5c193bacc747be4750c4` |
| Build check | PASS, 0 failures and 0 warnings (`D:/QM/reports/framework/21/build_check_20260711_050630.json`) |
| SPEC validation | PASS |
| Symbol scope | `BASKET_OK`, 0 violations |
| Basket manifest tests | 17 passed |

The backtest setfile remains structural and fixed-risk: `environment=backtest`, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No ML, banned indicator, adaptive refit, grid, martingale, or pyramiding logic was added.

A verification-only build-check invocation also passed, but its comment-hash refresh reflected unrelated dirty framework includes in the shared worktree. That comment-only side effect was not retained; the tracked target files remain unchanged and the Q02-tested setfile provenance is pinned in the Q03 payload.

## Q02 Evidence

The promotion predecessor is the repaired-binary real-tick run at `D:/QM/reports/work_items/77ec9572-e064-44bd-a756-51647aa383b9/QM5_13119/20260711_054814/summary.json`:

| Field | Value |
|---|---:|
| Status / verdict | `done` / `PASS` |
| Window | 2018-07-02 through 2022-12-31 |
| Model / period | Real ticks (`4`) / D1 |
| Trades | 136 |
| Profit factor | 1.06 |
| Net profit | 966.39 |
| Drawdown | 3,033.82 (2.92%) |
| ONINIT failure | false |
| Real-tick marker | true |
| Log bomb | false |

## Q03 Queue Mutation

The handoff used the guarded `codex` dispatch scope, an online SQLite backup, and an in-transaction duplicate check. Exactly one open Q03 row exists for this EA, logical symbol, and setfile.

- Work item: `e786ef7d-aaf8-4813-aae1-1e2f34f62ccb`.
- Parent task: `490a1cbf-1d27-4109-b324-158e44c18500`.
- Enqueue event: `246700`.
- Canonical Q02 metric correction event: `246702`.
- Setfile-provenance event: `246709`.
- Database backup: `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13119_q03_handoff_20260711T063714Z.sqlite`.
- Live database integrity: `ok`; backup integrity: `ok`.

No duplicate Q02, Q03, EA, card, registry row, or basket manifest was created.

## Capacity and Safety

At the post-handoff scan, no T1-T10 factory terminal or terminal worker was running. `FACTORY_OFF.flag` remained present and `launch_gate_max=1`, so the CPU ceiling was not reached and no additional backtest was started. Existing non-factory terminal processes, including `T_Live`, were observed only by the read-only slot scan and were not touched.

No `T_Live` path, AutoTrading state, deploy/live manifest, portfolio gate, `portfolio_admission`, portfolio KPI, or Q08 contribution path was changed.

Machine-readable evidence: `artifacts/qm5_13119_repaired_q02_pass_q03_handoff_20260711.json`.
