---
source_id: FERNANDEZ-XNG-SKEW-2026
title: XNG absolute Pearson-skewness premium extraction
publisher: QuantMechanica governed extraction of peer-reviewed source
source_type: peer_reviewed_trading_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-13_qm5_20296_xng_skew_prem_g0.md
parent_source_id: FERNANDEZ-SKEW-2018
parent_sha256: D9C9BDD383956A0190490E4977CAC5D247E9B250342B88577BF7439019C893F7
created: 2026-08-13
created_by: Research+Development
cards_extracted:
  - xng-skew-prem
---

# XNG Absolute Pearson-Skewness Premium Source Packet

## Approved Trading Source Of Record

Fernandez-Perez, Adrian; Frijns, Bart; Fuertes, Ana-Maria; and Miffre,
Joelle (2018), "The Skewness of Commodity Futures Returns," *Journal of
Banking & Finance* 86, 143-158, DOI
`10.1016/j.jbankfin.2017.06.015`.

The governed parent packet is
`strategy-seeds/sources/FERNANDEZ-SKEW-2018/source.md`. It records a complete
read of the 44-page institutional accepted manuscript, including theory,
daily log-return estimator, twelve-month formation, monthly portfolio sorts,
factor controls, robustness tests, appendices, tables, figures, conclusions,
references, and explicit natural-gas membership. The parent record is
content-bound by the SHA-256 above.

The durable OWNER approval for this bounded extraction is
`decisions/2026-08-13_qm5_20296_xng_skew_prem_g0.md`.

## Trading-Source Findings Used

- The paper estimates Pearson's moment coefficient of skewness for each
  commodity from daily log returns over the preceding twelve months.
- At each month-end it buys the lowest-skew commodity-futures quintile,
  shorts the highest-skew quintile, and holds for one month.
- It documents a negative relation between skewness rank and subsequent
  commodity-futures returns.
- Natural gas is an explicit member of the paper's five-contract energy
  sector and 27-commodity universe.
- The effect is driven more strongly by underperformance of the high-skew
  short side, and the source uses a diversified futures cross-section rather
  than a single continuous CFD.

These findings support falsifying whether the sign of natural gas's own slow
realized skewness contains a monthly risk-premium state. They do not establish
that zero is a profitable time-series threshold.

## Bounded QM Mechanization

At the first processed D1 bar of a genuine broker-month transition, define the
formation interval as the twelve complete broker months immediately preceding
the decision month. Load strictly increasing completed `XNGUSD.DWX` D1 closes
and form a log return only when both adjacent timestamps lie inside that
interval. Compute Pearson's population moment coefficient:

```text
r[d] = ln(close[d] / close[d-1])
mu   = mean(r[d])
m2   = mean((r[d] - mu)^2)
m3   = mean((r[d] - mu)^3)
skew = m3 / (m2^(3/2))
```

Buy when skewness is negative and sell when it is positive. Consume exact
zero or invalid state without a trade. Close and renew at the next broker-
month transition.

The absolute zero pivot and single-instrument direction map are transparent
QM hypotheses. They preserve the source's lower-skew/higher-next-return
orientation but replace a broad cross-sectional rank with a time-series state.
The continuous-CFD carrier, broker-calendar reconstruction, population
finite-sample convention, observation bounds, month-attempt ledger,
`RISK_FIXED` sizing, ATR hard stop, spread ceiling, and stale exit are also QM
mechanizations. No source return, alpha, Sharpe ratio, drawdown, trade count,
cost, natural-gas-only result, CFD equivalence, or portfolio-correlation
statistic transfers.

## Exact Statistical Contract

- Formation starts at 00:00 broker time on the first calendar day of the month
  twelve months before the decision month and ends immediately before 00:00
  on the first day of the decision month.
- Include a return only when both its start and end timestamps are inside that
  half-open interval. Exclude current-month and boundary-crossing returns.
- Every one of the twelve expected broker-month keys must contribute at least
  one contained return.
- Require 180 through 280 returns, positive finite closes, finite returns and
  moments, and population variance `m2 > 1e-12`.
- Use population denominators for the second and third central moments and the
  raw Pearson coefficient, with no bias correction, annualization,
  winsorization, rank, fitted threshold, or external benchmark.
- `abs(skew) <= 1e-12` is flat; negative skew buys and positive skew sells.
  Skew magnitude never scales risk.

## Non-Duplicate Boundary

The deterministic checker scanned 4,361 EA-registry rows and 472 root cards.
It found no exact identity and three expected source-family fuzzy matches.
Manual review fixes the boundary:

- `QM5_13118_energy-skew-rank` computes two skewness values and ranks XTI
  against XNG in a paired basket. This extraction computes one absolute XNG
  state around zero, has no XTI input, and has no second leg or orphan state.
- `QM5_20233_xauxag-skew-rank` ranks two precious metals and carries no
  outright natural-gas exposure.
- `QM5_20290_wti-skew-prem` implements the same source estimator and absolute
  direction on WTI. This extraction is an OWNER-authorized carrier extension
  to a separate registered market, with distinct price history, contract
  economics, spread ceiling, magic, and standalone evidence. It inherits no
  WTI pipeline verdict.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only oscillator
  pullback, not a monthly third-moment premium state.
- Existing XNG trend, reversal, calendar, storage-event, breakout,
  variance-ratio, and relative-spread EAs use different information objects,
  pivots, or clocks.

The XNG carrier, twelve complete months, boundary-contained log returns,
population Pearson skewness, fixed zero pivot, negative-skew long/positive-
skew short direction, and monthly lifecycle are jointly load-bearing. Verdict:
`CLEAN_AUTHORIZED_XNG_CARRIER_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1: PASS. One named peer-reviewed paper, DOI, complete institutional
  manuscript record, durable complete-read packet, and explicit natural-gas
  membership.
- R2: PASS. Formation bounds, return inclusion, month coverage, observation
  count, moment formulas, variance floor, pivot, direction, attempt, risk,
  stop, rollover, and stale exit are exact.
- R3: PASS. Registered `XNGUSD.DWX` D1 history and native MT5 execution state
  supply every runtime input.
- R4: PASS. Deterministic arithmetic only; no trained output, prohibited
  signal indicator, external feed, grid, martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The source supports testing a commodity skewness premium, not this absolute
XNG time-series translation. Q02 must retire the card below five completed
positions per full post-warm-up year or on nonpositive governed economics.
Downstream gates alone own robustness and correlation. No failure may be
rescued by changing the formation, estimator, pivot, direction, carrier,
stop, hold, spread, or retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or a claim of decorrelation.
