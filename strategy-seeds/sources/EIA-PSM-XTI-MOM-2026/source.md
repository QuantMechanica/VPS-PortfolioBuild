---
source_id: EIA-PSM-XTI-MOM-2026
title: EIA Petroleum Supply Monthly WTI supply-disposition information window
status: cards_ready
source_type: official_energy_statistics
created: 2026-07-07
owner: Codex
primary_uri: https://www.eia.gov/petroleum/supply/monthly/
quality_tier: A
---

# EIA Petroleum Supply Monthly WTI Supply-Disposition Information Window

## Source

- U.S. Energy Information Administration, "Petroleum Supply Monthly." URL:
  https://www.eia.gov/petroleum/supply/monthly/.
- U.S. Energy Information Administration, "Petroleum & Other Liquids - Data."
  URL: https://www.eia.gov/petroleum/data.php.

## Reputable Source Notes

This source is an official U.S. Energy Information Administration publication.
The EIA page identifies the Petroleum Supply Monthly as a recurring monthly
petroleum data release and links the report tables and release schedule. This
meets the QM reputable-source bar for an official public energy-statistics
source.

## Extracted Mechanic

The strategy card uses the PSM as source lineage for a WTI-only structural
information-window test. The EA does not ingest EIA files, web pages, APIs, or
release calendars at runtime. It tests whether large directional `XTIUSD.DWX`
D1 bars in a broker-calendar month-end PSM proxy window continue for several
daily bars when confirmed by a Donchian breakout and SMA trend filter.

## Extracted Cards

- `xti-psm-mom_card.md`
