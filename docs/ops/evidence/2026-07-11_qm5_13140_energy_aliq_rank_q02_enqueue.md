# QM5_13140 Energy ALIQ Rank - Q02 Enqueue Evidence

**Date:** 2026-07-11
**Branch:** agents/board-advisor
**EA:** QM5_13140_energy-aliq-rank
**Strategy ID:** YIYI-ALIQ-2025_XTI_XNG_S01

## Outcome

A new structural, low-frequency energy sleeve was carded, atomically
allocated, built, and left pending in Q02. The EA ranks XTI and XNG monthly by
the prior-12-completed-month mean of daily absolute log return divided by
same-day MT5 tick volume. It buys the higher-ALIq leg and shorts the lower-ALIq
leg with equal fixed-risk shares.

This is a cross-sectional illiquidity-premium carrier, not the existing XNG
RSI pullback, a liquidity-shock reversal, commodity momentum, trend,
seasonality, value, beta, IVOL, skew, semivariance, MAX, kurtosis, variance
ratio, or coefficient-of-variation rank. Realized portfolio decorrelation
remains a later measurement, not a build claim.

## Source And Card Evidence

- Canonical source: Qin, Cai, Zhu, and Webb (2025), "Commodity Futures
  Characteristics and Asset Pricing Models," Journal of Futures Markets
  45(3), 176-207, DOI 10.1002/fut.22559.
- The complete open paper, appendices, tables, and bibliography were read end
  to end.
- Source packet:
  strategy-seeds/sources/YIYI-ALIQ-2025/source.md.
- Card of record:
  strategy-seeds/cards/energy-aliq-rank_card.md.
- G0 and schema lints: PASS; R1-R4: PASS under the OWNER mission directive.
- Pre-allocation dedup: CLEAN for slug energy-aliq-rank and strategy ID
  YIYI-ALIQ-2025_XTI_XNG_S01. Manual review distinguished the monthly level
  premium from QM5_10330 and cs-spread-rev short-run reversals.

The source uses daily dollar volume across 34 exchange-traded commodity
futures. The EA substitutes broker tick volume and ranks two continuous CFDs.
That proxy and breadth loss are binding Q02 kill risks. The paper's IPCA model
is not implemented, and no source return statistic is imported.

## Locked Mechanic

1. On the first tradable XTI D1 bar of each broker month, select D1 bars from
   exactly the prior 12 completed calendar months for XTI and XNG.
2. Require every expected month and at least 220 valid observations per leg.
3. Compute daily absolute log return divided by same-day tick volume,
   multiplied by 1,000,000, and take the arithmetic mean.
4. Buy the higher-ALIq leg and short the lower-ALIq leg.
5. Split RISK_FIXED=1000 equally and apply a frozen D1 ATR(20) times 3.5 hard
   stop to each leg.
6. Close at the next monthly transition or after 40 days; repair an orphan or
   invalid package immediately.
7. Use position and deal history to prevent a second package in the same
   month after a restart or stop.

A missing month, nonpositive tick volume or close, numerical tie, invalid
arithmetic, excess spread, or incomplete package fails closed.

## Identity And Registry Evidence

- Atomic EA reservation:
  13140,energy-aliq-rank,YIYI-ALIQ-2025_XTI_XNG_S01,active.
- Magic slot 0: XTIUSD.DWX to 131400000.
- Magic slot 1: XNGUSD.DWX to 131400001.
- The clean staged resolver retains 14,873 rows and both 13140 magic values.
- Staged magic-registry SHA256:
  7BA7584C9858C45111A89680D25627DADC2F0916CDB80D5A3D700141F1AAE30D.
- Resolver-file SHA256:
  47A3C717E2BA3011D9E2B6C8D43F3A1BDE4F41501869B0F6D6B57EE78AE4050D.

The resolver preserves the pre-existing QM5_13122 row and drops only the
three historical missing-directory IDs 1001, 1015, and 1016. Unrelated dirty
fleet registry rows are not part of this staged change.

## Q01 Build Evidence

- Build artifact commit: 9565e32d9.
- EA source:
  framework/EAs/QM5_13140_energy-aliq-rank/QM5_13140_energy-aliq-rank.mq5.
- Compiled artifact:
  framework/EAs/QM5_13140_energy-aliq-rank/QM5_13140_energy-aliq-rank.ex5.
- Strict clean-staged-resolver compile: PASS, 0 errors, 0 compiler warnings.
- Compile log:
  C:/QM/worktrees/codex-13140-index-20260711-0924/framework/build/compile/20260711_092610/QM5_13140_energy-aliq-rank.compile.log.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  D:/QM/reports/framework/21/build_check_20260711_092034.json.
- Card schema and G0 lints: PASS.
- Targeted SPEC validator: PASS.
- Build guardrails: PASS.
- Symbol-scope validator: BASKET_OK.
- MQ5 SHA256:
  AAE0E65EFF3EAF72EACF1CD2D3BE41CEC38426AD725E95EADB653B13FFF60DE3.
- EX5 SHA256:
  304278EFEE71B059272899365B70A63C1B2C22F1D7A748A19F69FE17197D09AA.

## Risk And Setfile Evidence

- Logical symbol: QM5_13140_XTI_XNG_ALIQ_D1; host XTIUSD.DWX, D1.
- Setfile:
  framework/EAs/QM5_13140_energy-aliq-rank/sets/QM5_13140_energy-aliq-rank_QM5_13140_XTI_XNG_ALIQ_D1_D1_backtest.set.
- Setfile SHA256:
  3EFB6EFA0FA6F3D013D7485F7ACDE64B5CC4C1C55C3E648DF1484A9D082B4FE8.
- Setfile build hash:
  aae0e65eff3eaf72eacf1cd2d3be41cec38426ad725e95eadb653b13fff60de3.
- RISK_FIXED=1000, RISK_PERCENT=0, PORTFOLIO_WEIGHT=1.
- Friday close is disabled only for the source-aligned monthly hold.

## Q02 Queue Evidence

- Build task: 337f6ff8-9124-4d63-ad64-f7b32c7770fc, done.
- Work item: c0a7b2d3-2134-4334-b118-abf5c0986b0e.
- Phase: Q02; kind: backtest.
- Logical basket: QM5_13140_XTI_XNG_ALIQ_D1.
- Host/timeframe: XTIUSD.DWX, D1.
- Status at verification: pending.
- Attempt count: 0; claimed by: none.
- Enqueued at: 2026-07-11T09:29:06+00:00.
- Queue path: record_build_result.auto_q02.

No manual smoke, tester, terminal launch, dispatch tick, worker tick, or
backtest was started. This work consumed no backtest CPU and left paced Q02
dispatch intact.

## Safety Boundary

- No T_Live path changed.
- No AutoTrading setting changed.
- No live setfile or deploy manifest was created.
- No portfolio gate, gate threshold, portfolio KPI, admission file, or T_Live
  manifest was changed.
