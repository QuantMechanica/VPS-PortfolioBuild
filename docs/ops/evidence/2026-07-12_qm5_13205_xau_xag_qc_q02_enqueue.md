# QM5_13205 XAU/XAG Conditional Quantile Basket - Q02 Enqueue Evidence

**Date:** 2026-07-12

**Branch:** agents/board-advisor

**EA:** QM5_13205_xau-xag-qc

**Status:** Q01 PASS; one logical XAU/XAG Q02 item pending

## Edge and evidence boundary

The structural carrier is Schweikert (2018), "Are gold and silver
cointegrated? New evidence from quantile cointegrating regressions,"
*Journal of Banking & Finance* 88, 44-51.

- DOI: https://doi.org/10.1016/j.jbankfin.2017.11.010
- Complete author preprint:
  https://karstenschweikert.github.io/qcoint/qcoint_20171121_preprint.pdf

The complete 32-page preprint was reviewed. It supplies quantile-varying
gold/silver intercepts and slopes estimated by asymmetric check loss, but it
does not publish a profitable forecast or trading rule. Important constant
cointegration specifications fail, some daily/futures upper quantiles are
fragile, the state is not known ex ante, and the paper cautions against a
constant-coefficient statistical-arbitrage spread. Those findings are adverse
prior evidence and remain Q02 kill risks.

The EA is a disclosed QM mechanization: monthly exact constrained simple
quantile regressions at 10%, 50%, and 90% on 504 synchronized completed
log-price pairs, with the newest completed pair held out; weekly tail-envelope
entries; conditional-median/time/hard-stop exits; and beta-target dollar
notionals jointly scaled to one fixed-risk package.

## Non-duplicate decision

The load-bearing mechanic is a quantile-specific intercept and slope selected
by asymmetric check loss. Repository and history searches found no existing
conditional-quantile-regression or check-loss strategy.

Existing XAU/XAG families instead use fixed log-ratio z-scores, return-spread
z-scores, OLS residual/half-life logic, raw-ratio channels, stochastic
oscillators, fixed-beta deviation envelopes, or a Kalman hedge ratio. Replacing
the check-loss coefficients with one of those methods is outside the approved
card and would collapse this EA into an existing family.

Verdict: `CLEAN_PRE_ALLOCATION`.

## Locked mechanical baseline

1. At each broker-month transition, anchor history at the first XAU host D1
   bar, reserve the newest completed synchronized pair as the signal, and fit
   the older 504 pairs.
2. Estimate `ln(XAG) = alpha_tau + beta_tau*ln(XAU)` at
   `tau={0.10,0.50,0.90}` by exact constrained pairwise-slope/check-loss
   minimization.
3. Reject boundary betas, crossed conditional lines, a signal tail width below
   0.010, or `beta_90 <= beta_10 + 0.05`.
4. Above q90, buy XAU and sell XAG; below q10, sell XAU and buy XAG. Target
   XAU:XAG dollar notionals of beta:1.
5. Jointly scale both legs so combined frozen `ATR(20)*4` stop risk is no more
   than `RISK_FIXED=1000`; reject post-rounding hedge error above 20%.
6. Evaluate entries and median exits weekly, allow one persisted attempt per
   broker week, close after 70 days, and repair any orphan or invalid package.
7. A mid-month restart reconstructs the exact original month-anchored model;
   it never slides the formation endpoint.

Expected density is 6-12 completed packages/year after warm-up. Retire below
the binding five-package/year Q02 floor.

## Identity and Q01 build evidence

- EA reservation:
  `13205,xau-xag-qc,SCHWEIKERT-QC-2018_XAU_XAG_S01,active`.
- Magic slot 0: XAUUSD.DWX to `132050000`.
- Magic slot 1: XAGUSD.DWX to `132050001`.
- Build commit:
  `eb668adde587582aaebda5b6db4ddcec6f330837`.
- Strict compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 0 warnings.
- Card/G0, SPEC, build guardrails, and basket symbol scope: PASS.
- Independent semantic re-audit: PASS after resolving month-model restart,
  failed-attempt persistence, lifecycle ordering, parameter authorization,
  envelope-width fidelity, and phase-state findings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260712_190104/QM5_13205_xau-xag-qc.compile.log`.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260712_190104.json`.
- MQ5 SHA256:
  `76972C494B91BBFDCFE6A62384E9050DB9E5DFE221F7251C6FECAE2838B8771B`.
- EX5 SHA256:
  `D5D7BF2C37F3F6005BE769F18530CD8AE523D33FFD0AD34ACFD9E04A3053AF74`.
- Resolver registry SHA match: PASS
  (`F5C513740F19213D9EB0ED9696D4D8CEEC40C63C1C36CE533C25D4DACCF86C1F`).

## Risk and logical-basket evidence

- Logical symbol/timeframe: QM5_13205_XAU_XAG_QC_D1 / D1.
- Runner host: XAUUSD.DWX / D1.
- Traded legs: XAUUSD.DWX and XAGUSD.DWX.
- One logical setfile:
  `framework/EAs/QM5_13205_xau-xag-qc/sets/QM5_13205_xau-xag-qc_QM5_13205_XAU_XAG_QC_D1_D1_backtest.set`.
- Setfile SHA256:
  `F1668B54B120825A5B4D80736081F8C7E00A5156B8188A20AC3AFEF0F4A3B07E`.
- Setfile build hash:
  `8195bf0199d5392ecdf086c8e85645b20495297e7798b4b547909e1956db7602`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- No live setfile exists.

## Q02 queue evidence

- Build task: `2774ef4d-0a43-47e6-b5ff-abf01a614630`, done.
- Work item: `be5ffa78-fdfb-4718-af89-5f7fc7e8dee3`.
- Phase/kind: Q02 / backtest.
- Logical symbol/timeframe: QM5_13205_XAU_XAG_QC_D1 / D1.
- Status at handoff: pending, attempt 0, unclaimed.
- Enqueued at: `2026-07-12T19:07:11+00:00`.
- `farmctl record-build` enqueued one logical basket item and skipped none.

No dispatch tick, worker tick, terminal launch, smoke test, or backtest was
started. No backtest CPU slot was consumed, so the CPU ceiling was not
encountered; Q02 owns the first CPU-bearing validation pass.

## Safety and kill boundary

- Structural D1 price arithmetic and ATR safety stops only; no banned
  indicator, ML, external runtime signal, grid, martingale, or pyramiding.
- No T_Live artifact, AutoTrading action, deploy manifest, T_Live manifest,
  portfolio gate, portfolio admission, or portfolio KPI path was touched.
- The paired carrier has market-neutral intent but does not establish realized
  neutrality or book decorrelation. Later portfolio gates alone may measure
  those properties if the EA first survives its own pipeline.
