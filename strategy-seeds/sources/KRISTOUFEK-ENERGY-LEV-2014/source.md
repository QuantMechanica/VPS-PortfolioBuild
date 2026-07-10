---
source_id: KRISTOUFEK-ENERGY-LEV-2014
title: Leverage effect in energy futures
author: Ladislav Kristoufek
publisher: Energy Economics
source_type: peer_reviewed_paper
status: cards_ready
created: 2026-07-10
created_by: Codex
cards_extracted:
  - xng-invlev-brk
  - xti-levbrk
---

# Kristoufek Energy-Futures Leverage-Effect Source

## Source Identity

- Kristoufek, Ladislav. "Leverage effect in energy futures." *Energy
  Economics* 45 (2014), 1-9. DOI `10.1016/j.eneco.2014.06.009`.
- Publisher record:
  `https://doi.org/10.1016/j.eneco.2014.06.009`.
- Full accepted paper:
  `https://library.utia.cas.cz/separaty/2014/E/kristoufek-0433531.pdf`.

The 2026-07-10 mission directives approved bounded structural, low-frequency
commodity/energy cards and builds. This peer-reviewed source was chosen
because it separately documents the standard crude-oil leverage effect and a
natural-gas inverse leverage effect, neither of which is the incumbent
`QM5_12567` cumulative-RSI pullback logic.

## Complete Read And Bounded Extraction

The complete nine-page paper was reviewed, including the introduction,
literature review, range-volatility methodology, long-memory tests,
cross-correlation methods, 2000-2013 front-futures dataset, Tables 1-5,
conclusion, acknowledgements, and references.

The paper studies Brent, WTI, heating oil, and natural-gas futures. Its
distinct natural-gas result is an inverse leverage effect: standardized
natural-gas returns and logarithmic range volatility are positively correlated
in both reported detrended measures. Its separate crude-oil result is a stable,
statistically significant standard leverage effect: negative returns and
volatility are associated for both Brent and WTI, with stronger coefficients
at longer measurement scales. The paper also finds no long-range return/
volatility cross-correlation, and its literature review records mixed earlier
WTI asymmetry results. Those limitations prohibit any claim of a persistent
directional premium.

The source contains no mechanical trading strategy. The XNG card therefore
uses a positive native-price impulse only as a short-lived volatility regime,
then lets a separate completed H4 range break discover direction. The WTI card
uses a completed negative D1 impulse as the source-backed volatility regime,
but enters short only after a later completed H4 close confirms downside trend
continuation below the impulse low. All thresholds, confirmations, stops,
targets, weekly gates, and time exits are falsifiable QM mechanizations, not
author rules.

## Runtime Guardrails

- Native `XNGUSD.DWX` or `XTIUSD.DWX` H4/D1 OHLC, ATR, spread, broker calendar,
  and framework state only, according to the card's locked symbol.
- No DCCA/DMCA, GARCH, Hurst estimation, futures curve, roll series, storage,
  weather, EIA feed, API, CSV, volume, open interest, ML, or adaptive fit at
  runtime.
- One position on magic slot 0 and one accepted entry per broker week per EA.
- Backtest setfile only: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## R-Rules

- R1 reputable source: PASS. Peer-reviewed *Energy Economics* article, DOI,
  full institutional copy, complete read, and exact table/result location.
- R2 mechanical: PASS. Fixed positive impulse, completed H4 range confirmation,
  structural stop, fixed-R target, weekly gate, and time exit.
- R3 data available: PASS. `XNGUSD.DWX` H4/D1 is registered for V5 testing.
- R4 no ML/banned logic: PASS. Native OHLC/ATR only; no source econometric
  model runs in the EA.

## Extraction Completeness

Two cards were extracted, one for each distinct registered result needed by
the approved missions:

- `xng-invlev-brk`: positive-return-conditioned, direction-neutral XNG H4
  expansion for the inverse-leverage finding.
- `xti-levbrk`: negative-D1-impulse, short-only WTI H4 continuation for the
  standard crude-oil leverage finding.

Brent is not extracted because it would be a carrier port of the same crude
result rather than a distinct strategy. Heating oil is not a registered target
symbol. No further card remains open under this source.
