---
source_id: ARENDAS-OIL-SEASON-2018
title: Arendas et al. crude-oil seasonal patterns
publisher: Journal of International Studies
source_type: academic_paper
status: cards_ready
created: 2026-06-27
created_by: Codex
uri: https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf
cards_extracted:
  - wti-nov-fade
  - wti-mar-prem
  - wti-apr-prem
  - wti-aug-prem
  - wti-febsep-prem
  - brent-apr-prem
  - brent-aug-prem
  - wti-sep-prem
  - brent-febsep-prem
  - brent-sep-prem
  - brent-jul-prem
---

# Arendas Oil Seasonality Source

## Source Identity

- Publisher: Journal of International Studies
- Primary source: Arendas, P., Tkacova, D. and Bukoven, J., "Seasonal patterns
  in oil prices and their implications for investors", Journal of International
  Studies, 11(2), 180-192, DOI 10.14254/2071-8330.2018/11-2/12, URL
  https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf

## Research Use

This source is used for structural lineage around month-of-year seasonality in
crude-oil returns. The extraction used six mechanized cards:

- `wti-nov-fade`: XTIUSD.DWX D1 November month-of-year negative-return sleeve.
- `wti-mar-prem`: XTIUSD.DWX D1 March month-of-year positive-return sleeve.
- `wti-apr-prem`: XTIUSD.DWX D1 April month-of-year positive-return sleeve.
- `wti-aug-prem`: XTIUSD.DWX D1 August month-of-year positive-return sleeve.
- `wti-febsep-prem`: XTIUSD.DWX D1 February-September source-window sleeve.
- `brent-apr-prem`: XBRUSD.DWX D1 April month-of-year positive-return sleeve.
- `wti-sep-prem`: XTIUSD.DWX D1 September terminal-month sleeve from the
  paper's February-September allocation window.
- `brent-febsep-prem`: XBRUSD.DWX first-tradable-day February-September
  source-window premium.
- `brent-sep-prem`: XBRUSD.DWX D1 September terminal-month seasonal premium.
- `brent-jul-prem`: XBRUSD.DWX D1 July mid-window seasonal premium.

The March and April WTI cards isolate positive spring months reported by the
source. They are intentionally separate from the February premium card that uses
the Gorska-Krawiec WTI calendar source, and from the broad EIA demand-season
strategy that requires trend/momentum confirmation.

The Brent April and Brent August cards isolate source-reported positive months
on the Brent benchmark (`XBRUSD.DWX`) rather than WTI. They are deliberately
separate from the WTI month cards, existing Brent weekday cards, Brent
May/November/December calendar cards, Brent TSMOM, and Brent/WTI spread logic.

The August card isolates the third positive month named by the source and is
kept separate from the April spring premium and broad EIA summer-demand season
logic. The WTI August card validates that month on `XTIUSD.DWX`; the Brent
August card validates the same structural month on `XBRUSD.DWX`. Q02+ must
validate each deterministic rule on Darwinex bars before any portfolio
conclusion is drawn.

The February-September card mechanizes the paper's source-defined seasonal
holding window as one low-frequency WTI sleeve. It is deliberately separate
from the single-month March/April/August cards: instead of testing one month at
a time, it tests the broader seasonal allocation described by the source.

The September card isolates the terminal month of that source-defined
February-September holding window. It is a single-month validation of the
late-season segment, not another broad seasonal allocation or one of the
source-reported March/April/August positive-month tests.

The Brent February-September card ports that same source-window thesis to the
Brent benchmark, but keeps turnover low by testing only the first tradable D1
bar of each month in the window. It is separate from Brent March/April/August
single-month cards and from Brent weekday, trend, reversal, and spread builds.

The Brent September card isolates the terminal month of that same
source-defined February-September holding window on the Brent benchmark. It is
separate from the WTI September card by benchmark and from the Brent
February-September card by daily September-only exposure rather than one
first-tradable-day entry per month.

The Brent July card isolates a mid-window segment of the same source-defined
February-September holding window on the Brent benchmark. It is separate from
the broad Brent February-September card by daily July-only exposure, and from
the September terminal-month card by month timing.

The QM implementation does not import the paper's performance numbers into the
portfolio. Q02+ must validate each deterministic rule on the mapped Darwinex
XTIUSD.DWX or XBRUSD.DWX bars.

## Guardrails

- Runtime uses Darwinex MT5 OHLC and broker calendar only.
- No external API calls, CSV feeds, futures curve, inventory data, analyst
  forecast, or discretionary override.
- No ML, adaptive PnL fitting, grid, or martingale.
- One position per mapped Darwinex crude-oil symbol and magic slot.

## R-Rules

- R1 reputable source: PASS. Single academic paper source with URL.
- R2 mechanical: PASS. Fixed D1 month-of-year entry, ATR stop, and deterministic
  time exit.
- R3 data available: PASS. XTIUSD.DWX and XBRUSD.DWX exist in the DWX symbol
  matrix.
- R4 no ML/banned logic: PASS. Deterministic single-position calendar sleeve.
