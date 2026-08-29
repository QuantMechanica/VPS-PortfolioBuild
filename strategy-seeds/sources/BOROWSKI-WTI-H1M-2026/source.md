---
source_id: BOROWSKI-WTI-H1M-2026
title: WTI first-half-of-month negative return seasonality
publisher: Journal of Management and Financial Sciences, SGH Warsaw School of Economics
source_type: governed_peer_reviewed_translation_packet
status: approved_source_complete
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-29
source_approval: decisions/2026-08-29_wti_first_half_month_short_source_approval.md
primary_source_packet: strategy-seeds/sources/BOROWSKI-WTI-H2M-2016/source.md
strategy_ids: [BOROWSKI-WTI-H1M-2026_S01]
---

# WTI First-Half-of-Month Short Source Packet

## Bounded Source Basis

The complete governed repository packet
`strategy-seeds/sources/BOROWSKI-WTI-H2M-2016/source.md` was read before this
extraction. It preserves the complete-paper review of Krzysztof Borowski
(2016), "Analysis of Selected Seasonality Effects in Markets of Future
Contracts with the Following Underlying Instruments: Crude Oil, Brent Oil,
Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and
Lumber," *Journal of Management and Financial Sciences*, issue 26, 27-44.
The primary locations are Section 4.4 and Table 2, pages 37-38.

For NYMEX crude-oil futures from 1983-03-30 through 2016-03-31, the governed
packet records average daily returns of `-0.0148%` for calendar days 1-15 and
`-0.0824%` for days 16 through month end. The between-half difference is not
statistically significant (`p=0.5271`). This packet uses only the sign and
calendar definition of the reported first-half observation. It imports no
profitability, significance, cost, drawdown, density, CFD equivalence, or
portfolio-correlation claim.

## Approved Mechanical Translation

The one authorized card tests whether the weaker reported first-half negative
WTI observation survives on the registered continuous-CFD carrier:

- exact host and traded symbol: `XTIUSD.DWX`, D1, slot 0;
- decision clock: first executable D1 tick after a genuine broker-calendar
  month transition;
- direction: SELL only;
- lifecycle: hold through broker calendar days 1-15, then flatten at the first
  observed D1 bar whose normalized broker day is 16 or later;
- attempt: consume the broker `yyyymm` before any fallible entry gate and
  never retry that month after a block, rejection, stop, Friday close, or
  restart;
- risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, one frozen
  `2.75*ATR(20,D1)` broker hard stop, no target;
- safety: one position, positive-spread cap 2,500 points, both news axes OFF,
  and framework Friday close enabled at broker hour 21.

The first genuine month boundary may be dated 1, 2, or later after a weekend
or market closure. Entry may not occur after normalized day 5; a late attach
or missing opening segment consumes the month flat. The exit boundary is the
first available session dated 16 or later, not a shifted signal and not an
additional entry. A 20-calendar-day stale guard repairs only an exposure whose
ordinary boundary was missed.

Runtime uses native D1 timestamps/OHLC, completed-bar ATR for risk only,
quotes, symbol contract properties, positions, deals, broker time, and
terminal-global attempt state. It consumes no futures chain, roll map,
inventory, volume, open interest, news release, API, CSV, trained output, or
external signal.

## Non-Duplicate Boundary

The canonical pre-allocation checker returned only source-family fuzzy
matches. Manual review fixes the executable separation:

- `QM5_20021_wti-h2m-short` enters on an actual day-16 bar and owns the
  complementary second-half interval until next month. This candidate enters
  at the month boundary and must be flat before the existing card can enter.
- `QM5_20028_wti-dom1-long` buys an actual day-1 bar and exits at the next D1
  boundary. This candidate sells the first available month-opening session
  and holds the entire first-half interval.
- `QM5_20027_wti-dom26-short` owns only one actual day-26 session, which is
  outside this candidate's entry and holding interval.
- `QM5_20017` and `QM5_20018` trade natural gas or a weekday, not this WTI
  half-month carrier.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_FIRST_GENUINE_MONTH_BOUNDARY_SHORT_TO_FIRST_DAY_GE_16`.

## Reputable-Source Criteria

- R1 `PASS_WITH_NONSIGNIFICANCE_AND_CFD_TRANSLATION_RISK`: named-author,
  peer-reviewed, complete-read Tier-B paper evidence directly reports the WTI
  first-half return sign and exact 1-15 calendar partition. The source result
  is weak and explicitly non-significant.
- R2 `PASS`: carrier, clock, side, entry-lateness bound, attempt, stop, spread,
  exit boundary, stale repair, and risk modes are fixed before Q02.
- R3 `PASS_WITH_SESSION_AND_FUTURES_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 data and MT5 state provide every runtime field; broker-label
  mapping and continuous-futures/CFD basis remain falsification risks.
- R4 `PASS`: calendar comparisons, completed-bar ATR risk plumbing, and native
  execution state only; no ML or banned signal indicator.

## Falsification And Safety Boundary

Q02 must retire this unchanged identity on zero trades, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, late or duplicate entry, a wrong side, a shifted month boundary,
holding after the first session dated 16 or later, retry after a consumed
month, risk-mode mismatch, or nondeterminism. No weak result may be rescued by
changing the side, date bounds, stop, hold, spread, or attempt contract.

This packet authorizes one branch-only non-live card/build, strict Q01, and
one paced Q02 enqueue if capacity permits. It does not authorize a manual
backtest, live/demo/shadow/stress/optimization preset, terminal control,
`T_Live`, AutoTrading, a deploy manifest, portfolio-gate work, portfolio
admission, or a correlation waiver.
