---
source_id: EWALD-WTI-TRDTIME-2022
title: WTI and natural-gas trading-time seasonality
publisher: Energy Economics
source_type: peer_reviewed_paper
status: cards_ready
created: 2026-07-10
created_by: Codex
cards_extracted:
  - wti-juldec-short
  - xng-febjun-long
---

# Ewald et al. Energy Trading-Time Seasonality Source

## Source Identity

- Ewald, Christian-Oliver; Haugom, Erik; Lien, Gudbrand; Stordal, Stale; and
  Wu, Yuexiang. "Trading time seasonality in commodity futures: An
  opportunity for arbitrage in the natural gas and crude oil markets?"
  *Energy Economics* 115 (2022), article 106324.
- DOI: https://doi.org/10.1016/j.eneco.2022.106324.
- Open-access published version:
  https://eprints.gla.ac.uk/281581/1/281581.pdf.
- The full 17-page paper, including the empirical method, strategy section,
  risk discussion, limitations, and references, was reviewed on 2026-07-10.

## Bounded Extraction

The paper distinguishes trading-time seasonality from ordinary maturity-month
seasonality. Across fixed-maturity WTI futures contracts, its samples show the
highest prices when contracts are traded in July and the lowest when contracts
are traded in December. Across fixed-maturity natural-gas futures contracts,
prices are lowest when traded in February and highest when traded in June.
Section 5.1 turns those observations into matched-maturity short-WTI and
long-natural-gas rules.

The extraction is bounded to two source-defined, commodity-specific rules:
`wti-juldec-short` and `xng-febjun-long`. The Darwinex instruments are
continuous CFDs rather than matrices of fixed-maturity futures, so neither can
reproduce the paper's matched-maturity construction. Each card tests only the
directional carrier of its published effect using one D1 tranche on the first
tradable bar of each active week, flattened by the framework on Friday. Weekly
tranches preserve the source windows, avoid overlapping positions, and produce
enough independent packages for the binding Q02 frequency floor. No futures-
curve or maturity claim is made for either CFD translation.

## Evidence And Limitations

- Data in the paper: daily Henry Hub natural-gas and WTI futures prices,
  aggregated by trading month; the natural-gas samples span 1992-2020 and
  2006-2020, while WTI samples span 1995-2020 and 2006-2020.
- Statistical result: the Kruskal-Wallis no-seasonality null is rejected for
  both WTI groups at the reported 1% level.
- Trading rule: WTI is sold in July and the corresponding same-maturity
  position is closed in December.
- Trading rule: natural gas is bought in February and the corresponding same-
  maturity position is closed in June.
- The authors report significant CAPM alphas across WTI maturity panels, but
  also note large year-to-year payoff variation, unusually large 2008 gains,
  and five months of unhedged directional exposure.
- The authors state that the precise economic source of the seasonality remains
  unknown. They discuss pricing-kernel seasonality, hedging pressure, market
  sentiment, ESG preferences, and natural factors as possible mechanisms.
- Natural-gas results weaken in the later sample and include a large 2008
  contribution. That is an explicit fragility, not evidence for the CFD port.
- None of the paper's performance results are imported as an expectation for
  the Darwinex CFD port. Q02 and later gates must falsify or support it.

## Runtime Guardrails

- Native MT5 `XTIUSD.DWX` D1 OHLC, ATR, spread, broker calendar, and framework
  position state only.
- No futures curve, contract-maturity matrix, volume, open interest, options,
  inventory, WPSR, COT, OPEC, API, CSV, external feed, ML, grid, martingale,
  pyramiding, or discretionary switch.
- One short position on magic slot 0, with an ATR hard stop, seven-day stale
  guard, and framework Friday close.
- The natural-gas sibling uses one long `XNGUSD.DWX` position on magic slot 0
  with the same risk controls, but a locked February-May entry window.

## R-Rules

- R1 reputable source: PASS. Peer-reviewed *Energy Economics* paper with DOI
  and an open-access published version.
- R2 mechanical: PASS. Fixed commodity-specific weekly calendar gates, ATR
  stops, Friday flatten, and seven-day stale exits.
- R3 data available: PASS. `XTIUSD.DWX` and `XNGUSD.DWX` are registered in the
  DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic calendar-and-OHLC-only,
  single-position sleeve.
