# QM5_13119 USDJPY/EURAUD Cointegration Q02 Enqueue

Date: 2026-07-10

Branch: `agents/board-advisor`

## Outcome

One new, non-duplicate FX sleeve was selected from the OWNER-requested
66-pair scan, carded, built as a logical basket, strict-compiled, and enqueued
to Q02:

- EA: `QM5_13119_usdjpy-euraud`
- Strategy ID: `SRC02_S10`
- Logical symbol: `QM5_13119_USDJPY_EURAUD_COINTEGRATION_D1`
- Q02 work item: `f8767f2f-4bcb-4b32-b857-cf9063b1c935`
- Handoff state: `pending`, unclaimed
- Host: `USDJPY.DWX`, D1
- Traded legs: `USDJPY.DWX`, `EURAUD.DWX`
- Conversion/history-only symbol: `AUDUSD.DWX`
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

No manual MT5 run or dispatch was launched. At handoff the paced farm had
seven active work items, equal to the mission's CPU ceiling, so smoke was
deferred and work stopped after the pending Q02 enqueue.

## Priority Check

The two proven anchors are not Q02 setup blockers:

- `QM5_12532`: logical Q02 PASS, Q04 PASS, terminal Q05 FAIL.
- `QM5_12533`: logical Q02 PASS, terminal Q04 FAIL.

Neither has an open ONINIT or NO_HISTORY Q02 row to repair. The prior cycle had
already built EURGBP/AUDJPY as `QM5_13117`, so USDJPY/EURAUD was selected as
the next and final strict row from the sign-aware reproduction. Repository
dedup was clean before atomic allocation.

## Selection Evidence

Command:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

| Metric | Value |
|---|---:|
| DEV net Sharpe | 0.5059112597 |
| OOS net Sharpe | 0.8837435895 |
| OOS return | 16.014828283% |
| OOS state changes | 23 |
| Fixed DEV beta | -1.4182482312 |
| Half-life | 77.45654457 D1 bars |

The negative beta, same-direction packages, cross-bloc relationship, marginal
OOS threshold clearance, long half-life, and unmodeled swap remain explicit
high-risk caveats. No adaptive refit, regime filter, carry filter, banned
indicator, grid, martingale, or ML component was added.

## Build Artifacts

- Approved card:
  `strategy-seeds/cards/approved/QM5_13119_usdjpy-euraud_card.md`
- EA source, binary, SPEC, setfile, and basket manifest:
  `framework/EAs/QM5_13119_usdjpy-euraud/`
- Build evidence: `artifacts/qm5_13119_build_result.json`
- Magic slots: `131190000` USDJPY, `131190001` EURAUD.

The basket manifest declares AUDUSD only for USD-account conversion/history
warmup. It is not traded and therefore has no EA magic slot.

## Verification

- Atomic EA-ID allocation: `QM5_13119`.
- Card schema lint: PASS.
- SPEC validation: PASS.
- Symbol-scope validation: BASKET_OK, zero violations.
- Strict MetaEditor compile: PASS, 0 errors, 0 warnings.
- Local build check: PASS, 0 failures, 0 warnings.
- Canonical logical setfile: `RISK_FIXED=1000`,
  `RISK_PERCENT=0`.
- Q02 auto-enqueue: one row created, zero duplicates.
- Smoke: deferred at the seven-active-job CPU ceiling.

## Safety

No `T_Live`, AutoTrading, deploy/live manifest, portfolio gate,
`portfolio_admission`, portfolio KPI, or Q08 contribution path was modified.

