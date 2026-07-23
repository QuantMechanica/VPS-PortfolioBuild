---
source_id: BURAKOV-WTI-HALLOWEEN-2018
title: The Halloween Effect on Energy Markets - West Texas winter-season extraction
publisher: International Journal of Energy Economics and Policy
source_type: peer_reviewed_open_access_paper
status: approved
approved_by: OWNER commodity-sleeve mission
approved_at: 2026-07-20
primary_url: https://www.econjournals.com/index.php/ijeep/article/view/6092
open_full_text_url: https://www.econjournals.com/index.php/ijeep/article/download/6092/3608/15549
strategy_ids:
  - BURAKOV-WTI-HALLOWEEN-2018_S01
  - BURAKOV-WTI-HALLOWEEN-2018_S02
---

# Burakov-Freidin-Solovyev WTI Winter-Season Source

## Source identity

Burakov, Dmitry, Max Freidin and Yuriy Solovyev (2018), "The Halloween
Effect on Energy Markets: An Empirical Study," *International Journal of
Energy Economics and Policy* 8(2), 121-126, ISSN 2146-4553. The official
article and complete six-page open text are linked above. The full paper,
including both seasonal definitions, all three result tables, discussion,
conclusion and references, was reviewed on 2026-07-20.

The journal article is a named-author empirical study with public full text.
It is treated as quality tier B: reputable and peer reviewed, but not a trading
track record and not an elite-journal result.

## Selected WTI finding

The authors use monthly closing prices from the IMF database over 1985-2016
and compare two deterministic winter/summer partitions. The card selects their
second alternative:

- winter return: last trading-day close of October through the last
  trading-day close of the following May;
- summer return: last trading-day close of May through the last trading-day
  close of October; and
- the executable exposure is consequently long from the first tradable D1 bar
  of November through the end of May, then flat from June through October.

For the `Crude Oil, West Texas` row in Table 2, the paper reports average
winter return `16.65%` versus average summer return `-5.3%`, with the winter
return higher in 23 of 32 years (`72%`). Table 3 reports WTI alternative-two
two-sample t-test `p=0.0096` and Wilcoxon rank-sum `p=0.0031`; the latter is
marked as the appropriate test. These are source statistics, not expected
Darwinex returns and not a portfolio-admission claim.

The repeated month labels printed above Table 2 conflict with the prose and
method equations. Section 3's algorithm explicitly defines alternative two as
end-October to end-May for winter and end-May to end-October for summer. The
mechanization locks that methods-section definition; it does not infer dates
from the duplicated table heading.

The abstract also says summer returns are higher while calling that a
Halloween effect; this conflicts with the paper's own definition, WTI tables,
discussion and conclusion, all of which identify the higher WTI winter leg.
It is recorded as an editorial direction error rather than silently adopted.

## Mechanization boundary

The paper measures one continuous November-May holding interval. The V5
carrier keeps exactly that direction and calendar exposure, but closes and
renews the long package at each month boundary inside November-May. Monthly
renewal is a disclosed QM execution adaptation: it creates seven separately
auditable fixed-risk packages per calendar cycle, realizes financing and gap
costs explicitly, and prevents a stopped package from re-entering mid-month.
It is not claimed as a source-authored trading result.

On the first tradable `XTIUSD.DWX` D1 bar of November through May, the carrier
opens one long package after closing any prior-month package. It remains flat
June through October. A frozen `4.0 * ATR(20)` D1 hard stop, 35-day stale
guard, spread cap, one-attempt-per-month state and fixed-risk sizing are V5
risk/execution additions. There is no short summer leg, price indicator,
trend filter, external feed or parameter fit.

The paper studies an IMF West Texas monthly price series, while
`XTIUSD.DWX` is a continuous Darwinex CFD proxy. Contract construction,
roll/basis, financing, costs, gaps and post-2016 persistence are explicitly
unproven and must be falsified by Q02 and later gates.

## Cadence and data precheck

The deterministic calendar permits seven completed entry packages per full
year: November, December, January, February, March, April and May. The local
V5 registry maps `XTIUSD.DWX` D1 and existing WTI builds demonstrate the
tester route. The saturated tester fleet was not used for a cadence or
performance run; Q02 is authoritative.

## Reputable-source criteria

- R1: PASS (tier B). Exactly one named-author, peer-reviewed, open-full-text
  source lineage is used and the official article URL is preserved.
- R2: PASS. Direction, November-May exposure, June-October flat state,
  monthly renewal, ATR stop, stale guard and spread cap are deterministic;
  the carrier adaptation is explicit.
- R3: PASS. `XTIUSD.DWX` D1 is registered and already has a functioning V5
  custom-symbol/tester route; no external runtime data is required.
- R4: PASS. Calendar arithmetic and ATR risk only; no ML, banned indicator,
  adaptive PnL fit, grid, martingale, pyramiding or multiple positions per
  magic.

## Non-duplicate boundary

Repository-wide card, source and EA searches found no WTI carrier that is
long in every November-May month and flat June-October under the Burakov et
al. energy-market result.

- `QM5_20008_wti-month-ch3` is symmetric price-channel continuation and can
  be long, short or flat in any month.
- `QM5_12726_wti-nov-fade` and the other single-month WTI cards isolate one
  calendar month; they do not express the seven-month winter regime.
- `QM5_12813_eia-energy-switch` is a paired XTI/XNG summer-oil/winter-gas
  package, not a WTI winter-only empirical anomaly.
- `QM5_1047`, `QM5_1080` and `QM5_1573` carry Halloween logic on equity
  indices from different source lineages; none trades WTI.

The signal therefore adds a new WTI carrier/mechanic combination. Different
underlying exposure and source evidence do not guarantee low realized book
correlation; that remains a later portfolio-gate measurement.

## Safety boundary

This source authorizes one `RISK_FIXED` research/backtest carrier only. It
does not authorize a live setfile, AutoTrading, T_Live, a deploy or T_Live
manifest, portfolio admission, or any change to the portfolio gate.

## Second extraction: WTI summer short

The same fully reviewed paper reports the alternative-two WTI summer return
(last May close through last October close) at `-5.3%`, versus `+16.65%` for
winter, with the preferred Wilcoxon comparison reported at `p=0.0031`.
`BURAKOV-WTI-HALLOWEEN-2018_S02` isolates that negative summer leg: short
`XTIUSD.DWX` from June through October and remain flat November through May.
The carrier renews once per broker month, uses a frozen `4.0 * ATR(20)` stop,
a 35-day stale guard, and one attempt per month. Monthly renewal is disclosed
QM execution plumbing, not a source-authored result.

This is not the built S01 winter-long carrier: the exposure months, direction,
and return leg are disjoint. It is also not `QM5_12567`, which is a
price-conditioned cumulative-RSI2 pullback. Five eligible packages per year
put the hypothesis exactly at the Q02 frequency floor, so any missed completed
package requires retirement. Multiple comparisons, the pre-2017 sample,
futures/CFD basis, costs, financing, and post-publication decay remain binding
kill risks.
