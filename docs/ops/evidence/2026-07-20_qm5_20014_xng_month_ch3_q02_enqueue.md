# QM5_20014 Natural Gas Monthly CH3 - Q02 Enqueue Evidence

**Date:** 2026-07-20

**Branch:** agents/board-advisor

**EA:** QM5_20014_xng-month-ch3

**Status:** Q01 PASS; one XNGUSD.DWX Q02 item pending

## Edge And Source Boundary

The carrier implements the monthly channel rule tested by Szakmary, Shen and
Sharma (2010), *Trend-following trading strategies in commodity futures: A
re-examination*, Journal of Banking & Finance 34(2), 409-426, DOI
`10.1016/j.jbankfin.2009.08.004`. The peer-reviewed journal record is at
https://www.sciencedirect.com/science/article/pii/S037842660900199X. The
authors' complete accessible manuscript includes Natural Gas in its commodity
sample and defines the tested channel horizons `L={3,6,9,12}`, strict
prior-month extrema, a flat inside state and a one-month holding period:
https://www.researchgate.net/profile/Andrew-Szakmary/publication/267715955_Price_Momentum_and_Trading_Volume_In_Commodity_Futures_Markets/links/556dae9d08aeccd7773d7aca/Price-Momentum-and-Trading-Volume-In-Commodity-Futures-Markets.pdf.

The Q02 baseline locks `L=3`. On the first D1 bar of a new broker month it
reconstructs four completed Natural Gas month-end closes. It buys when the
latest completed close is strictly above all prior three, sells when strictly
below all prior three, and otherwise remains flat. Every package closes before
the next monthly renewal. A frozen `4.0 * ATR(20)` hard stop and 35-day stale
guard are the only signal-adjacent V5 risk additions.

Six completed entry packages/year is a conservative card prior, not a local
performance result. Q02 must measure actual cadence and expectancy.

## Non-Duplicate Decision

Gold/silver ratio reversion was rejected because `QM5_12577` already implements
the proposed log-ratio z-score basket and several adjacent XAU/XAG builds exist.
The remaining pure WTI three-month momentum gap is a carrier port of a common
TSMOM family already present on XAU and at several WTI horizons.

No XNG card or EA was found that compares a completed month-end close with the
extrema of the prior three completed month-end closes. The abstract rule family
is not claimed as new: `QM5_20008_wti-month-ch3` is the disclosed WTI carrier.
This XNG carrier is materially different from `QM5_12567`'s cumulative-RSI(2)
pullback above a 200-day filter and short lifecycle, and from `QM5_20013`'s
two-month contrarian return-sign package. Realized correlation remains an
unproven later-phase gate.

## Identity And Q01 Evidence

- EA reservation: `QM5_20014`, strategy `SZAKMARY-XNG-MCH3-2010`.
- Magic slot 0: `XNGUSD.DWX` to `200140000`.
- Resolver retains 14,951 rows and embeds magic-registry SHA256
  `BC1E7CDD5A63155585F1A7B3CA5F177BFFDFDD200455BD30E845075491552CC5`.
- Build/card commits: `a0964570a`, `3c3edad34`, `bae5d56c9`, and
  `80d25f46b`.
- Strict compile: PASS, 0 errors, 0 warnings; log
  `C:/QM/repo/framework/build/compile/20260720_044142/QM5_20014_xng-month-ch3.compile.log`.
- Build check: PASS, 0 failures, 0 warnings; report
  `D:/QM/reports/framework/21/build_check_20260720_044142.json`.
- SPEC validation, card/G0 preflight and build guardrails: PASS.
- MQ5 SHA256:
  `4970F3529444C9AD54D69DC303CDD630062FE913BAEEF802E23C97A26D8A1438`.
- EX5 SHA256:
  `F31D4E7CA2AAE3E3F2EEA94598C815CAD5890964952C3C84A628118FB6306EFF`.

## Risk And Q02 Queue Evidence

- Setfile:
  `framework/EAs/QM5_20014_xng-month-ch3/sets/QM5_20014_xng-month-ch3_XNGUSD.DWX_D1_backtest.set`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Setfile build hash:
  `fc1cc069c2e2f4e10fd1dec0769fa423d19c0b155ab07d0ea5cc13b5cea68120`.
- Build task `35c924e1-3fa4-460c-8c39-1f83aabffa35`: done.
- Q02 work item `bf4b07c5-7e13-4cdf-8939-b8f99ab09fed`: pending,
  attempt 0, unclaimed, `XNGUSD.DWX` D1.
- Enqueued at `2026-07-20T04:40:09+00:00` by `farmctl record-build`;
  one item enqueued, none skipped.

The paced-fleet scan reached ten terminal64 and eight metatester64 processes.
Smoke was recorded as `deferred_p2_smoke`; no dispatch tick, worker tick,
terminal launch, tester run, optimization or backtest was started by this
mission.

## Safety And Falsification Boundary

- Structural monthly price arithmetic only; no banned indicator or ML.
- No live setfile, T_Live artifact, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio gate, portfolio admission or KPI was touched.
- The source uses commodity futures, while this build uses a continuous
  Darwinex Natural Gas CFD plus an ATR risk overlay. Transfer, costs, gaps,
  expectancy, drawdown and realized correlation to the certified book remain
  unproven kill risks. Q02 and later portfolio gates—not this build—must measure
  them.
