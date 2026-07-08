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

Embedded approved strategy card for the EA build. Canonical repo card:
`strategy-seeds/cards/approved/QM5_13049_xti-1w-mom-vol_card.md`.

## hypothesis

Short-term commodity continuation can persist when the recent move is large
enough and current realized volatility is not elevated.

## rules

Trade `XTIUSD.DWX` D1 only. Use prior 5 closed-D1 return for direction and
current 20-D1 realized-volatility percentile versus the prior 120 observations
as the entry regime filter.

## 4. entry rules

Long above the configured positive 5-D1 return threshold; short below the
symmetric negative threshold. Volatility percentile must be at or below cap.

## 5. exit rules

ATR hard stop, 7-calendar-day time exit, opposite 5-D1 return reversal exit,
standard news handling, and Friday close.

## 6. filters (no-trade module)

Require `XTIUSD.DWX`, D1, magic slot 0, valid D1 close/ATR/realized-vol data,
and spread at or below cap.

## 7. trade management rules

One position per magic/symbol; no grid, martingale, pyramiding, external feed,
adaptive PnL fitting, or ML.

## risk

Q02 backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`.
