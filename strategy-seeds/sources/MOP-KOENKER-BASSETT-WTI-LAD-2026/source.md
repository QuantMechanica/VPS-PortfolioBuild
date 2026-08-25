---
source_id: MOP-KOENKER-BASSETT-WTI-LAD-2026
title: WTI thirteen-month least-absolute-deviation robust-trend extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading and statistical research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-25_wti_monthly_lad_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
  - SCHWEIKERT-QC-2018
  - MOP-WTI-THEILSEN-2026
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  SCHWEIKERT-QC-2018: 7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA
  MOP-WTI-THEILSEN-2026: F83880B74B1DB645F6C20A58B76825DA96787E327C461D0E798CA01CAB72535E
created: 2026-08-25
created_by: Research+Development
cards_extracted:
  - wti-lad-tr
---

# WTI Thirteen-Month Least-Absolute-Deviation Robust-Trend Source Packet

## Approved Sources Of Record

The trading source is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`.

The governed packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md`
preserves a complete read of the 23-page published paper from author Lasse
Heje Pedersen's NYU faculty site. Its retrieval receipt records PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
The packet itself has SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The statistical-method source is Karsten Schweikert (2018), "Are gold and
silver cointegrated? New evidence from quantile cointegrating regressions,"
*Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`. The governed packet
`strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md` records a complete read
of the 32-page author preprint, including its model, Koenker-Bassett
quantile-regression objective, empirical results, adverse findings,
appendix, and references. That packet has SHA-256
`7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`.
At the median quantile, symmetric check loss is one half of total absolute
vertical error; the factor one half does not change the minimizer.

The governed WTI endpoint and lifecycle precedent is
`strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md`, SHA-256
`F83880B74B1DB645F6C20A58B76825DA96787E327C461D0E798CA01CAB72535E`.
It fixes the direct-WTI carrier, thirteen consecutive completed month ends,
chronological log-price coordinate, monthly attempt, fixed risk, ATR stop,
spread cap, and next-month exit. Its global slope median does not transfer.

All bounded records were read completely before the durable OWNER source
approval at
`decisions/2026-08-25_wti_monthly_lad_trend_source_approval.md`, commit
`06d083b2d`. No blocked source body, inferred table value, or ungoverned
performance claim is used.

## Source Findings Used

- Section 3.1 of Moskowitz, Ooi, and Pedersen tests each instrument's own
  return at monthly lags one through sixty and reports positive continuation
  over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from own past
  returns and renews them monthly.
- Appendix A includes NYMEX WTI crude among the commodity futures.
- The source uses rolling liquid futures, excess returns, and ex ante
  volatility scaling; it does not test a Darwinex continuous CFD.
- Schweikert's Equation 10 estimates quantile-specific intercepts and slopes
  by minimizing Koenker-Bassett asymmetric check loss. Its governed extraction
  documents the exact simple-regression reduction to sorted pairwise-slope
  breakpoints and a residual empirical quantile for the intercept.
- Schweikert explicitly does not deliver an ex-ante profitable trading rule,
  reports important specification rejections, and warns against treating a
  constant relationship as safe arbitrage. Those adverse findings remain
  binding claim limits.

These findings support a falsifiable test of slow WTI own-price direction
through a median-regression slope. They do not establish this exact estimator,
its direction, its parameters, or its trading performance.

## Exact LAD Reduction

For thirteen chronological observations `x[i]=i`, `y[i]=ln(C[i])`, define

```text
Q(a,b) = sum(i=0..12) abs(y[i] - a - b*x[i]).
```

For any fixed slope `b`, the minimizing intercept is the median of the
thirteen residuals `y[i]-b*x[i]`, which is sorted index 6. The profiled
objective is convex and piecewise linear in `b`; its breakpoints occur when
two residuals cross, at slopes `(y[j]-y[i])/(j-i)`. An optimum is therefore
attained at one of the 78 pairwise slopes. The card evaluates all 78 rather
than using an iterative optimizer, fitted bounds, convergence settings, or a
random start.

If more than one candidate objective is within `1e-12` of the minimum, the
card takes the ordinary median of those minimizing candidate slopes. This
fixed equality guard is a numeric tie convention, not a signal-strength or
performance threshold. The final slope magnitude never changes risk.

## Bounded QM Mechanization

At the first executable D1 tick of a genuine broker-month transition,
reconstruct thirteen consecutive completed `XTIUSD.DWX` month-end closes,
oldest to newest. Take natural logs and pair them with integer month indexes
zero through twelve. Enumerate all 78 chronological pair slopes. For each
candidate, profile the intercept at residual median index 6 and calculate the
thirteen-term absolute-loss objective in chronological order. Select the
median slope among candidates tied within `1e-12` of the minimum. Buy when
the slope is positive, sell when it is negative, and consume the month flat
when it is exactly zero or invalid. Renew at the next broker month.

The approved execution contract is:

1. Consume and persist the broker `yyyymm` before all fallible gates.
2. Use exactly thirteen immediately prior completed months, the latest close
   in each, and no current-month price.
3. Require positive finite closes, chronological timestamps, consecutive
   month keys, an immediately prior newest endpoint, and at most ten calendar
   days of endpoint staleness.
4. Require exactly 78 finite pair slopes, 78 thirteen-residual profiles, 78
   finite intercepts, and 78 finite nonnegative objectives.
5. Use the fixed `1e-12` loss-equality guard, ordinary median convention, and
   strict final sign. Exact zero or invalid arithmetic consumes the month
   flat.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Size
   against a frozen `3.5*ATR(20,D1)` broker hard stop, attach no target, and
   cap entry spread at 1,500 points.
7. Retain only one correctly directed, correctly registered, stop-protected
   position. Close on the first tick in a later broker month or after forty
   calendar days. Immediately repair duplicate, wrong-symbol, wrong-magic,
   wrong-side, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF for the monthly
hold. Runtime uses only registered MT5 D1 history, timestamps, calendar,
quotes, symbol metadata, ATR, positions, deals, and terminal-persistent state.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,658 registry identities, 1,311
card files, and 45 Strategy Wiki nodes. It returned no exact or fuzzy match.
The receipt is
`artifacts/qm5_wti_lad_tr_preallocation_dedup_20260825.json`, SHA-256
`C53AE2817A8139C7D57C376B0913B9A9F201B48447A285530082B3569114B308`.

Manual semantic and functional review fixes a new mechanic:

- Theil-Sen ranks the 78 pairwise slopes and takes their global median. LAD
  profiles an intercept for every candidate and minimizes the sum of thirteen
  absolute vertical residuals.
- Repeated median takes thirteen pivot-specific inner slope medians and one
  outer median. It has no intercept or objective minimization.
- On log-price levels
  `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, LAD is `-0.002`,
  while Theil-Sen, repeated median, OLS, and endpoint slope are all positive.
  The systems therefore take opposite sides on one valid state.
- `QM5_13205_xau-xag-qc` fits three 504-observation conditional metals
  regressions and trades two-leg tail-envelope reversion. This rule fits one
  thirteen-point time slope and trades one direct WTI continuation leg.
- OLS plus `R^2`, ordinal Mann-Kendall, adjacent-return median/trim/Winsor/
  Huber/Hodges-Lehmann, weighted-return, sign-vote, endpoint, and path-
  efficiency systems optimize or aggregate different state objects.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback and shares neither carrier nor mechanic.

The carrier, thirteen completed endpoints, time coordinate, all-pairs
candidate set, residual-median intercept, absolute-loss objective, tie rule,
strict direction, consumed attempt, fixed risk, and monthly renewal are
jointly load-bearing. Verdict: `CLEAN_EXACT_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_ESTIMATOR_TRANSLATION_RISK`. Named authors, a complete-read
  peer-reviewed JFE trading paper with explicit WTI membership, and a
  complete-read peer-reviewed JBF method packet with DOI and author preprint.
  The conjunction is untested and labeled as such.
- R2: `PASS`. Endpoint count/order, logarithm, 78 candidates, residual median,
  objective, fixed equality guard, final median, direction, attempt, fixed
  risk, hard stop, rollover, and stale exit are exact.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history and native MT5 execution state supply every runtime input.
- R4: `PASS`. Deterministic logarithm, sorting, absolute loss, finite
  arithmetic, and native execution state only; no trained output, prohibited
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Claim And Kill Boundary

The trading source supports testing an own-price WTI carrier, not the
efficacy of the LAD transformation. Q02 must retire the card below five
completed positions per full post-warm-up year or on nonpositive governed
economics. Downstream gates alone own robustness and correlation. No failure
may be rescued by changing the sample, candidate set, loss, tie convention,
horizon, direction, carrier, stop, hold, spread cap, or retry contract.

## Safety Boundary

This packet supports one Strategy Card, deterministic allocation, one
branch-only V5 build, strict compile/Q01, and one paced non-live Q02 handoff
only. It does not authorize a manual backtest, live artifact, `T_Live`,
AutoTrading, deploy manifest, portfolio-gate change, portfolio admission,
correlation waiver, terminal control, or claim that the sleeve is already
uncorrelated.
