---
source_id: BIANCHI-COMM-52W-2016
title: Bianchi-Drew-Fan commodity 52-week high momentum
publisher: Journal of Banking and Finance / SSRN preprint
source_type: academic_paper
status: mined
last_reviewed: 2026-06-29
cards_extracted:
  - wti-52w-anchor
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
idea to a Darwinex-native WTI CFD rule: once per month, buy WTI only when the
prior close is near its own 252-D1 close high and the 63-D1 return confirms;
sell only when the prior close is near its own 252-D1 close low and the 63-D1
return confirms.

The EA does not ingest futures-chain data, inventory data, CFTC data,
analyst forecasts, APIs, CSV files, or external feeds at runtime. It uses only
Darwinex MT5 D1 close data, broker calendar, spread, ATR, and the V5 framework
risk/news/friday-close guards.

## R-Rules

- R1 reputable source: PASS. Peer-reviewed finance journal paper with SSRN
  preprint lineage.
- R2 mechanical: PASS. Fixed D1 252-bar anchor, fixed D1 63-bar confirmation,
  monthly calendar gate, ATR hard stop, and max-hold exit are deterministic.
- R3 data available: PASS. `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. No ML, adaptive fitting, grid, martingale,
  external API, or discretionary input.
