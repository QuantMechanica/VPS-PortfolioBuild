---
source_id: KELOHARJU-GK-OILBENCH-CAL-2026
title: WTI/Brent same-calendar relative seasonality
publisher: Journal of Finance / Problems of World Agriculture / CME / ICE / EIA
source_type: governed_composite_lineage
quality_tier: A/B
status: approved_source_complete
approval_basis: OWNER commodity/energy sleeve mission 2026-08-01
created: 2026-08-01
created_by: Research+Development
parent_sources:
  - KELOHARJU-RETSEAS-2016
  - GORSKA-KRAWIEC-WTI-CAL-2015
  - CME-WTI-BRENT-SPREAD-2026
strategy_ids:
  - KELOHARJU-GK-OILBENCH-CAL-2026_S01
---

# WTI/Brent Same-Calendar Relative-Seasonality Source Packet

## Approval And Review Scope

The OWNER mission dated 2026-08-01 directs one new structural,
low-frequency commodity or energy card, build, and paced Q02 enqueue. This
packet combines three already governed repository lineages that were read
completely for this extraction:

1. Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities",
   *The Journal of Finance* 71(4), 1557-1590,
   DOI `10.1111/jofi.12398`. The complete 57-page NBER version and its
   cross-sectional commodity construction are recorded in
   `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`.
2. Gorska and Krawiec (2015), "Calendar Effects in the Market of Crude Oil",
   *Problems of World Agriculture* 15(4), 62-70,
   DOI `10.22630/PRS.2015.15.4.54`. Its end-to-end repository review records
   daily WTI and Brent calendar evidence in
   `strategy-seeds/sources/GORSKA-KRAWIEC-WTI-CAL-2015/source.md`.
3. CME, ICE, and U.S. EIA references establish Brent-versus-WTI as a standard
   traded and economically interpretable crude-benchmark spread. Their
   governed packet is
   `strategy-seeds/sources/CME-WTI-BRENT-SPREAD-2026/source.md`.

A 2026-08-01 generic-source refresh request was classified
`DEFERRED:SOURCE_POLICY` by the deterministic source router. Its evidence is
preserved beside this packet. No fresh page text or uncited performance claim
is used; the bounded repository packets above are the extraction authority.

## Findings Used

- Keloharju, Linnainmaa, and Nyberg define a recurring same-calendar-month
  state from prior returns in the decision calendar month. Their commodity
  strategy ranks eligible futures by that historical average and holds the
  high rank long against the low rank short for one month, with at least five
  prior observations.
- Gorska and Krawiec directly study calendar effects in both WTI and Brent,
  supporting the two crude benchmarks as calendar-sensitive carriers. Their
  sample results do not establish this relative rule.
- CME and ICE list Brent/WTI spread products, and EIA analyzes the benchmark
  differential as a market-structure variable. This establishes a real energy
  spread, not profitability or stationarity.

The parent papers and exchange references do not test a two-CFD historical
same-month rank, equal stop-risk legs, Darwinex month boundaries, or the QM
portfolio. Those translations remain hypotheses for Q02 and later gates.

## Bounded Mechanization

`KELOHARJU-GK-OILBENCH-CAL-2026_S01` locks one monthly two-leg package:

- host/slot 0: `XTIUSD.DWX`, D1; companion/slot 1: `XBRUSD.DWX`, D1;
- decision: first tradable XTI D1 bar of each broker calendar month;
- history: the current decision calendar month's synchronized WTI and Brent
  returns in exactly the ten prior years, requiring at least five paired
  observations;
- score: arithmetic mean of `log_return_WTI - log_return_Brent` across the
  accepted paired years;
- positive score buys WTI and sells Brent; negative score sells WTI and buys
  Brent; a tie or invalid state remains flat for the consumed month;
- close and rerank at the next month boundary, with a 40-calendar-day stale
  guard and frozen `3.5 * ATR(20,D1)` per-leg hard stops;
- one `RISK_FIXED=1000` package budget split equally by stop risk,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The opposite legs target recurring relative crude-benchmark seasonality and
reduce common outright-oil direction. They do not prove dollar, beta,
volatility, or portfolio neutrality.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,246 registry rows and 377
cards and returned `CLEAN` for slug `oilbench-cal`, strategy ID
`KELOHARJU-GK-OILBENCH-CAL-2026_S01`, and the exact mechanic.

Manual semantic review separates the candidate from the closest systems:

- `QM5_12843_wti-brent-spread` fades a rolling Brent-minus-WTI log-level
  z-score and exits near its recent mean.
- `QM5_12848_wti-brent-brk` follows a Donchian breakout of that spread level.
- `QM5_12860_wti-brent-rshock` fades a short-horizon standardized return
  shock.
- `QM5_13115_energy-samecal` uses WTI and natural gas, exposing storage,
  weather, and gas-specific fundamentals absent from this benchmark pair.
- `QM5_20099_wti-samecal`, the Brent month cards, and weekday cards own one
  directional oil leg and never rank synchronized WTI against Brent.
- WTI trend, inventory, WPSR, fixed-month, and XNG systems do not estimate a
  recurring two-benchmark relative calendar return.

The synchronized prior-year calendar estimator, WTI-versus-Brent rank,
opposite two-leg package, and monthly decision clock are jointly load-bearing.
Replacing them with a recent z-score, channel, shock, fixed direction, or
single carrier recreates an existing family.

## Reputable-Source Criteria

- R1: PASS. The primary method is from a peer-reviewed *Journal of Finance*
  paper with DOI and complete durable review; the target benchmarks have a
  peer-reviewed calendar study; CME, ICE, and EIA establish the spread's
  market structure.
- R2: PASS. Calendar endpoints, ten-year bounded estimator, five-pair floor,
  direction, attempt state, shared risk, hard stops, and exits are fixed.
- R3: PASS. Native `XTIUSD.DWX` and `XBRUSD.DWX` D1 routes are already used
  by local V5 builds; Q02 remains responsible for synchronized-history and
  fill sufficiency.
- R4: PASS. Runtime uses deterministic OHLC, ATR, calendar, symbol, deal,
  position, and framework state only; no trained model, external signal,
  grid, martingale, scale-in, or pyramid is used.

## Claim And Safety Boundary

The parent evidence does not establish profitability, CFD/futures
equivalence, spread stationarity, trade density, or book decorrelation for
this narrow translation. Continuous-CFD rolls, financing, common crude beta,
regional dislocations, legging, lot granularity, and only five-to-ten annual
samples per calendar month are binding risks.

This approval covers one card, deterministic allocation `QM5_20190`, two
magic rows, one V5 build, one logical-basket `RISK_FIXED` setfile, one basket
manifest, and one paced Q02 enqueue. It does not authorize a live setfile,
AutoTrading, `T_Live`, a deploy or T_Live manifest, portfolio admission, a
portfolio-gate change, or a correlation waiver.
