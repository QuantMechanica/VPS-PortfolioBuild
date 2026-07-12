---
source_id: SCHWEIKERT-QC-2018
title: Are gold and silver cointegrated? New evidence from quantile cointegrating regressions
publisher: Journal of Banking and Finance
source_type: peer_reviewed_paper_with_open_preprint
status: cards_ready
approval_basis: OWNER commodity-sleeve mission 2026-07-12
created: 2026-07-12
created_by: Research
cards_extracted:
  - xau-xag-qc
---

# Schweikert Gold/Silver Quantile-Cointegration Source Packet

## Source identity and bounded approval

- Schweikert, Karsten (2018), "Are gold and silver cointegrated? New evidence
  from quantile cointegrating regressions," *Journal of Banking & Finance* 88,
  44-51.
- Published DOI: https://doi.org/10.1016/j.jbankfin.2017.11.010.
- Complete 32-page author preprint:
  https://karstenschweikert.github.io/qcoint/qcoint_20171121_preprint.pdf.
- Approval basis: the OWNER commodity-sleeve mission dated 2026-07-12 directs
  Research and Development to select, card, build, and enqueue one bounded new
  structural commodity sleeve.

The complete preprint was reviewed end to end, including the economic
motivation, prior literature, structural model, linear and quantile
cointegration estimators, monthly and daily spot tests, futures tests,
appendix, conclusion, and references.

## Source result and adverse evidence

The paper models the gold/silver long-run equation with quantile-varying
intercepts and slopes. Its Equation 10 estimates each conditional quantile by
minimizing Koenker-Bassett asymmetric check loss. Gold and silver spot and
futures prices exhibit a state-dependent and asymmetric relationship: the
response is generally stronger in upper price quantiles and during episodes
when both metals act as financial safe havens.

This is not clean evidence for a profitable pairs trade. Constant-vector
linear cointegration is rejected in important specifications; some daily
upper quantiles also reject quantile cointegration. The conclusion states that
the exact state is not known ex ante, the estimates cannot directly be used to
forecast, and a constant-coefficient gold/silver statistical-arbitrage spread
would be risky. Earlier work summarized by the paper likewise found no
profitable ex-ante intercommodity-spread rule. These adverse findings are
binding prior evidence for the QM carrier.

## Bounded extraction

This packet extracts one strategy only: `xau-xag-qc`. It mechanizes a
conditional-quantile envelope rather than pretending to reproduce the paper's
full cointegration tests:

1. On the first tradable XAU D1 bar of each broker month, use 504 synchronized
   completed XAU/XAG D1 log-price pairs as the formation sample and reserve the
   newest completed pair as an out-of-formation signal observation. Freeze the
   fitted lines for that broker month and evaluate entries/exits weekly. A
   restart reconstructs that exact month-anchored window rather than shifting
   the fit endpoint to the restart date.
2. Estimate `ln(XAG) = alpha_tau + beta_tau * ln(XAU)` separately for
   `tau in {0.10, 0.50, 0.90}` by minimizing the asymmetric check-loss
   objective. For any beta, alpha is the empirical tau-quantile of residuals.
   The exact constrained two-parameter solution is selected from the sorted
   pairwise-slope breakpoints inside fixed beta bounds.
3. Require positive bounded slopes, ordered conditional predictions, and the
   source-consistent but QM-defined asymmetry
   `beta_90 > beta_10 + 0.05`. Invalid or nearly constant envelopes are
   no-trade states.
4. Sell expensive silver and buy beta-weighted gold above the upper envelope;
   buy cheap silver and sell beta-weighted gold below the lower envelope.
5. Exit on a weekly return to the conditional median, a 70-day time stop, a
   hard per-leg ATR stop, or broken-package detection.

The log-price transform, rolling 504-pair window, fixed 10/50/90 quantiles,
monthly refit, weekly signal cadence, 0.05 slope-span guard, tail entry, and
median exit are disclosed QM mechanizations. The paper estimates price levels
with dynamic augmentation or fully-modified correction and tests
cointegration with Xiao CUSUM statistics; the EA does not reproduce those
full-sample estimators or tests. The paper supplies structural lineage and the
check-loss target, not a performance claim or executable threshold.

## Reputable-source criteria

- R1: PASS. Exactly one peer-reviewed *Journal of Banking & Finance* source,
  with DOI and complete author preprint.
- R2: PASS. Fixed D1 sample, three fixed quantiles, bounded deterministic exact
  constrained check-loss solver, explicit envelope entries, median/time/hard-stop exits,
  and two allocated position slots.
- R3: PASS. Registered `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories are native
  Darwinex inputs.
- R4: PASS. Deterministic arithmetic only; no ML, adaptive PnL fit, external
  runtime feed, grid, martingale, pyramiding, or random path.

## Non-duplicate boundary

The load-bearing novelty is a quantile-specific intercept and slope estimated
by asymmetric check loss. Repository and all-history searches found no
conditional-quantile regression or check-loss EA/card/source.

- `QM5_12577` is fixed-beta log-ratio z-score reversion.
- `QM5_12862` is fixed-beta return-spread z-score reversion.
- `QM5_12724` is a fixed-beta ratio channel breakout.
- `QM5_1083` and `QM5_11241` use rolling OLS residuals, z-scores, and
  half-life diagnostics.
- `QM5_11246` uses a Kalman hedge ratio and forecast-error bands.
- `QM5_1256` uses a stochastic oscillator on the raw ratio plus correlation.
- `QM5_1334` uses a fixed-beta mean/max-deviation envelope.
- Registry-only `QM5_12019_ru-garch-quantile-action` has no EA, card, source,
  setfile, or magic rows and is unrelated.

Replacing check-loss slopes with OLS, replacing conditional boundaries with a
z-score, or dropping the asymmetric-slope gate would collapse this strategy
into an existing family and requires rejection as duplicate.

## Runtime and risk boundary

- Native MT5 D1 time/close, ATR, spread, broker calendar, position/deal state,
  terminal-global weekly-attempt marker, and symbol metadata only. The marker
  stores no signal or market input and exists solely to suppress a same-week
  retry when both broker orders reject before a deal exists.
- One logical XAU/XAG basket; XAU host/traded slot 0 and XAG traded slot 1.
- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, no live setfile.
- At entry the EA targets XAU:XAG dollar notionals of `beta:1`, then scales
  both lots so their combined frozen-stop loss does not exceed one fixed
  package budget. Volume rounding leaves residual hedge error and does not
  prove beta, volatility, or realized portfolio neutrality.
- No T_Live, AutoTrading action, deploy manifest, portfolio gate, portfolio
  admission, or portfolio KPI change is authorized.
