---
source_id: DOE-WTI-SPR-REFILL-2024
title: "U.S. DOE Strategic Petroleum Reserve refill purchase policy"
publisher: "U.S. Department of Energy / CESER"
source_type: official_government_energy_policy
status: mined
last_reviewed: 2026-06-28
cards_extracted:
  - wti-spr-refill-bounce
---

# DOE WTI SPR Refill Policy Source

## Source Links

- U.S. Department of Energy / CESER, Strategic Petroleum Reserve purchase
  solicitation and replenishment strategy:
  https://www.energy.gov/ceser/articles/us-department-energy-announces-solicitation-purchase-oil-strategic-petroleum-1
- U.S. Department of Energy / CESER, additional SPR purchase solicitation:
  https://www.energy.gov/ceser/articles/us-department-energy-announces-solicitation-purchase-oil-strategic-petroleum-7

## Research Use

DOE public SPR replenishment communications describe a structural policy demand
zone for crude purchases after emergency sales, including the stated objective
of refilling at prices that are a good deal for taxpayers and around at or below
USD 79 per barrel. This source is used only for the commodity-market hypothesis
that WTI may show asymmetric support or bounce behavior when it probes that
policy refill zone.

The derived EA does not ingest DOE, EIA, SPR inventory, tender, news, API, CSV,
or policy-calendar data at runtime. It uses Darwinex `XTIUSD.DWX` D1 OHLC bars,
broker calendar time, framework spread/news/friday guards, and deterministic
price confirmation around a fixed policy-zone parameter.

## Gate Notes

- R1 PASS: official U.S. Department of Energy / CESER source.
- R2 PASS: deterministic D1 price-zone reclaim rules can be coded and audited.
- R3 PASS: `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 PASS: no ML, no external runtime feed, no grid, no martingale.
