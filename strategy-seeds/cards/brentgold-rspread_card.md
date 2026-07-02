---
ea_id: QM5_12867
slug: brentgold-rspread
type: strategy
strategy_id: CME-OIL-GOLD-RATIO-2024_BRENT_S04
source_id: CME-OIL-GOLD-RATIO-2024
sources:
  - "[[sources/CME-OIL-GOLD-RATIO-2024]]"
strategy_type_flags: [market-neutral-basket, oil-gold-relative-value, return-spread-zscore, mean-reversion-exit, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XBRUSD.DWX, XAUUSD.DWX]
primary_target_symbols: [XBRUSD.DWX, XAUUSD.DWX]
markets: [XBRUSD.DWX, XAUUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_12867_XBR_XAU_RSPREAD_D1
period: D1
g0_status: APPROVED
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-02
ml_required: false
---

# Brent/Gold Return-Spread Reversion

Canonical approved card:

`strategy-seeds/cards/approved/QM5_12867_brentgold-rspread_card.md`

This card implements a low-frequency paired Brent/gold return-spread reversion
test from the existing CME oil-through-gold source packet. Runtime uses
Darwinex MT5 OHLC only. No external feed, ML, grid, martingale, live manifest,
`T_Live`, portfolio gate, or AutoTrading change is part of this card.
