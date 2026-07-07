---
source_id: EIA-GASDRAW-XTI-MOM-2026
title: EIA weekly gasoline stocks pressure window for WTI
status: cards_ready
source_type: official_energy_statistics
created: 2026-07-07
owner: Codex
primary_uri: https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WGTSTUS1
quality_tier: A
---

# EIA Weekly Gasoline Stocks Pressure Window For WTI

## Source

- U.S. Energy Information Administration, "Weekly U.S. Ending Stocks of
  Total Gasoline." URL:
  https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WGTSTUS1.
- U.S. Energy Information Administration, "Weekly Petroleum Status Report."
  URL: https://www.eia.gov/petroleum/supply/weekly/.
- U.S. Energy Information Administration, "Petroleum & Other Liquids - Data."
  URL: https://www.eia.gov/petroleum/data.php.

## Reputable Source Notes

The source family is official U.S. Energy Information Administration petroleum
statistics. The Weekly Petroleum Status Report includes weekly refined-product
stock tables, and the gasoline stock series gives a recurring public view of
whether the U.S. gasoline complex is drawing down or building inventory. This
meets the QM reputable-source bar for an official public energy-statistics
source.

## Extracted Mechanic

The strategy card uses weekly gasoline stocks as source lineage for a WTI-only
structural information-window test. The EA does not ingest EIA files, web pages,
APIs, or release calendars at runtime. It trades only the D1 `XTIUSD.DWX` price
reaction around the normal Wednesday/Thursday WPSR proxy window during the
May-August driving-season demand period. A long setup requires a short pullback
into the release window followed by a large bullish D1 reaction above a rising
SMA, expressing gasoline draw pressure through front-month WTI price.

## Extracted Cards

- `xti-gasdraw-mom_card.md`
