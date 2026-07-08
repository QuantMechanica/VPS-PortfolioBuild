---
ea_id: QM5_13051
slug: xng-vrp-proxy
type: strategy
strategy_id: TROLLE-SCHWARTZ-ENERGY-VRP-2008_XNG_PROXY
source_id: TROLLE-SCHWARTZ-ENERGY-VRP-2008
source_citations:
  - type: academic_paper
    citation: "Trolle, Anders B. and Schwartz, Eduardo S. (2008). Variance risk premia in energy commodities."
    location: "https://www.anderson.ucla.edu/documents/areas/fac/finance/schwartz_risk_premia.pdf"
    quality_tier: A
    role: primary
  - type: academic_working_paper
    citation: "BIS Working Papers No. 619. Volatility risk premia and future commodities returns."
    location: "https://www.bis.org/publ/work619.pdf"
    quality_tier: A
    role: supporting
markets: [XNGUSD.DWX]
timeframes: [D1]
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
status: APPROVED
g0_status: APPROVED
pipeline_phase: Q02
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_pf: 1.08
expected_dd_pct: 24.0
expected_trades_per_year_per_symbol: 8
expected_trade_frequency: "D1 high-realized-volatility natural-gas stretch reversion; estimate 5-12 trades/year."
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual, low_frequency_sample_size]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
---

# QM5_13051 XNG VRP Proxy

Farm-approved card mirror for Q02 enqueue. Full source card lives at
`strategy-seeds/cards/xng-vrp-proxy_card.md`; seed-approved copy lives at
`strategy-seeds/cards/approved/QM5_13051_xng-vrp-proxy_card.md`.

The EA trades `XNGUSD.DWX` on D1 only. It uses energy variance-risk-premium
literature as structural lineage, but runtime does not read option chains,
variance swap rates, futures curves, EIA data, APIs, CSV files, or news feeds.
It computes a natural-gas realized-volatility percentile from Darwinex D1 OHLC
and fades ATR-normalized stretch/reversal states back toward a slow mean.

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy
manifest, `T_Live`, portfolio gate, or AutoTrading setting is touched.
