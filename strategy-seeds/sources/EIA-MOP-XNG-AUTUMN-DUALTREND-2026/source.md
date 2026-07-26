---
source_id: EIA-MOP-XNG-AUTUMN-DUALTREND-2026
source_type: governed_composite
status: cards_ready
created: 2026-07-26
created_by: Codex
---

# XNG autumn transition plus price-trend source packet

Source approval: OWNER commodity/energy sleeve mission received 2026-07-26,
explicitly authorizing a second XNGUSD edge with logic different from
`QM5_12567`.

## Completely read governed sources

1. U.S. Energy Information Administration, “Natural gas use features two
   seasonal peaks per year,” 2015-09-11,
   https://www.eia.gov/todayinenergy/detail.php?id=22892. The bounded,
   previously approved repository extraction was read completely at
   `strategy-seeds/sources/706222b7-2d60-5fdb-8dab-d722d3c96f92/source.md`.
2. Moskowitz, Ooi and Pedersen (2012), “Time Series Momentum,” *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The bounded, previously approved repository
   extraction was read completely at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

## Bounded extraction

EIA documents recurring winter heating and summer power-sector demand peaks,
which makes September-November a structural transition into the heating
season. Moskowitz, Ooi and Pedersen document persistence in own past returns
across liquid futures, including commodities. The QM hypothesis takes either
side of XNG only in September-November when completed D1 prices form a
directionally aligned and still-moving fast/slow trend stack.

Neither source specifies the 21/84-day averages, five-day slope comparison,
ATR stop, Friday-close segmentation, Darwinex CFD carrier, or profitability.
Those are transparent QM implementation hypotheses subject to Q02
falsification. Runtime uses only native MT5 OHLC and broker-calendar data.
