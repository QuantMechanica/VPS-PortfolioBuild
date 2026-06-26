---
source_id: CME-GSR-SPREAD-2025
title: CME Group gold-silver ratio spread research
status: cards_ready
created: 2026-06-26
created_by: Codex
source_type: exchange_education
uri: https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade
---

# CME Group Gold-Silver Ratio Spread Research

## Source Identity

- Publisher: CME Group.
- Primary source: CME Group, "Gold & Silver Ratio Spread", URL https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade.
- Supplement: CME Group, "Spread Trading Opportunities with Precious Metals", URL https://www.cmegroup.com/education/articles-and-reports/spread-trading-opportunities-with-precious-metals.
- Supplement: CME Group, "Four Major Drivers of the Gold-Silver Price Ratio", URL https://www.cmegroup.com/insights/economic-research/2025/four-major-drivers-of-the-gold-silver-price-ratio.html.

## Mining Scope

One card was extracted for a structural precious-metals basket sleeve:

- `cme-xauxag-ratio`: XAUUSD.DWX/XAGUSD.DWX D1 gold-silver ratio z-score reversion basket.

## Evidence Notes

- CME defines the gold-silver ratio as gold price divided by silver price on a per-troy-ounce basis.
- CME documents that gold and silver are related precious metals with different macro drivers: gold has more monetary/safe-haven behavior, while silver has more industrial-cycle exposure.
- CME presents the gold-silver ratio as an intermarket spread that can be traded through gold and silver instruments.
- The QM implementation does not ingest CME data, futures curves, inventory data, or external APIs at runtime. It mechanizes the relationship with Darwinex MT5 XAUUSD.DWX and XAGUSD.DWX closes only.

## Guardrails

- No external data calls in the EA.
- No ML, no adaptive parameter fitting, no grid, no martingale.
- The ratio is traded as one logical basket work item, not as standalone per-leg directional systems.
