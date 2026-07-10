# QM5_13117 EURGBP/AUDJPY Cointegration Q02 Enqueue

Date: 2026-07-10

Branch: `agents/board-advisor`

## Outcome

One new non-duplicate FX sleeve was advanced from its reviewed card, built,
strict-compiled, and enqueued as one logical basket Q02 row:

- EA: `QM5_13117_eurgbp-audjpy`
- Logical symbol: `QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1`
- Q02 work item: `ed75430e-2ff4-4ea1-9d50-e49a7912d323`
- Handoff state: `pending`, unclaimed
- Host: `EURGBP.DWX`, D1
- Traded legs: `EURGBP.DWX`, `AUDJPY.DWX`
- Conversion/history-only symbols: `GBPUSD.DWX`, `USDJPY.DWX`
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

No manual MT5 run or dispatch was launched. At handoff the paced farm had
seven active work items, equal to the mission's CPU ceiling, so Q01 smoke was
deferred and this pass stopped after the pending Q02 enqueue.

## Priority Check

The two proven strict positive-hedge anchors are not Q02 setup blockers:

- `QM5_12532` has a logical Q02 PASS, Q04 PASS, and terminal Q05 FAIL.
- `QM5_12533` has a logical Q02 PASS and terminal Q04 FAIL.

Neither had an open ONINIT/NO_HISTORY Q02 row to repair. The existing
EURGBP/AUDJPY draft was therefore the next concrete pair to mechanize. No
registry row or EA folder for that pair existed before atomic allocation.

## Selection Evidence

The sign-aware reproduction of the OWNER-requested 66-pair scan reports:

| Metric | Value |
|---|---:|
| DEV net Sharpe | 0.4168335930 |
| OOS net Sharpe | 0.8918614046 |
| OOS return | 4.475153414% |
| OOS state changes | 20 |
| Fixed DEV beta | -0.12202869296345396 |
| Half-life | 36.83805248 D1 bars |

The negative, small hedge and cross-bloc relationship remain explicit
high-risk caveats. No filter, adaptive refit, or parameter was added to hide
them; Q02 onward remains the judge.

## Build Artifacts

- Approved card:
  `strategy-seeds/cards/approved/QM5_13117_eurgbp-audjpy_card.md`
- EA source, binary, SPEC, setfile, and basket manifest:
  `framework/EAs/QM5_13117_eurgbp-audjpy/`
- Build evidence: `artifacts/qm5_13117_build_result.json`
- Magic slots: `131170000` EURGBP, `131170001` AUDJPY.

The basket manifest declares GBPUSD and USDJPY only for USD-account
conversion/history warmup. They are not traded and therefore have no EA magic
slots.

## Verification

- Atomic EA-ID allocation: `QM5_13117`.
- Card schema lint: PASS.
- SPEC validation: PASS.
- Symbol-scope validation: BASKET_OK, zero violations.
- Strict MetaEditor compile: PASS, 0 errors, 0 warnings.
- Local build check: PASS, 0 failures, 0 warnings.
- Canonical logical setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Q02 auto-enqueue: one row created, zero duplicates.
- Q01 smoke: deferred at the seven-active-job CPU ceiling.

## Safety

No `T_Live`, AutoTrading, T_Live/deploy manifest, portfolio gate,
`portfolio_admission`, portfolio KPI, or Q08 contribution path was modified.
