---
ea_id: QM5_12979
slug: wti-6m-reversal
type: strategy
strategy_id: BIANCHI-COMM-52W-2016_XTI_6M_REV
source_id: BIANCHI-COMM-52W-2016
source_citation: "Bianchi, R. J., Drew, M. E. and Fan, J. H. Commodities momentum: A behavioural perspective. Journal of Banking and Finance, 2016. DOI https://doi.org/10.1016/j.jbankfin.2016.06.010; Yang, Goncu, and Pantelous. Momentum and Reversal in Commodity Futures. SSRN working paper."
source_citations:
  - type: paper
    citation: "Bianchi, R. J., Drew, M. E. and Fan, J. H. (2016). Commodities momentum: A behavioural perspective. Journal of Banking and Finance."
    location: "https://doi.org/10.1016/j.jbankfin.2016.06.010"
    quality_tier: A
    role: primary
  - type: paper
    citation: "Yang, Goncu, and Pantelous. Momentum and Reversal in Commodity Futures."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/BIANCHI-COMM-52W-2016]]"
  - "[[sources/YANG-COMM-REVERSAL-2017]]"
concepts:
  - "[[concepts/commodity-reversal]]"
  - "[[concepts/medium-horizon-overextension]]"
  - "[[concepts/energy-mean-reversion]]"
indicators:
  - "[[indicators/rolling-return-120]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [medium-horizon-reversal, return-threshold-fade, atr-hard-stop, time-stop, monthly-rebalance, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12979_XTI_6M_REVERSAL_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly D1 WTI 6-month overextension fade; estimate 4-9 entries/year after threshold, SMA/ATR stretch, spread, and one-entry-per-month filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.08
expected_dd_pct: 22.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS peer-reviewed Bianchi-Drew-Fan commodity behavioural source plus Yang-Goncu-Pantelous commodity reversal supplement; R2 PASS deterministic monthly 120-D1 WTI return threshold, SMA/ATR stretch confirmation, ATR stop, zero-cross exit, and max-hold exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data. Non-duplicate versus existing WTI sleeves because this is a monthly 6-month overextension fade, not 20-D1 reversal, 63-D1 reversal, 9/12-month momentum, 12-month carry, or calendar/event logic."
---

# WTI 6-Month Overextension Fade

See canonical card: `strategy-seeds/cards/wti-6m-reversal_card.md`.

This approved card mechanizes a monthly `XTIUSD.DWX` D1 120-bar overextension
fade using Darwinex MT5 OHLC only. It is not a metal, index, XNG, ratio-basket,
RSI pullback, WTI event, WTI calendar, WTI 20-D1 reversal, WTI 63-D1 reversal,
or WTI 9/12-month momentum/carry sleeve. Backtests use `RISK_FIXED=1000` and
no live or portfolio-gate files are touched.
