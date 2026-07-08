---
ea_id: QM5_13056
slug: xbr-1w-rev-vol
type: strategy
strategy_id: ZHAO-ST-MOMREV-2026_XBR_S04
source_id: ZHAO-ST-MOMREV-2026
source_citation: "Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets. SSRN, 2026."
source_citations:
  - type: academic_working_paper
    citation: "Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets. DOI 10.2139/ssrn.6425598."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598"
    quality_tier: B
    role: primary
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
expected_trade_frequency: "Weekly-gated Brent D1 short-term reversal with high-volatility filter; estimate 6-14 entries/year."
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [xbr_history_sufficiency, friday_close, magic_schema, risk_mode_dual, low_frequency_sample_size]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
---

# QM5_13056 XBR One-Week High-Volatility Reversal

Approved build copy of `strategy-seeds/cards/xbr-1w-rev-vol_card.md`.

## hypothesis

Short-term commodity reversal can appear after large one-week moves when
realized volatility is elevated. Brent gives the portfolio a crude-energy
sleeve distinct from the existing index, metal, and natural-gas book exposure.

## rules

Trade `XBRUSD.DWX` D1 only. On each new broker D1 bar, compute the prior 5
closed-D1 return and the current 20-D1 realized volatility percentile versus
the prior 120 rolling realized-vol observations. Take at most one entry per
broker week.

## 4. entry rules

Enter long when the prior 5 closed D1 bars have fallen at least the configured
negative threshold and volatility percentile is at or above the configured
floor. Enter short on the symmetric positive 5-D1 return.

## 5. exit rules

Use an ATR hard stop, 5-calendar-day time exit, neutral-return exit, news
handling, and framework Friday close.

## 6. filters (no-trade module)

Require `XBRUSD.DWX`, D1, magic slot 0, valid D1 close/ATR/realized-vol data,
spread at or below cap, and standard V5 guards.

## 7. trade management rules

One position per magic/symbol. No pyramiding, grid, martingale, partial close,
external runtime feed, adaptive PnL fitting, or ML.

## risk

Q02 backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one
`XBRUSD.DWX` D1 setfile. Live risk is not configured by this card.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-08 | initial XBR one-week high-volatility reversal build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-08 | APPROVED | this card |
| Q01 Build Validation | 2026-07-08 | PASS | `artifacts/qm5_13056_build_result.json` |
| Q02 Baseline Screening | 2026-07-08 | QUEUED | `artifacts/qm5_13056_q02_enqueue_20260708.json` |
