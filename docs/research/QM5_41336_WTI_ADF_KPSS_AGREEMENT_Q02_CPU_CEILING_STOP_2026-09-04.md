# QM5_41336 WTI ADF-KPSS Agreement — Q02 CPU-Ceiling Stop

**Date:** 2026-09-04  
**Branch:** `agents/board-advisor`  
**Outcome:** new non-duplicate commodity edge carded and source-built; governed
compile enqueued; stopped before Q02 because the binding CPU ceiling was hit.

## Edge delivered

`QM5_41336_wti-adf-kpss-agree-tr` is a direct `XTIUSD.DWX` D1 energy sleeve.
Once per broker month it reconstructs 60 completed monthly log closes. It trades
the newest 12-month return direction only when both independent state tests pass:

- lag-one, intercept-only ADF t statistic is inclusively at least `-2.594`;
- constant-only KPSS with four Bartlett covariance lags is inclusively at least
  `0.347`.

The conjunction is distinct from the existing single-ADF and single-KPSS EAs.
Deterministic ADF-only and KPSS-only disagreement vectors both remain flat. The
sole backtest set is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with a frozen ATR(20) x 3.5 stop and monthly lifecycle.

## Durable repository evidence

- source approval: `3913751920`
- approved card and G0: `d9c86dc43d`
- EA identity reservation: `a999121528`
- magic/resolver allocation: `5fa00f30a5`
- governed build-authority mirror: `4a87579e1d`
- MQ5, SPEC, oracle, and fixed-risk set: `67ce3bc876`
- MQ5 SHA-256:
  `A44763CE85B4F471F4E2F5C96E782780406C78E7ECB883D2E61898A235B6F7A2`
- setfile SHA-256:
  `E7D14C5F347CAEA849CB43BCA19BDCCA739CC5031F41CEE526CC1C77264C72E0`
- approved-card SHA-256:
  `EB9170A593D715A1C128BADA12970AC568991D001951E7F5B4AD4332E56AB219`

Verification before the stop:

```text
python -m unittest .../test_wti_adf_kpss_agree_tr_reference.py
Ran 9 tests — OK

python framework/scripts/validate_spec_doc.py \
  framework/EAs/QM5_41336_wti-adf-kpss-agree-tr
PASS (1/1)

python framework/scripts/skill_card_schema_lint.py --card ...
status=ok; ml_hits=[]; missing_sections=[]
```

## Governed compile state

The local strict compile correctly refused the ad-hoc include mirror while
`terminal64` processes were alive (`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`). No
terminal was stopped, restarted, or bypassed. The canonical compile work item is:

- build task: `cd7a9e1c-3677-4168-be52-60badda01d21` (`pending`)
- compile work item: `0a80a328-3b81-4125-aa48-ed5686b7a962`
- compile status: `pending`
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`
- compile verdict / EX5 / evidence path: none yet

This is a safe fleet-capacity handoff, not a compile PASS or Q01 verdict.

## Binding CPU stop

At `2026-09-04T20:09Z`, the required fresh five-sample total-CPU series was:

```text
99.0255, 95.8011, 97.0021, 97.2709, 95.9090 percent
average = 97.0017 percent
maximum = 99.0255 percent
binding ceiling = 97 percent
```

The maximum exceeded the ceiling. Per the mission instruction, no backtest was
launched and Q02 was not enqueued. A read-only runtime audit found only the one
pending build task and the pending compile work item for `QM5_41336`; there is
no `QM5_41336` backtest task.

## Safe continuation boundary

Allow the canonical compile worker to consume the held item without terminal
interference. After strict `COMPILE_OK` and a fresh five-sample CPU check whose
maximum is below 97%, record/review the build and enqueue exactly the sole
`XTIUSD.DWX / D1 / RISK_FIXED=1000` set into Q02. Do not modify the portfolio
gate, T_Live manifest, AutoTrading, or the locked strategy parameters.
