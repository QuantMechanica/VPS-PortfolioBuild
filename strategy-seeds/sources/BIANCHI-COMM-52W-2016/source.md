---
source_id: BIANCHI-COMM-52W-2016
title: Bianchi-Drew-Fan commodity 52-week high momentum
publisher: Journal of Banking and Finance / SSRN preprint
source_type: academic_paper
status: mined
last_reviewed: 2026-06-29
cards_extracted:
  - wti-52w-anchor
  - xng-52w-anchor
  - brent-52w-anchor
  - wti-6m-reversal
  - brent-6m-rev
---

# Bianchi-Drew-Fan Commodity 52-Week High Source

## Source Identity

- Bianchi, R. J., Drew, M. E., and Fan, J. H., "Commodities momentum: A
  behavioural perspective", Journal of Banking and Finance, 2016.
- Primary DOI pointer: https://doi.org/10.1016/j.jbankfin.2016.06.010
- Public preprint pointer: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2571725

## Research Use

This source is used for structural lineage around commodity momentum being
observable through a 52-week high anchor. The QM implementation ports the
idea first to a Darwinex-native WTI CFD rule, then to independent natural-gas
and Brent ports: once per month, buy only when the prior close is near its own
252-D1 close high and the 63-D1 return confirms; sell only when the prior close
is near its own 252-D1 close low and the 63-D1 return confirms.

The EA does not ingest futures-chain data, inventory data, CFTC data,
analyst forecasts, APIs, CSV files, or external feeds at runtime. It uses only
Darwinex MT5 D1 close data, broker calendar, spread, ATR, and the V5 framework
risk/news/friday-close guards.

`wti-6m-reversal` uses this source only as behavioural commodity-overextension
lineage, with Yang-Goncu-Pantelous as the direct reversal supplement. It is a
monthly WTI 120-D1 overextension fade, not the 52-week high/low momentum-anchor
rule and not the shorter 20-D1 or 63-D1 WTI reversal cards.

`brent-6m-rev` applies the same intermediate overextension-fade structure to
`XBRUSD.DWX`. It is intentionally separate from the Brent 52-week anchor
momentum port, Brent calendar cards, WTI 6-month reversal, WTI/Brent spread
cards, and XNG/metal sleeves.

## R-Rules

- R1 reputable source: PASS. Peer-reviewed finance journal paper with SSRN
  preprint lineage.
- R2 mechanical: PASS. Fixed D1 252-bar anchor, fixed D1 63-bar confirmation,
  monthly calendar gate, ATR hard stop, and max-hold exit are deterministic.
- R3 data available: PASS. `XTIUSD.DWX` and `XNGUSD.DWX` exist in the DWX
  symbol matrix; `XBRUSD.DWX` has active local Brent build routes and Q02
  validates current history sufficiency.
- R4 no ML/banned logic: PASS. No ML, adaptive fitting, grid, martingale,
  external API, or discretionary input.
