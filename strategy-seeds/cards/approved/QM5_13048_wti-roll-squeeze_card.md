---
ea_id: QM5_13048
slug: wti-roll-squeeze
type: strategy
strategy_id: CFTC-ETF-ROLL-WTI-SQUEEZE-2026
source_id: CFTC-ETF-ROLL-WTI-2014
source_citation: "Mou, Y. Predatory or Sunshine Trading? Evidence from Crude Oil ETF Rolls. CFTC Office of the Chief Economist."
source_citations:
  - type: official_government_research_paper
    citation: "Mou, Y. Predatory or Sunshine Trading? Evidence from Crude Oil ETF Rolls. CFTC Office of the Chief Economist."
    location: "https://www.cftc.gov/sites/default/files/idc/groups/public/@economicanalysis/documents/file/oce_predatorysunshine0314.pdf"
    quality_tier: A
    role: primary
markets: [XTIUSD.DWX]
timeframes: [D1]
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
status: APPROVED
g0_status: APPROVED
pipeline_phase: Q02
expected_pf: 1.08
expected_dd_pct: 20.0
expected_trade_frequency: "Early-month WTI ETF-roll compression breakout; estimate 4-9 entries/year."
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [roll_window_sample_size, friday_close, magic_schema, risk_mode_dual]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
---

# QM5_13048 WTI ETF Roll-Window Squeeze Breakout

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/wti-roll-squeeze_card.md`.

The EA trades `XTIUSD.DWX` on D1 only. It uses the official CFTC crude-oil ETF
roll research paper as structural lineage but reads no ETF holdings, futures
curve, CFTC file, COT data, CSV, API, analyst calendar, or ML output at
runtime. It trades at most one early-month roll-window compression breakout per
broker-calendar month and exits by ATR stop/target, SMA failure, exit-window,
month change, time, standard news handling, and Friday close.

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy
manifest, `T_Live`, portfolio gate, or AutoTrading setting is touched.

## hypothesis

Predictable early-month crude-oil ETF roll activity can turn a compressed WTI
D1 range into a tradable breakout. The card imports no CFTC performance claim.

## rules

Trade `XTIUSD.DWX` D1 only. The prior completed D1 bar must be inside broker
trading days 5-9 of the month, the preceding D1 range must be compressed, and
the signal close must break the pre-signal channel. One entry per month.

## 4. entry rules

Enter long on an upside closed-bar channel break, or short on a downside
closed-bar channel break, after the roll-window and compression filters pass.

## 5. exit rules

Use ATR stop, ATR target, SMA failure, exit-window, month-change, max-hold, and
Friday-close exits.

## 6. filters (no-trade module)

Require `XTIUSD.DWX`, D1, magic slot 0, valid D1 OHLC/ATR/SMA/channel data,
spread at or below cap, and standard V5 news/kill-switch guards.

## 7. trade management rules

One position per magic/symbol. No pyramiding, grid, martingale, partial close,
trailing stop, external runtime feed, or ML.

## risk

Q02 backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one
`XTIUSD.DWX` D1 setfile. Live risk is not configured by this card.
