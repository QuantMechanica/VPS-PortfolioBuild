---
ea_id: QM5_13049
slug: xti-1w-mom-vol
type: strategy
strategy_id: ZHAO-ST-MOMREV-2026_XTI_S01
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
expected_trade_frequency: "Weekly-gated WTI D1 short-term momentum with low-volatility filter; estimate 6-14 entries/year."
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual, low_frequency_sample_size]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
---

# QM5_13049 XTI One-Week Low-Volatility Momentum

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/xti-1w-mom-vol_card.md`.

The EA trades `XTIUSD.DWX` on D1 only. It uses the short-horizon commodity
momentum evidence from Zhao, Ding, Yu, and Kang as structural lineage, but reads
no futures curve, COT, EIA, ETF roll, inventory, CSV, API, analyst calendar, or
ML output at runtime.

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy
manifest, `T_Live`, portfolio gate, or AutoTrading setting is touched.

## hypothesis

Short-term commodity continuation can persist when the recent move is large
enough and current realized volatility is not elevated. WTI gives the portfolio
an energy sleeve distinct from the existing index, metal, and natural-gas RSI
book exposure.

## rules

Trade `XTIUSD.DWX` D1 only. On each new broker D1 bar, compute the prior 5
closed-D1 return and the current 20-D1 realized volatility percentile versus
the prior 120 rolling realized-vol observations. Take at most one entry per
broker week. Enter only when the absolute 5-D1 return is above threshold and
the volatility percentile is at or below threshold.

## 4. entry rules

Enter long when the prior 5 closed D1 bars have returned at least the configured
positive threshold and current 20-D1 realized-volatility percentile is at or
below the configured cap. Enter short on the symmetric negative 5-D1 return.
One position per magic and one entry per broker week.

PARAMETERS

- strategy_momentum_lookback_days = 5
- strategy_min_week_return_pct = 1.25
- strategy_vol_window_d1 = 20
- strategy_vol_rank_lookback_d1 = 120
- strategy_max_vol_pctile = 55.0
- strategy_atr_period = 20
- strategy_atr_sl_mult = 2.50
- strategy_hold_days = 7
- strategy_exit_reverse_pct = 0.50
- strategy_max_spread_points = 1200

## 5. exit rules

Use an ATR hard stop, a 7-calendar-day time exit, an opposite 5-D1 return
reversal exit, standard news handling, and Friday close. There is no fixed TP;
the edge is managed by stop, time, and reversal.

## 6. filters (no-trade module)

Require `XTIUSD.DWX`, D1, magic slot 0, valid D1 close/ATR/realized-vol data,
spread at or below cap, and standard V5 news/kill-switch guards.

## 7. trade management rules

One position per magic/symbol. No pyramiding, grid, martingale, partial close,
external runtime feed, cross-symbol state, adaptive PnL fitting, or ML.

## risk

Q02 backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one
`XTIUSD.DWX` D1 setfile. Live risk is not configured by this card.
