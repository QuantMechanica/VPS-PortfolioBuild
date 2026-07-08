---
ea_id: QM5_13055
slug: xbr-1w-mom-vol
type: strategy
strategy_id: ZHAO-ST-MOMREV-2026_XBR_S03
source_id: ZHAO-ST-MOMREV-2026
source_citation: "Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets. SSRN, 2026."
source_citations:
  - type: academic_working_paper
    citation: "Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets. DOI 10.2139/ssrn.6425598."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598"
    quality_tier: B
    role: primary
  - type: exchange_reference
    citation: "CME Group. Brent Last Day Financial futures product overview."
    location: "https://www.cmegroup.com/markets/energy/crude-oil/brent-last-day-financial.html"
    quality_tier: A
    role: market_context
markets: [XBRUSD.DWX]
timeframes: [D1]
primary_target_symbols: [XBRUSD.DWX]
target_symbols: [XBRUSD.DWX]
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
expected_trade_frequency: "Weekly-gated Brent D1 short-term momentum with low-volatility filter; estimate 6-14 entries/year."
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [xbr_history_sufficiency, friday_close, magic_schema, risk_mode_dual, low_frequency_sample_size]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-08: R1 PASS academic short-horizon commodity momentum/reversal source plus CME Brent market context; R2 PASS deterministic D1 five-day return direction, realized-volatility percentile gate, weekly entry cadence, ATR stop, opposite-return exit, and time exit; R3 PASS XBRUSD.DWX local route used by recent Brent builds, with Q02 validating current history sufficiency; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate because this is Brent one-week low-volatility continuation, not WTI one-week continuation/reversal, Brent TOM, Brent fixed month/weekday, Brent 12-month trend, Brent 52-week anchor, Brent/WTI spread, oil-metal ratio, XNG, XAU/XAG, index, or commodity RSI logic."
---

# QM5_13055 XBR One-Week Low-Volatility Momentum

The EA trades `XBRUSD.DWX` on D1 only. It uses the short-horizon commodity
momentum evidence from Zhao, Ding, Yu, and Kang as structural lineage, but reads
no futures curve, COT, EIA, ETF roll, inventory, CSV, API, analyst calendar, or
ML output at runtime.

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy
manifest, `T_Live`, portfolio gate, or AutoTrading setting is touched.

## hypothesis

Short-term commodity continuation can persist when the recent move is large
enough and current realized volatility is not elevated. Brent gives the
portfolio a crude-energy sleeve distinct from the existing index, metal, and
natural-gas book exposure.

This is not a duplicate of `QM5_13049_xti-1w-mom-vol`, which tests the same
low-volatility continuation branch on WTI, or `QM5_13050_xti-1w-rev-vol`, which
fades a WTI one-week move in high-volatility conditions. It is also distinct
from Brent TOM, Brent month/weekday seasonality, Brent TSMOM, Brent 52-week
anchor, Brent/WTI, XBR/XNG, Brent/CAD, oil-metal, XAU/XAG, XNG, index, and
commodity RSI sleeves.

## rules

Trade `XBRUSD.DWX` D1 only. On each new broker D1 bar, compute the prior 5
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

Require `XBRUSD.DWX`, D1, magic slot 0, valid D1 close/ATR/realized-vol data,
spread at or below cap, and standard V5 news/kill-switch guards.

## 7. trade management rules

One position per magic/symbol. No pyramiding, grid, martingale, partial close,
external runtime feed, cross-symbol state, adaptive PnL fitting, or ML.

## risk

Q02 backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one
`XBRUSD.DWX` D1 setfile. Live risk is not configured by this card.

## Framework Alignment

- no_trade: XBR/D1 host guard, magic-slot guard, valid parameter checks, data
  sufficiency checks, spread cap, and V5 framework gates.
- trade_entry: weekly-gated D1 five-day continuation when realized-volatility
  percentile is not elevated.
- trade_management: time exit and opposite-return exit.
- trade_close: ATR hard stop, framework Friday close, and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-08 | initial XBR one-week low-volatility momentum build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-08 | APPROVED | this card |
| Q01 Build Validation | 2026-07-08 | PENDING | `artifacts/qm5_13055_build_result.json` |
| Q02 Baseline Screening | 2026-07-08 | PENDING | `artifacts/qm5_13055_q02_enqueue_20260708.json` |
