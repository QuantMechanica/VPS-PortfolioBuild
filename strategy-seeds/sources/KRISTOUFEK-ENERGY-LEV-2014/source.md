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
---

# Kristoufek Energy-Futures Leverage-Effect Source

## Source Identity

- Kristoufek, Ladislav. "Leverage effect in energy futures." *Energy
  Economics* 45 (2014), 1-9. DOI `10.1016/j.eneco.2014.06.009`.
- Publisher record:
  `https://doi.org/10.1016/j.eneco.2014.06.009`.
- Full accepted paper:
  `https://library.utia.cas.cz/separaty/2014/E/kristoufek-0433531.pdf`.

The 2026-07-10 mission directive approved one new structural, low-frequency
commodity/energy card and build. This bounded peer-reviewed source was chosen
because it documents a natural-gas return/volatility asymmetry that is absent
from the incumbent `QM5_12567` cumulative-RSI pullback logic.

## Complete Read And Bounded Extraction

The complete nine-page paper was reviewed, including the introduction,
literature review, range-volatility methodology, long-memory tests,
cross-correlation methods, 2000-2013 front-futures dataset, Tables 1-5,
conclusion, acknowledgements, and references.

The paper studies Brent, WTI, heating oil, and natural-gas futures. Its one
distinct natural-gas result is an inverse leverage effect: standardized
natural-gas returns and logarithmic range volatility are positively correlated
in both reported detrended measures. The paper also finds no long-range
cross-correlation, and the 2019 replication says natural-gas significance is
sensitive to method and return definition. Those limitations prohibit any
claim of a persistent directional premium.

The source contains no mechanical trading strategy. The sole card therefore
uses a positive native-price impulse only as a short-lived volatility regime,
then lets a separate completed H4 range break discover direction. The
positive-impulse threshold, confirmation, stop, target, weekly gate, and time
exit are a falsifiable QM mechanization, not author rules.

## Runtime Guardrails

- Native `XNGUSD.DWX` H4/D1 OHLC, ATR, spread, broker calendar, and framework
  state only.
- No DCCA/DMCA, GARCH, Hurst estimation, futures curve, roll series, storage,
  weather, EIA feed, API, CSV, volume, open interest, ML, or adaptive fit at
  runtime.
- One position on magic slot 0 and one accepted entry per broker week.
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

One card was extracted. Crude-oil leverage effects are not separate builds in
this source pass because the mission requested one edge and the selected XNG
inverse-asymmetry is the source's distinct non-crude finding. Heating oil is
not a registered target symbol. No further card remains open under this source.

