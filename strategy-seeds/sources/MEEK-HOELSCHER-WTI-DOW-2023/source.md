---
source_id: MEEK-HOELSCHER-WTI-DOW-2023
title: Day-of-the-week effect: Petroleum and petroleum products
publisher: Cogent Economics and Finance
source_type: peer_reviewed_open_access_paper
status: approved
approved_by: OWNER commodity/energy sleeve mission
approved_at: 2026-07-24
primary_url: https://doi.org/10.1080/23322039.2023.2213876
open_full_text_url: https://www.econstor.eu/bitstream/10419/304091/1/10.1080_23322039.2023.2213876.pdf
strategy_ids:
  - MEEK-HOELSCHER-ENERGY-DOW-2023_S04
---

# MEEK-HOELSCHER-WTI-DOW-2023

## Citation

Meek, H. and Hoelscher, S. A. (2023). "Day-of-the-week effect: Petroleum and petroleum products." Cogent Economics & Finance, 11(1). DOI: https://doi.org/10.1080/23322039.2023.2213876

Open repository pointer: https://www.econstor.eu/handle/10419/304091

## Use in QM

This source is used for deterministic energy day-of-week cards. Existing
single-carrier extractions include the WTI Friday-premium family. The
`MEEK-HOELSCHER-ENERGY-DOW-2023_S04` extraction is one jointly managed
Friday-session relative-value package: buy `XTIUSD.DWX`, sell `XNGUSD.DWX`,
target equal absolute USD notionals, and flatten both legs before the weekend.
No source performance number is imported into the portfolio; Q02 and later
phases must validate the Darwinex CFD realization.

## Bounded full-text review

The complete 21-page EconStor copy (19 journal pages plus repository
frontmatter) was reviewed on 2026-07-24, including the introduction,
literature, contract definitions, price-synching method, descriptive
statistics, five conditional-variance specifications, all result tables,
limitations, conclusion, disclosures, and references.

The paper studies WTI, Brent, RBOB gasoline, heating oil, and natural-gas
futures. WTI and natural gas use Bloomberg front- and second-month contracts
from 2002 through 2021. The authors replace the less-liquid front contract
around expiry with the second contract, compute close-to-close log returns,
and estimate weekday coefficients with GARCH, EGARCH, PGARCH, QGARCH, and
TGARCH variance specifications.

For WTI, Table 2 reports positive Friday coefficients in all five models:
`0.001550`, `0.001017`, `0.001041`, `0.001113`, and `0.001349`. Every Friday
coefficient is statistically significant at the reported 10% or 5% level.
For natural gas, Table 6 reports consistently negative Friday coefficients:
`-0.000745`, `-0.000720`, `-0.000680`, `-0.000607`, and `-0.000673`; none is
reported statistically significant. Subtracting the natural-gas coefficient
from the WTI coefficient gives an untested raw Friday differential of roughly
17-23 basis points across the five model columns.

The authors do not test that cross-energy differential, a two-leg portfolio,
equal-notional sizing, Darwinex CFDs, or transaction-cost profitability. Their
explicit conclusion is that weekday effects are heterogeneous across energy
contracts and that costs may reduce or eliminate paper profits. The paired
carrier is therefore a QM falsification translation, not an author claim.

## Mechanization boundary

- Host and first leg: `XTIUSD.DWX`, D1, long on the first executable Friday
  D1 tick.
- Second leg: `XNGUSD.DWX`, D1, short on the same decision.
- Close both at the governed Friday-close boundary; the next-D1 boundary and
  a three-calendar-day limit are stale safety exits only.
- Solve both volumes jointly so their frozen ATR stops fit inside one
  `RISK_FIXED=1000` package budget and rounded absolute USD notionals target
  1:1 within a fixed tolerance.
- Consume one attempt per broker week before fallible gates and repair any
  partial, orphaned, duplicated, same-direction, or materially unbalanced
  package.

The source labels close-to-close futures returns by ending weekday. The
Friday-open-to-Friday-close Darwinex carrier omits any gap between the prior
D1 close and first Friday tick, and the continuous CFD does not reproduce the
paper's liquidity-based futures roll. Those basis differences, natural-gas
tail risk, order legging, spread, financing, holidays, and costs are binding
kill risks.

## Non-duplicate boundary

The deterministic repository check for slug `xti-xng-fri-rv`, strategy ID
`MEEK-HOELSCHER-ENERGY-DOW-2023_S04`, and the full Friday paired mechanic
returned `CLEAN`.

- `QM5_20016_xti-xng-mon-rv` trades the opposite pair direction on Monday
  from a different source sample and weekday effect.
- `QM5_12597_wti-fri-prem` owns an independent outright WTI long; it has no
  natural-gas hedge or package invariant.
- `QM5_20094_xng-fri-short` owns an independent outright natural-gas short; it
  has no WTI hedge or joint risk budget.
- Oil/gas ratio, return-spread, breakout, momentum, carry, volatility, and
  seasonal baskets use price state or longer formation windows, not a locked
  one-session Friday cross-energy differential.

The two standalone components are known exact overlap. Neither component is
valid by itself under this extraction: the new information object is the
jointly sized Friday differential and its logical-basket return stream.
Pairing does not establish beta neutrality or portfolio decorrelation.

## R1-R4

- R1: PASS. One peer-reviewed, open-access paper with DOI and complete
  reproducible full text is the sole lineage.
- R2: PASS. Friday, pair directions, joint sizing, hard stops, package repair,
  and exits are deterministic and frozen.
- R3: PASS. Registered `XTIUSD.DWX` and `XNGUSD.DWX` D1 history supports one
  logical basket route without an external runtime feed.
- R4: PASS. Native calendar, price, ATR, spread, history, and symbol metadata
  only; no GARCH runtime, ML, adaptive PnL fit, grid, martingale, or multiple
  positions per registered magic.

## Safety boundary

This source approval covers one backtest-only `RISK_FIXED` card, deterministic
registry allocation, build, strict compile, and paced Q02 enqueue. It does not
authorize a live setfile, AutoTrading, `T_Live`, a deploy/T_Live manifest,
portfolio admission, a portfolio-gate change, or a correlation waiver.
