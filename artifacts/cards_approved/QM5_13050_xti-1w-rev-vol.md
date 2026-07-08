---
ea_id: QM5_13050
slug: xti-1w-rev-vol
type: strategy
strategy_id: ZHAO-ST-MOMREV-2026_XTI_S02
source_id: ZHAO-ST-MOMREV-2026
source_citation: "Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets. SSRN, 2026."
source_citations:
  - type: academic_working_paper
    citation: "Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets. DOI 10.2139/ssrn.6425598."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598"
    quality_tier: B
    role: primary
markets: [XTIUSD.DWX]
timeframes: [D1]
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
status: APPROVED
g0_status: APPROVED
pipeline_phase: Q02
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_pf: 1.08
expected_dd_pct: 20.0
expected_trades_per_year_per_symbol: 8
expected_trade_frequency: "Weekly-gated WTI D1 short-term reversal with high-volatility filter; estimate 6-14 entries/year."
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual, low_frequency_sample_size]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
---

# QM5_13050 XTI One-Week High-Volatility Reversal

Farm-approved card mirror for Q02 enqueue. Full source card lives at
`strategy-seeds/cards/xti-1w-rev-vol_card.md`; seed-approved copy lives at
`strategy-seeds/cards/approved/QM5_13050_xti-1w-rev-vol_card.md`.

The EA trades `XTIUSD.DWX` on D1 only. It fades large prior 5-D1 XTI moves
when current 20-D1 realized volatility ranks high versus the prior 120
observations. Runtime uses only Darwinex MT5 D1 OHLC, spread, ATR, broker
calendar, news controls, and V5 framework state.

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy
manifest, `T_Live`, portfolio gate, or AutoTrading setting is touched.
