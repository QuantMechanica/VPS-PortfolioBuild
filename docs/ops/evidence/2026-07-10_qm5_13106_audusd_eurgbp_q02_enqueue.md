# QM5_13106 AUDUSD/EURGBP Cointegration Q02 Enqueue

Date: 2026-07-10  
Branch: `agents/board-advisor`

## Outcome

One new non-duplicate FX sleeve was carded, built, compiled, and enqueued as a
logical basket Q02 row:

- EA: `QM5_13106_aud-eurgbp-coint`
- Logical symbol: `QM5_13106_AUDUSD_EURGBP_COINTEGRATION_D1`
- Q02 work item: `78e5573f-9b83-42fc-8cbc-04125c4e42f1`
- Handoff state: `pending`, unclaimed
- Host: `AUDUSD.DWX`, D1
- Traded legs: `AUDUSD.DWX`, `EURGBP.DWX`
- Conversion/history-only symbol: `GBPUSD.DWX`
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

No manual MT5 run was launched. At handoff the farm had seven active paced
workers and 4,640 pending rows, so this pass stopped at the backtest CPU ceiling.

## Selection Evidence

The published positive-hedge scan contains only the already-built strict
anchors `QM5_12533` and `QM5_12532`. An all-sign reproduction of the same
66-pair scan makes AUDUSD/EURGBP the highest OOS-ranked strict row not already
built after the existing anchors and `QM5_12978`/`QM5_13003`:

| Metric | Value |
|---|---:|
| DEV net Sharpe | 0.5535928822 |
| OOS net Sharpe | 1.0472370393 |
| OOS return | 10.86473973% |
| OOS state changes | 25 |
| Fixed DEV beta | -0.05457637365 |
| Half-life | 112.5038 days |

The small negative beta is documented as a directional-risk caveat. It was not
hidden or compensated with a new filter; downstream gates remain the judge.

## Build Artifacts

- Approved card:
  `strategy-seeds/cards/approved/QM5_13106_aud-eurgbp-coint_card.md`
- EA source and binary:
  `framework/EAs/QM5_13106_aud-eurgbp-coint/`
- Basket manifest declares AUDUSD, EURGBP, and GBPUSD conversion history.
- Magic slots: `131060000` AUDUSD, `131060001` EURGBP.
- Build evidence: `artifacts/qm5_13106_build_result.json`.

## Verification

- Dedup check: `CLEAN` before allocation.
- Atomic EA-ID allocation: `QM5_13106`.
- Card schema lint: `PASS`.
- SPEC validation: `PASS`.
- Symbol-scope validation: `BASKET_OK`, zero violations.
- Strict MetaEditor compile: `PASS`, 0 errors, 0 warnings.
- Local build check: `PASS`, 0 failures, 0 warnings.
- Q02 auto-enqueue: one row enqueued, zero skipped.

The repository-wide registry validator and research audit still report
pre-existing legacy-row defects unrelated to QM5_13106; those global files were
not repaired or normalized in this pass.

## Guardrails

- No `T_Live` or AutoTrading action.
- No live setfile or deploy manifest.
- No portfolio-admission, portfolio-KPI, or Q08-contribution change.
- No portfolio gate code touched.
- Existing unrelated dirty worktree paths were left untouched.

