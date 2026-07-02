---
source_id: KOIJEN-CARRY-2018
title: Koijen-Moskowitz-Pedersen-Vrugt cross-asset carry
publisher: Journal of Financial Economics
source_type: academic_paper
status: cards_ready
created: 2026-07-02
created_by: Codex
uri: https://doi.org/10.1016/j.jfineco.2017.11.002
cards_extracted:
  - xng-12m-carry
  - xti-12m-carry
---

# Koijen Cross-Asset Carry Source

## Source Identity

- Koijen, Ralph S. J., Tobias J. Moskowitz, Lasse Heje Pedersen, and
  Evert B. Vrugt, "Carry", Journal of Financial Economics, 127(2), 2018,
  pages 197-225. DOI: https://doi.org/10.1016/j.jfineco.2017.11.002.
- NBER working-paper lineage: https://www.nber.org/papers/w19325.

## Research Use

The source is used for structural lineage around carry as an ex-ante return
component observable before price movement and applicable across asset classes,
including commodities. QM ports the concept to Darwinex commodity CFDs by using
MT5 broker swap fields as the observable carry side when available.

The runtime implementation does not ingest futures curves, inventory reports,
term-structure data, APIs, CSV files, analyst forecasts, or external feeds. For
`.DWX` tester symbols that expose both swap fields as zero, the card must
document any deterministic fallback direction so the pipeline can test a
deliberate sleeve instead of a zero-trade data artifact.

## Guardrails

- Runtime uses Darwinex MT5 broker swap fields, OHLC, spread, ATR, and broker
  calendar only.
- No external API calls or CSV dependencies.
- No ML, adaptive PnL fitting, grid, martingale, pyramiding, or discretionary
  override.
- One position per magic/symbol.

## R-Rules

- R1 reputable source: PASS. Peer-reviewed Journal of Financial Economics paper
  with DOI and NBER working-paper lineage.
- R2 mechanical: PASS. Broker-swap direction, fixed weekly rebalance, ATR hard
  stop, 12-month adverse-drift guard, and max-hold exit are deterministic.
- R3 data available: PASS. `XNGUSD.DWX` and `XTIUSD.DWX` exist in the DWX
  symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic single-position carry sleeves.
