# QM5_13151 Energy Smooth-Volatility Beta - Q02 Enqueue Evidence

**Date:** 2026-07-12

**Branch:** agents/board-advisor

**EA:** QM5_13151_energy-volbeta

**Status:** Q01 PASS; one logical XTI/XNG Q02 item pending

## Edge And Evidence Boundary

The edge is the continuous aggregate-volatility-beta characteristic in
Hollstein, Prokopczuk, and Tharann (2021), "Anomalies in Commodity Futures
Markets," *Quarterly Journal of Finance* 11(4), article 2150017.

DOI and journal record:
https://doi.org/10.1142/S2010139221500178

Complete institutional accepted manuscript and online appendix:
https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf

The complete 57-page document was reviewed. The paper explicitly includes WTI
and natural gas, estimates commodity characteristics from the prior twelve
months of daily observations, rebalances monthly, and reports a positive
3.56% annualized high-minus-low return for its continuous aggregate-
volatility-beta sort. The result does not clear the paper-wide multiple-
testing threshold; no source return, significance, drawdown, cost, or
correlation statistic is imported as QM evidence.

The source factor is option-derived and market-wide. QM5_13151 is an explicit
falsification using changes in a price-native two-contract energy benchmark's
realized volatility. It is not claimed as a replication.

## Locked Mechanical Baseline

On the first tradable XTIUSD.DWX D1 bar of broker month `t`:

1. Load 273 synchronized completed XTI and XNG closes and form 272 simple
   returns; current bars are excluded.
2. Use the latest 252 returns to lock inverse-volatility XTI/XNG benchmark
   weights and benchmark mean and standard deviation.
3. Form daily changes in the benchmark's rolling 20-return standard deviation;
   set the change to zero on benchmark-return innovations of at least two
   standard deviations.
4. Regress each leg on an intercept, benchmark return, and the smooth-
   volatility innovation. Require at least 200 non-jump observations.
5. Buy the higher smooth-volatility-beta leg and short the lower-beta leg,
   splitting `RISK_FIXED=1000` equally.
6. Attach frozen ATR(20) times 3.5 hard stops and close at the next broker-
   month transition or after 40 days. Position and entry-deal history prevent
   same-month re-entry; orphan composition closes immediately.

Expected density is approximately twelve completed packages/year after
warm-up. The binding Q02 floor is five packages/year.

## Non-Duplicate Decision

- `QM5_13147_energy-jumpbeta` estimates exposure to extreme common-return
  days and buys low jump beta. QM5_13151 excludes those days from its
  volatility innovation and buys high smooth-volatility beta.
- `QM5_13146_energy-vov` ranks dispersion of each leg's own rolling volatility
  level; it does not estimate sensitivity to common volatility changes.
- `QM5_13132_energy-bab` uses total return beta, low-beta direction, and
  inverse-beta sizing. `QM5_13133_energy-ivol` uses residual dispersion.
- Ratio, spread, carry, trend, calendar, return-sign momentum, and incumbent
  XNG RSI implementations use different mechanics and hypotheses.

Exact repository text search plus manual input/window/factor/direction review
found no smooth aggregate-volatility-beta build. Verdict:
`CLEAN_PRE_ALLOCATION`.

## Identity And Registry Evidence

- EA reservation:
  `13151,energy-volbeta,HOLLSTEIN-AGGVOL-2021_XTI_XNG_S01,active`.
- Magic slot 0: XTIUSD.DWX to `131510000`.
- Magic slot 1: XNGUSD.DWX to `131510001`.
- The committed resolver contains both mappings and retains 14,893 rows.
- Committed LF magic-registry SHA256:
  `96047053970221F6433B86AE6DF98C92B92CA5F270C05562D7A4C217CC681BA6`.
- Committed resolver SHA256:
  `89A1D4A7CC7267FCF641039C2002214BC53233B54582866095EDF330A1E16B77`.

The shared worktree contained unrelated fleet allocations before this build.
The feature commit was assembled from clean HEAD registry blobs plus only EA
13151. Resolver generation and final compilation used a `core.autocrlf=false`
isolated checkout, so the embedded registry digest matches the committed LF
registry exactly. The generator's same four pre-existing missing-directory
rows remained excluded; QM5_13151 added no new exclusion.

## Q01 Build Evidence

- Build commit:
  `c1282e11c4161ebe5b422922fbf2d77a85c9c0d6`.
- Strict compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 0 warnings.
- Preserved compile log:
  `D:/QM/reports/compile/20260712_040808/QM5_13151_energy-volbeta.compile.log`.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260712_040808.json`.
- Card schema/G0, SPEC, build guardrails, and basket-manifest scope: PASS.
- MQ5 SHA256:
  `036B90F22016941F3C3E87C85CA261CE93ECABA4F6FED4CA249DAC3463ACFC16`.
- Committed EX5 SHA256:
  `5CDA2A9B904E34E0503BC5335E9C7D76AB1C31BAD998DDCDADA99A38D38F33D5`.

No compile or resolver claim depends on unrelated working changes.

## Risk And Setfile Evidence

- Logical symbol/timeframe: QM5_13151_XTI_XNG_VBETA_D1 / D1.
- Runner host: XTIUSD.DWX / D1; traded legs: XTIUSD.DWX and XNGUSD.DWX.
- Setfile:
  `framework/EAs/QM5_13151_energy-volbeta/sets/QM5_13151_energy-volbeta_QM5_13151_XTI_XNG_VBETA_D1_D1_backtest.set`.
- Setfile SHA256:
  `81FDF86FF9422A6C53BC1E29ADC3A2DEF7EF4A85E583A8D4D42217F5D84EC14A`.
- Setfile build hash:
  `771cf55f01477f0a82def4140ecbd559c01c904f2602d8ad5423b7ca0b58439b`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the declared monthly hold.

## Q02 Queue Evidence

- Build task: `87b13690-2103-4e01-8b5c-d10219d3e17a`, done.
- Work item: `d792f306-3b9c-4ff6-b317-61c1137e6c92`.
- Phase/kind: Q02 / backtest.
- Logical symbol/timeframe: QM5_13151_XTI_XNG_VBETA_D1 / D1.
- Status at handoff: pending, attempt 0, unclaimed.
- Enqueued at: `2026-07-12T04:10:24+00:00`.
- `farmctl record-build` enqueued one logical basket item and skipped none.

No dispatch tick, worker tick, terminal launch, smoke test, or backtest was
started. No backtest CPU slot was consumed, so the backtest CPU ceiling was not
encountered; Q02 owns the first CPU-bearing validation pass.

## Safety And Kill Boundary

- Structural D1/monthly price arithmetic only; no ML or banned indicator.
- No live setfile, T_Live artifact, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio gate, portfolio admission, or portfolio KPI was
  touched.
- Multiple-testing weakness, option-to-realized substitution, endogenous
  two-name factor, narrow rank, return-based jump exclusion, futures/CFD basis,
  XNG gaps, legging, financing, and costs are kill risks, never waiver grounds.
- Opposite-side energy exposure and a distinct factor make diversification
  plausible; certification and realized book orthogonality remain unclaimed
  until later gates measure them.
