---
source_id: VILLAR-RAMBERG-OILGAS-2026
title: Time-varying error correction between WTI crude oil and Henry Hub natural gas
publisher: U.S. Energy Information Administration and The Energy Journal
source_type: government_research_plus_peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity/energy sleeve mission directive 2026-08-06
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
uri: https://www.eia.gov/naturalgas/archive/reloilgaspri.pdf
cards_extracted:
  - xtixng-ecm-rv
---

# Villar-Joutz / Ramberg-Parsons Oil-Gas Error-Correction Source Packet

## Approval And Complete-Read Scope

- The OWNER mission dated 2026-08-06 authorizes one new structural,
  low-frequency commodity or energy card, branch-only build, and paced Q02
  enqueue using reputable-source criteria.
- Villar and Joutz's complete 43-page EIA report was read end to end: economic
  linkage, unit-root treatment, VAR specification, diagnostics, stability
  tests, Johansen rank tests, error-correction model, dynamics, limitations,
  and bibliography.
- Ramberg and Parsons' complete peer-reviewed article was read end to end from
  the MIT author copy: rules-of-thumb, VECM and conditional ECM, exogenous
  controls, residual volatility, regime-break tests, segmented relationships,
  conclusions, and bibliography. PDF page 24 is blank; substantive journal
  pages are 13-35.
- The extraction is bounded to one transparent price-native hypothesis: a
  rolling trend-augmented log-price residual on registered XTI/XNG CFDs. The
  sources' weather, inventory, shutdown, and production variables are evidence
  context only and are not runtime inputs.

## Primary Citations And Retrieval Evidence

1. Villar, Jose A., and Frederick L. Joutz (2006), "The Relationship Between
   Crude Oil and Natural Gas Prices," U.S. Energy Information Administration,
   Office of Oil and Gas, 43 pages.
   - Landing page:
     https://www.eia.gov/naturalgas/articles/reloilgaspriindex.php
   - Complete report:
     https://www.eia.gov/naturalgas/archive/reloilgaspri.pdf
   - Retrieved 2026-08-06; SHA256
     `25e544ad2cc2d7777b728ce1e235101e7c00d9e4179caf66d6b48f4fe9a4cf1b`.
2. Ramberg, David J., and John E. Parsons (2012), "The Weak Tie Between
   Natural Gas and Oil Prices," *The Energy Journal* 33(2), 13-35, DOI
   https://doi.org/10.5547/01956574.33.2.2.
   - Publisher record:
     https://journals.sagepub.com/doi/10.5547/01956574.33.2.2
   - Complete MIT author copy:
     https://web.mit.edu/~jparsons/www/publications/Weak%20Tie%20Natural%20Gas%20and%20Oil%20Prices.pdf
   - Retrieved 2026-08-06; SHA256
     `27f875e6a032331e8283e056e37ccf9d79e194b0011edc763c7436c6ab8464c2`.
3. U.S. EIA (2020), "Natural gas markets remain regionalized compared with oil
   markets," read completely as adverse modern context:
   https://www.eia.gov/todayinenergy/detail.php?id=43535.

## Relevant Source Locations

- Villar-Joutz pp. 2-6: oil and gas are linked through fuel substitution,
  co-production, drilling inputs, finance, and oil-indexed LNG, but the supply
  effects can conflict and temporary decoupling occurs.
- Villar-Joutz pp. 7-16: price levels are nonstationary, naive level
  regressions can be spurious, and both logged price series are treated as
  I(1).
- Villar-Joutz pp. 24-27: recursive diagnostics identify shocks and require
  explicit attention to model stability.
- Villar-Joutz pp. 27-33 and Table 5: one cointegrating relation is found; the
  normalized log-WTI coefficient is about 0.812; Henry Hub adjusts while WTI
  is weakly exogenous.
- Villar-Joutz pp. 34-40: the conditional ECM includes gas seasonality,
  inventories, weather, and outliers; its lagged error term is negative and
  statistically significant. The authors explicitly call the deterministic
  trend an oversimplification and warn against direct operational adoption.
- Ramberg-Parsons journal pp. 13-18: no fixed energy-content or price-ratio
  rule is reliable; gas is materially more volatile than oil.
- Ramberg-Parsons pp. 21-27 and Tables 1-2: their log-price cointegrating
  coefficient is about 0.468, the lagged gas error-correction coefficient is
  negative, and WTI again does not significantly adjust to gas.
- Ramberg-Parsons pp. 30-35: roughly 85% of gas-price-change variance remains
  unexplained in the full model, and the estimated relationship shifts across
  regimes. The paper rejects a tight or permanently fixed tie.
- EIA 2020: contemporary daily WTI and gas benchmark returns showed little
  correlation, with regional gas fundamentals and transport economics still
  differentiating the markets.

## Source Rule And Bounded Mechanization

The common source object is the error-correction residual from a logged gas
price conditioned on logged oil price and a deterministic drift term:

```text
log(gas_t) = alpha + beta * log(oil_t) + gamma * time_t + residual_t
```

The reports estimate monthly or weekly econometric systems with exogenous
controls. QM does not reproduce those systems. On each new host D1 bar, the EA
will instead fit the equation above by ordinary least squares to exactly 252
synchronized completed XTI/XNG D1 closes, standardize the in-window residual,
and act only when the newest residual crosses a fixed two-standard-deviation
boundary:

- positive residual crossing: gas is rich to its rolling oil-conditioned tie;
  buy XTI and sell XNG;
- negative residual crossing: gas is cheap to the tie; sell XTI and buy XNG;
  and
- close the pair after residual convergence, model invalidation, an orphan,
  or the fixed stale-time limit.

The entry beta is frozen for the package's relative risk weights. Each leg has
an independent ATR hard stop, and one aggregate `RISK_FIXED=1000` budget is
shared between them. A crossing rule prevents repeated entries during one
persistent extreme. Native MT5 OHLC, timestamps, ATR, spread, positions, deal
history, and contract metadata are the only runtime inputs.

This is a falsification proxy, not an econometric replication. A rolling OLS
fit does not prove cointegration or stationarity. Daily continuous CFD prices
do not equal source spot/futures series; the deterministic drift cannot replace
weather, storage, transport, technology, or production controls; and opposite
legs do not prove dollar, beta, volatility, factor, or portfolio neutrality.

## Adverse Evidence And Kill Boundary

- The peer-reviewed source says the relationship can shift dramatically and
  leaves most short-horizon gas volatility unexplained.
- EIA's 2020 evidence says crude and gas benchmark daily returns showed little
  correlation at that time.
- The source samples end in 2005 and 2010. The QM 2017+ CFD window is a later
  regime and receives no inherited coefficient, half-life, return, or efficacy.
- A beta outside the predeclared positive range, a singular regression,
  unsynchronized/stale history, non-finite arithmetic, zero residual variance,
  or a non-crossing extreme fails closed.
- Q02 retires the candidate below five completed paired packages per full
  post-warm-up year or on nonpositive governed economics. No direction,
  window, carrier, trend term, or retry rule may be changed after observing a
  result to rescue the lineage.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,294 EA-registry rows and
410 canonical cards. It found no exact duplicate and no fuzzy match above its
threshold for `xtixng-ecm-rv` / `VILLAR-RAMBERG-OILGAS-2026_S01`.

Manual review resolves the nearest mechanics:

- `QM5_12578_eia-oilgas-ratio` standardizes a fixed XTI/XNG log-price ratio;
  this candidate estimates an intercept, positive oil beta, and deterministic
  drift on a rolling synchronized window.
- `QM5_12608_eia-oilgas-breakout` follows a ratio channel break rather than
  fading an estimated error-correction residual.
- `QM5_12840_xti-xng-rspread` fades a fixed-window return difference, not a
  log-price-level residual.
- `QM5_20016_xti-xng-mon-rv` and `QM5_20110_xti-xng-fri-rv` use weekday
  relative returns rather than a rolling structural tie.
- Energy calendar, momentum, tail, volatility, factor-rank, leverage, and
  breakout baskets consume different state objects and clocks.
- `QM5_20161_xauxag-ols-rv` is a precious-metal rolling OLS sibling without
  the time regressor, oil/gas asymmetric source thesis, or XTI/XNG carrier.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only RSI pullback.

The XNG-on-XTI orientation, intercept plus linear time regressor, 252
synchronized completed D1 observations, bounded positive beta, residual
z-score crossing, gas-residual fade direction, frozen beta risk weights,
convergence exit, and no in-excursion retry are jointly load-bearing. Verdict:
`CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## R1-R4

- R1 source: PASS. Complete U.S. government research report, complete
  peer-reviewed Energy Journal article with DOI and MIT author copy, and
  explicit modern adverse government context.
- R2 mechanical: PASS. Fixed synchronized window, closed-form OLS with trend,
  beta bound, residual crossing, paired direction, shared fixed risk, hard
  stops, convergence/stale exits, and orphan repair.
- R3 data: PASS for the disclosed proxy. Registered XTIUSD.DWX and XNGUSD.DWX
  D1 histories and native broker metadata are sufficient; Q02 must validate
  synchronized warm-up and actual fills.
- R4 deterministic/no ML: PASS. Closed-form arithmetic and native MT5 data
  only; no external runtime feed, trained model, banned indicator, grid,
  martingale, pyramiding, or adaptive PnL fit.

## Safety Boundary

The OWNER mission authorizes this source packet, one G0 card, deterministic EA
and magic allocation, branch-only non-live build, strict compile, one logical
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It excludes manual
backtests; live, demo, or shadow setfiles; AutoTrading; `T_Live`; deploy or
T_Live manifests; portfolio admission; portfolio-gate changes; and correlation
waivers.
