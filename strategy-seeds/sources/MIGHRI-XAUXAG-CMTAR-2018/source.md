---
source_id: MIGHRI-XAUXAG-CMTAR-2018
title: Gold-Silver Nexus - A Threshold Cointegration Approach
publisher: International Journal of Economics and Financial Issues
source_type: peer_reviewed_paper
status: cards_ready
created: 2026-07-20
created_by: Research
cards_extracted:
  - xauxag-cmtar
---

# Mighri-Al Saggaf Gold-Silver C-MTAR Source

## Source Identity

- Mighri, Zouheir Ahmed and Al Saggaf, Majid Ibrahim (2018), "Gold -
  Silver Nexus: A Threshold Cointegration Approach," *International Journal
  of Economics and Financial Issues* 8(5), 210-219, ISSN 2146-4138.
- Official article page:
  https://www.econjournals.com/index.php/ijefi/article/view/6838
- Open full text:
  https://www.econjournals.com/index.php/ijefi/article/download/6838/pdf/17184
- The complete ten-page paper, including its method, empirical tables,
  conclusion, and references, was reviewed on 2026-07-20.

The journal describes its process as double-blind peer review and the article
is an open, named-author empirical study. It is treated as quality tier B: a
reputable but non-elite journal source, not a demonstrated trading record.

## Selected Finding

The paper studies 581 LBMA gold and silver observations from January 1968
through May 2016. Section 3.1 and the observation count establish a monthly
cadence. Its preferred consistent momentum-threshold autoregressive
cointegration model reports:

- long-run row labelled `Silver-gold`: intercept `-0.99823` and elasticity
  `0.71970`, both reported significant at 1%;
- residual in the data's base-10 scale:
  `e = log10(silver) + 0.99823 - 0.71970 * log10(gold)`;
- momentum threshold `delta(e) = 0.021`;
- when `delta(e) < 0.021`, adjustment coefficient `rho2 = -0.043`
  (`t = -3.716`); and
- when `delta(e) >= 0.021`, `rho1 = +0.023` is not significant.

The no-threshold-cointegration null is rejected for the consistent M-TAR model
(`F=7.601`, `p=0.0006`) and symmetric adjustment is rejected (`F=8.206`,
`p=0.004`). The selected edge is therefore not unconditional gold/silver
ratio reversion. It is monthly convergence of a fixed published residual only
while the residual change is in the source's statistically convergent regime.

## Source Reconciliation

The paper contains three internal labeling inconsistencies, so the mechanical
interpretation is fixed here rather than hidden:

- the abstract says weekly observations, but Section 3.1 says monthly and 581
  observations over 1968-2016 can only be monthly;
- Section 3.1 says natural logarithms, but the Table 1 means (`2.5196` for
  gold and `0.8151` for silver) are base-10 log levels; and
- the Table 4 footnote reverses the equation labels, while the `Silver-gold`
  row and sample means identify silver as the dependent variable. Substitution
  of the sample means satisfies
  `0.8151 ~= -0.99823 + 0.71970 * 2.5196`; the reverse equation does not.

The card consequently locks monthly sampling, base-10 logs, and the
silver-on-gold orientation. Those choices reproduce the published table rather
than choosing a favorable implementation after testing.

## Mechanization Boundary

On the first tradable D1 bar of each broker month, the carrier reconstructs
the two latest synchronized completed month-end closes, calculates `e` and
`delta(e)`, and opens an opposite-direction XAG/XAU package only when
`delta(e) < 0.021` and the absolute residual clears a small fixed execution
buffer. A positive residual means silver is rich: sell XAG and buy XAU. A
negative residual means silver is cheap: buy XAG and sell XAU. The XAU:XAG
dollar-notional target is the published `0.71970:1` elasticity.

Each package is renewed at the next month boundary. The entry buffer, monthly
renewal, ATR hard stops, spread caps, broken-package repair, and forty-day
stale guard are explicit V5 execution/risk adaptations. The source publishes
no trading rule, transaction-cost result, or CFD result. Q02 and later phases
must decide whether the fixed 1968-2016 LBMA relationship survives on Darwinex
spot-CFD bars after costs.

## Non-Duplicate Boundary

- `QM5_12577_cme-xauxag-ratio` is a rolling symmetric ratio z-score fade.
- `QM5_12724_cme-xauxag-brk` is a ratio-channel continuation rule.
- `QM5_12862_xauxag-rspread` fades a standardized fixed-lookback return
  spread.
- `QM5_11241_ht-coint-spread` fits a rolling symmetric OLS residual and
  half-life/z-score gate.
- `QM5_13205_xau-xag-qc` fits rolling conditional-quantile envelopes.

None uses the published fixed C-MTAR residual together with its asymmetric
monthly `delta(e) < 0.021` convergence gate. Removing that gate would change
the strategy and is not authorized.

## Reputable-Source Criteria

- R1: PASS (tier B). Named-author, double-blind-peer-reviewed journal article
  with official landing page and complete open text; no performance claim is
  imported.
- R2: PASS. Fixed equation, monthly endpoints, threshold, directions, sizing
  target, exits, and risk additions are deterministic; all adaptations and
  source inconsistencies are disclosed.
- R3: PASS. `XAUUSD.DWX` and `XAGUSD.DWX` are registered local Darwinex
  symbols with prior multi-symbol basket builds.
- R4: PASS. Base-10 arithmetic, calendar logic, ATR stops, and deterministic
  basket sizing only; no ML, banned indicator, grid, martingale, pyramiding,
  external runtime feed, or adaptive PnL fitting.

