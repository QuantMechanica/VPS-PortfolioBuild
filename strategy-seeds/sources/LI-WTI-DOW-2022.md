---
source_id: LI-WTI-DOW-2022
title: The evolution of day-of-the-week and the implications in crude oil market
publisher: Energy Economics
source_type: peer_reviewed_academic_paper
status: approved
approved_by: OWNER commodity-sleeve mission
approved_at: 2026-07-21
primary_url: https://doi.org/10.1016/j.eneco.2022.105817
catalog_url: https://www.econbiz.de/10013202138
strategy_ids: [LI-WTI-DOW-2022_S01]
---

# Li et al. WTI Wednesday Source

## Source identity

Wenhui Li, Qi Zhu, Fenghua Wen and Normaziah Mohd Nor (2022), "The
evolution of day-of-the-week and the implications in crude oil market,"
*Energy Economics* 106, article 105817. DOI:
`10.1016/j.eneco.2022.105817`.

This is a quality-tier-A primary source: a named-author peer-reviewed paper in
an established energy-economics journal, with DOI metadata and bibliographic
identity independently indexed by EconBiz. The article studies WTI trading-day
returns from 2007-05-14 through 2021-05-14.

## Selected finding

The paper reports an abnormal positive Wednesday WTI return and links the
weekday concentration to the scheduled crude-inventory information shock. It
also reports that weekday efficiency evolves through time; the result is not
presented as an immutable premium. The paper's open abstract and highlights
are the evidentiary boundary used here. No coefficient unavailable from that
boundary is invented or used for sizing.

## Mechanization boundary

The closest deterministic MT5 carrier is to buy `XTIUSD.DWX` on the first
executable tick of a broker D1 bar dated Wednesday and flatten on the first
following D1 bar. The paper does not prescribe ATR stops, spread limits, news
handling, fixed-risk sizing or restart state; those are frozen V5 execution
and risk controls.

Broker D1 boundaries do not necessarily equal NYMEX settlement boundaries,
and Darwinex's continuous CFD is not the source futures series. Q02 therefore
tests a basis-sensitive implementation rather than claiming replication.

## Limitations and kill boundary

- The authors explicitly find time-varying market efficiency.
- The 2007-2021 evidence may decay after publication.
- Inventory holidays can move the release schedule, while this carrier uses
  weekday only and consumes a blocked signal rather than shifting it.
- Futures/CFD construction, broker-day mapping, spread, financing and gaps can
  reverse the gross source result.
- One cited empirical anomaly does not establish portfolio decorrelation.

Only the locked Wednesday-long/next-D1-flat baseline is authorized. A weekday,
direction, hold, news-release-time or parameter sweep needs a new card.

## Safety boundary

This source authorizes a `RISK_FIXED` research/backtest build and Q02 enqueue
only. It authorizes no live setfile, T_Live access, AutoTrading action,
deployment manifest, portfolio admission or portfolio-gate change.
