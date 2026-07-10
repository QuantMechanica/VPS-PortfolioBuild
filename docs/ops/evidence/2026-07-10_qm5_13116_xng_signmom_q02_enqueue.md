# QM5_13116 XNG Return-Sign Momentum Q02 Enqueue Evidence

Date: 2026-07-10

Branch: `agents/board-advisor`

## Outcome

`QM5_13116_xng-signmom` was extracted, approved, allocated, built, validated,
and enqueued to Q02 on `XNGUSD.DWX` D1.

- Work item: `d3bef250-99ff-492c-b737-5eba646cff3e`
- Status at handoff: `pending`, unclaimed
- Build task: `0d5c807a-471e-4b8f-b846-230d2f804b95`, `done`
- Strict compile: `PASS`, 0 errors, 0 warnings
- Build check: `PASS`, 0 failures, 0 warnings
- Magic: slot 0, `131160000`, resolver verified
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

## Edge Boundary

The EA implements the fixed return-sign momentum rule from Papailias, Liu, and
Thomakos (2021), *Journal of Banking & Finance* 124, Article 106063. On each
monthly renewal it counts non-negative monthly returns in the prior 12 completed
months. It buys XNG when the fraction is at least 0.40 and sells otherwise.

This differs from `QM5_12567` at every signal dimension: monthly versus daily,
sign persistence versus RSI pullback, symmetric long/short versus long-only,
one-month hold versus five D1 bars, and no SMA(200) filter. It also differs from
the conventional cumulative-return XNG momentum, reversal, breakout,
seasonality, event, carry, ratio, and spread families already built.

Source record:

- DOI: https://doi.org/10.1016/j.jbankfin.2021.106063
- Accepted manuscript:
  https://pureadmin.qub.ac.uk/ws/files/229452162/RSM_011220.pdf
- Local source packet:
  `strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md`

The full manuscript and Appendices A-I were read. Natural gas is explicit in
the paper's commodity panel and individual-instrument tables. The futures-to-CFD
translation and portfolio-to-single-carrier reduction remain Q02 falsification
risks; no source result is treated as V5 evidence.

## Validation Evidence

- Compile log:
  `framework/build/compile/20260710_142810/QM5_13116_xng-signmom.compile.log`
- Compile summary: `D:/QM/reports/compile/20260710_142810/summary.csv`
- Build check report:
  `D:/QM/reports/framework/21/build_check_20260710_142824.json`
- Machine build record: `artifacts/qm5_13116_build_result.json`
- Queue record: `artifacts/qm5_13116_q02_enqueue_20260710.json`

## CPU And Safety Boundary

At `2026-07-10T14:28:50Z`, path-anchored pipeline terminals T1, T3, T4, T6,
and T8 were active. The paced-fleet CPU guard therefore deferred manual smoke
and launched no MT5 process or backtest. `record-build` only created the pending
Q02 work item for normal worker dispatch.

No live setfile, `T_Live`, AutoTrading, deploy/T_Live manifest, portfolio gate,
portfolio admission, or portfolio KPI file was read-modified-written by this
mission.
