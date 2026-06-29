---
ea_id: QM5_12808
slug: ftmo-xti-pb
type: strategy
strategy_id: FTMO-MAR2026-XTI-PORTFOLIO_S01
source_id: FTMO-MAR2026-XTI-PORTFOLIO
source_citation: "Local QM inventory of OWNER FTMO March 2026 portfolio package: docs/research/dropbox/existing_ea_inventory.md, row FTMO_XTIUSD_Portfolio_v1."
sources:
  - "[[sources/FTMO-MAR2026-XTI-PORTFOLIO]]"
concepts:
  - "[[concepts/wti-trend-pullback]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
strategy_type_flags: [trend-pullback, multi-timeframe-filter, atr-hard-stop, signal-reversal-exit, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
timeframes: [H4]
single_symbol_only: true
period: H4
expected_trade_frequency: "D1/H4 WTI trend-pullback package; estimate 8-24 entries/year after D1 regime, H4 reclaim, spread, and framework filters."
expected_trades_per_year_per_symbol: 16
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS single local code-first FTMO March 2026 XTIUSD package lineage; R2 PASS deterministic D1 EMA regime plus H4 EMA pullback/reclaim, ATR stop, trend invalidation, and max-hold exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
---

# FTMO XTI Trend Pullback

Canonical approved card:
`strategy-seeds/cards/approved/QM5_12808_ftmo-xti-pb_card.md`.

Summary: H4 `XTIUSD.DWX` trend-pullback sleeve from the local FTMO March 2026
XTIUSD portfolio inventory. It trades in the D1 EMA trend direction after a H4
pullback into EMA(50) and reclaim of EMA(21), with an ATR hard stop and
trend/time exits. Runtime uses Darwinex OHLC only.

Runtime scope: build and Q02 queue only. No `T_Live` manifest, AutoTrading,
deploy manifest, or portfolio gate is touched.

## hypothesis

WTI crude oil trends can persist when the higher-timeframe regime is aligned,
but cleaner entries may come after a pullback into the H4 moving-average zone
and a reclaim in the D1 trend direction.

## rules

- Long: D1 EMA(50) > EMA(200), rising EMA(50), D1 close above EMA(50), and H4
  pullback/reclaim above EMA(21).
- Short: D1 EMA(50) < EMA(200), falling EMA(50), D1 close below EMA(50), and H4
  pullback/reclaim below EMA(21).
- Exit on ATR stop, H4 EMA(50) invalidation, D1 trend invalidation, or max-hold.

## risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one H4 setfile for
`XTIUSD.DWX`. Future live risk must come from the portfolio process.
