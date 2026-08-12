---
source_id: FERNANDEZ-WTI-SKEW-2026
title: WTI absolute Pearson-skewness premium extraction
publisher: QuantMechanica governed extraction of peer-reviewed source
source_type: peer_reviewed_trading_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-12_qm5_20290_wti_skew_prem_g0.md
parent_source_id: FERNANDEZ-SKEW-2018
parent_sha256: D9C9BDD383956A0190490E4977CAC5D247E9B250342B88577BF7439019C893F7
created: 2026-08-12
created_by: Research+Development
cards_extracted:
  - wti-skew-prem
---

# WTI Absolute Pearson-Skewness Premium Source Packet

## Approved Trading Source Of Record

Fernandez-Perez, Adrian; Frijns, Bart; Fuertes, Ana-Maria; and Miffre,
Joelle (2018), "The Skewness of Commodity Futures Returns," *Journal of
Banking & Finance* 86, 143-158, DOI
`10.1016/j.jbankfin.2017.06.015`.

The governed parent packet is
`strategy-seeds/sources/FERNANDEZ-SKEW-2018/source.md`. It records a complete
read of the 44-page institutional accepted manuscript, including the theory,
daily log-return estimator, twelve-month formation, monthly portfolio sorts,
factor controls, robustness tests, appendices, tables, figures, conclusions,
references, and explicit crude-oil membership. The parent record is content-
bound by the SHA-256 above.

The durable OWNER approval for this bounded extraction is
`decisions/2026-08-12_qm5_20290_wti_skew_prem_g0.md`.

## Trading-Source Findings Used

- The paper estimates Pearson's moment coefficient of skewness for each
  commodity from daily log returns over the preceding twelve months.
- At each month-end it buys the lowest-skew commodity-futures quintile,
  shorts the highest-skew quintile, and holds the portfolio for one month.
- The source documents a negative relation between skewness rank and
  subsequent commodity-futures returns.
- Crude oil is an explicit member of the paper's 27-commodity universe.
- The effect is driven more strongly by underperformance of high-skew
  commodities, and the paper uses a diversified futures cross-section rather
  than a single continuous CFD.

These findings support falsifying whether the sign of WTI's own slow realized
skewness contains a monthly risk-premium state. They do not establish that
zero is a profitable time-series threshold.

## Bounded QM Mechanization

At the first processed D1 bar of a genuine broker-month transition, define
the formation interval as the twelve complete broker months immediately
preceding the decision month. Load strictly increasing completed
`XTIUSD.DWX` D1 closes and form a log return only when both adjacent bar
timestamps lie inside that interval. Compute Pearson's population moment
coefficient:

    r[d] = ln(close[d] / close[d-1])
    mu   = mean(r[d])
    m2   = mean((r[d] - mu)^2)
    m3   = mean((r[d] - mu)^3)
    skew = m3 / (m2^(3/2))

Buy when skewness is negative and sell when it is positive. Consume exact
zero or invalid state without a trade. Close and renew at the next broker-
month transition.

The absolute zero pivot and single-instrument direction map are transparent
QM hypotheses. They preserve the source's lower-skew/higher-next-return
orientation but replace a broad cross-sectional rank with a time-series
state. The continuous-CFD carrier, broker-calendar reconstruction, population
finite-sample convention, observation bounds, month-attempt ledger,
`RISK_FIXED` sizing, ATR hard stop, spread ceiling, and stale exit are also QM
mechanizations. No source return, alpha, Sharpe ratio, drawdown, trade count,
cost, WTI-only result, CFD equivalence, or portfolio-correlation statistic
transfers.

## Exact Statistical Contract

- Formation starts at 00:00 broker time on the first calendar day of the
  month twelve months before the decision month and ends immediately before
  00:00 on the first day of the decision month.
- A return is included only when both its start and end timestamps are inside
  that half-open interval. Current-month and boundary-crossing returns are
  excluded.
- Every one of the twelve expected broker-month keys must contribute at least
  one contained return.
- Require 180 through 280 returns, positive finite closes, finite returns and
  moments, and population variance `m2 > 1e-12`.
- Use population denominators for the second and third central moments and
  the raw Pearson coefficient, with no bias correction, annualization,
  winsorization, ranking, fitted threshold, or external benchmark.
- `abs(skew) <= 1e-12` is flat; negative skew buys and positive skew sells.
  Skew magnitude never scales risk.

## Non-Duplicate Boundary

The deterministic checker scanned 4,355 EA-registry rows and 467 root cards.
It found no exact identity and the two expected source-family fuzzy matches.
Manual review fixes the boundary:

- `QM5_13118_energy-skew-rank` computes two skewness values and ranks XTI
  against XNG in a paired basket. This extraction computes one absolute WTI
  state around zero, has no XNG input, and has no second leg or orphan state.
- `QM5_20233_xauxag-skew-rank` ranks two precious metals and carries no
  outright crude-oil exposure.
- `QM5_20289_wti-rsj-rev` uses one complete month of normalized upside-minus-
  downside semivariance. This extraction uses twelve complete months and the
  centered third standardized moment.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only oscillator
  pullback, not a monthly third-moment premium state.
- Existing WTI return trend, robust trend, reversal, calendar, event,
  breakout, variance-ratio, and path-quality systems use different
  information objects, pivots, or clocks.

The twelve complete months, boundary-contained log returns, Pearson
population skewness, fixed zero pivot, negative-skew long/positive-skew short
direction, outright WTI carrier, and monthly lifecycle are jointly load-
bearing. Verdict:
`CLEAN_AFTER_MANUAL_CROSS_SECTIONAL_TO_TIME_SERIES_REVIEW`.

## Reputable-Source Criteria

- R1: PASS. One named peer-reviewed paper, DOI, complete institutional
  manuscript record, durable complete-read packet, and explicit WTI
  membership.
- R2: PASS. Formation bounds, return inclusion, month coverage, observation
  count, moment formulas, variance floor, pivot, direction, attempt, risk,
  stop, rollover, and stale exit are exact.
- R3: PASS. Registered `XTIUSD.DWX` D1 history and native MT5 execution state
  supply every runtime input.
- R4: PASS. Deterministic arithmetic only; no trained output, prohibited
  signal indicator, external feed, grid, martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The source supports testing a commodity skewness premium, not this absolute
WTI time-series translation. Q02 must retire the card below five completed
positions per full post-warm-up year or on nonpositive governed economics.
Downstream gates alone own robustness and correlation. No failure may be
rescued by changing the formation, estimator, pivot, direction, carrier,
stop, hold, spread, or retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or a claim of decorrelation.
