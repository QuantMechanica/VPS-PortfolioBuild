# QM5_13057 diversity build rework

Date: 2026-08-16

Branch: `agents/board-advisor`

Farm build task: `123f5903-1555-441c-a0fa-7355d11f3556`

Fleet claim: `c1bb2eec-8b47-4e0f-8494-613450fd35f0`

## Outcome

`QM5_13057_xti-gbpcad-rspr` is a D1, low-frequency, two-leg energy/FX
return-spread sleeve on `XTIUSD.DWX` and `GBPCAD.DWX`. The code-review blocker
was repaired: the XTI host leg now enters through `QM_TM_OpenPosition`, while
the registered GBPCAD satellite remains on `QM_BasketOpenPosition`.

The host call uses the framework's explicit risk-mode/value overload with the
same proportional basket allocation used by the satellite. The aggregate
configured risk therefore remains the card-authorized `RISK_FIXED=1000`
budget rather than assigning a full risk budget to each leg.

## Governed preflight

- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_13057_xti-gbpcad-rspr.md`
- Card status: `g0_status: APPROVED`
- EA registry: `13057,xti-gbpcad-rspr,...,active`
- Magic registry: slot 0 `XTIUSD.DWX` / `130570000`; slot 1 `GBPCAD.DWX` / `130570001`
- Slug length: 15; EA folder/file name: 25 characters
- Strategy remains structural, non-ML, D1, and sourced from EIA and Bank of Canada research.
- Logical Q02 setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Verification

- Strict compile: PASS, 0 errors, 0 warnings
- Compile log: `framework/build/compile/20260816_112227/QM5_13057_xti-gbpcad-rspr.compile.log`
- Compile summary: `D:/QM/reports/compile/20260816_112227/summary.csv`
- Targeted strict build check: PASS, 0 failures, 0 warnings
- Build-check report: `D:/QM/reports/framework/21/build_check_20260816_112453.json`

SHA-256 bindings:

- MQ5: `be5c85b878116ab9b4a89794dff82078cc87fb616ac7dd5f9fa98cc42724c9cd`
- EX5: `c48c0507d3c3c10c4c3af80d2546bad20ab88fb13deeba0f818818be983ed690`
- SPEC: `e5d1a83e39b67efab228d7bbe887ef84cbb0627323119f43af0bb0b05cc7b286`
- Logical Q02 setfile: `643eff007c05637c0fe5105615a6f0b94ba5a37af6b3487ca67e1eff691a1b01`
- Approved card: `9f6d33fdcd1f15448143d0daa271ff504d36c4955e406c5a9a0380718ddf37b6`

## Q02 capacity deferral

No smoke test, tester run, dispatch tick, optimization, or backtest was
started. At `2026-08-16T11:26:17Z`, `farmctl mt5-slots` showed active tester
processes on T3, T4, T6, T7, and T8. Three host CPU samples averaged 99.9%, so
the mission's backtest-CPU-ceiling stop condition applied. Q02 was deliberately
not enqueued from this unit.

When capacity is below the ceiling, the next deterministic action is to record
the current build result for build task `123f5903-1555-441c-a0fa-7355d11f3556`;
the canonical `record-build` transition will enqueue the logical
`QM5_13057_XTI_GBPCAD_RSPREAD_D1` Q02 work item.

## Live-safety boundary

No `T_Live` file, AutoTrading setting, deploy manifest, live manifest,
portfolio gate, or portfolio-admission artifact was touched.
