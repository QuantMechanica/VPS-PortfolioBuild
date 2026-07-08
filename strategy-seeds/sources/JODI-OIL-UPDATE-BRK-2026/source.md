---
source_id: JODI-OIL-UPDATE-BRK-2026
title: JODI Oil World Database Monthly Update
publisher: Joint Organisations Data Initiative / International Energy Forum
source_type: official_global_energy_data
status: mined
last_reviewed: 2026-07-08
cards_extracted:
  - xti-jodi-brk
  - xti-jodi-fade
---

# JODI Oil Monthly Update Source

## Source Identity

- JODI-Oil World Database, https://www.jodidata.org/oil/
- JODI-Oil World Database Update Calendar,
  https://www.jodidata.org/oil/support/update-calendar.aspx
- International Energy Forum, Oil and Gas Data Review,
  https://www.ief.org/data/oil-gas-data-review
- International Energy Agency, Joint Organisations Data Initiative overview,
  https://www.iea.org/about/international-collaborations/joint-organisations-data-initiative

## Research Use

JODI is an official global oil and gas data-transparency initiative coordinated
through the IEF and supported by major international energy organizations. The
JODI-Oil database provides monthly oil market data, while the IEF Oil and Gas
Data Review summarizes the latest JODI update on a monthly publication calendar.

The QM expressions do not import JODI data at runtime. They use the official
monthly update and review cadence as a structural global-oil information clock,
then trade only Darwinex `XTIUSD.DWX` D1 price action during a deterministic
mid-to-late-month proxy window.

## R-Rules

- R1 reputable source: PASS. JODI/IEF/IEA are official global energy data
  institutions and the JODI oil database is public.
- R2 mechanical: PASS. Fixed monthly date window, completed-bar Donchian
  breakout or failed-probe fade, SMA confirmation/mean exit, ATR stop/target,
  time exit, and one signal per month.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, external runtime API, grid, martingale,
  pyramiding, adaptive PnL fitting, or discretionary override.
