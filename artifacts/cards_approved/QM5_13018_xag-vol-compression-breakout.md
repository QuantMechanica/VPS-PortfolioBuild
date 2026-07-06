---
ea_id: QM5_13018
slug: xag-vol-compression-breakout
type: strategy
strategy_id: GR-COMMODITY-FACTS-2006_XAG-VOLCOMP
source_id: GR-COMMODITY-FACTS-2006
source_citation: "Gorton and Rouwenhorst (2006), Facts and Fantasies about Commodity Futures, Financial Analysts Journal; Erb and Harvey (2006), The Strategic and Tactical Value of Commodity Futures, Financial Analysts Journal."
source_citations:
  - type: academic_journal
    citation: "Gorton, Gary and K. Geert Rouwenhorst. Facts and Fantasies about Commodity Futures. Financial Analysts Journal, 62(2), 2006."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=560042"
    quality_tier: A
    role: primary
  - type: academic_journal
    citation: "Erb, Claude B. and Campbell R. Harvey. The Strategic and Tactical Value of Commodity Futures. Financial Analysts Journal, 62(2), 2006."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=650923"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/GR-COMMODITY-FACTS-2006]]"
concepts:
  - "[[concepts/volatility-compression]]"
  - "[[concepts/donchian-breakout]]"
  - "[[concepts/commodity-vol-cycle]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/donchian-channel]]"
strategy_type_flags: [vol-compression-filter, donchian-breakout, atr-hard-stop, channel-trail, time-stop, commodity-sleeve]
target_symbols: [XAGUSD.DWX]
primary_target_symbols: [XAGUSD.DWX]
markets: [XAGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13018_XAG_VOLCOMP_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XAG compression-filtered Donchian breakout; estimate 8-14 entries/year after the compression tercile filter gates the breakout signal."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-06
expected_pf: 1.15
expected_dd_pct: 18.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-06 (Claude, Fable program #5): R1 Gorton/Rouwenhorst and Erb/Harvey Financial Analysts Journal commodity vol-cycle sources; R2 deterministic rules below; R3 symbols verified in DWX matrix; R4 no ML/grid/martingale/external runtime data."
---

# XAG D1 Volatility-Compression Breakout

## Source

- Source: [[sources/GR-COMMODITY-FACTS-2006]]
- Primary citation: Gorton, Gary and K. Geert Rouwenhorst. "Facts and
  Fantasies about Commodity Futures." Financial Analysts Journal, 62(2), 2006.
  URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=560042.
- Supplement: Erb, Claude B. and Campbell R. Harvey. "The Strategic and
  Tactical Value of Commodity Futures." Financial Analysts Journal, 62(2),
  2006. URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=650923.

## Hypothesis

Silver alternates long volatility-compression phases with expansion bursts.
The commodity vol-cycle literature (Gorton/Rouwenhorst, Erb/Harvey) documents
that commodity returns are episodic and volatility-clustered rather than
smoothly trending. Breakouts that emerge from a compression phase carry
follow-through because the expansion burst that resolves the compression
tends to persist for days to weeks. This card trades only those breakouts:
a Donchian(20) D1 channel break taken exclusively while ATR(10) sits in the
bottom tercile of its trailing 120-bar range.

## Mechanism

- Compression filter: on each completed `XAGUSD.DWX` D1 bar, compute ATR(10)
  and the min/max of ATR(10) over the trailing 120 D1 bars. The market is
  "compressed" when the current ATR(10) is in the bottom tercile of that
  min-max range.
- Breakout trigger: while compressed, a D1 close above the Donchian(20) high
  signals a long expansion burst; a D1 close below the Donchian(20) low
  signals a short expansion burst.
- Exit engine: fixed ATR hard stop, opposite Donchian(10) channel trail, and
  a max-hold time stop, so every trade has a deterministic lifecycle.

This is deliberately different from existing XAG exposure: no XAU/XAG ratio,
oil/silver or gas/silver return-spread basket, RSI pullback, or calendar
sleeve is used — this is a single-symbol volatility-cycle breakout on silver.

## Markets And Timeframe

- Symbol: `XAGUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: about 8-14 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker time, and V5
  framework state only. No futures-curve, COT, ETF-flow, CSV, API, or ML
  input is consumed at runtime.

## Rules

### Entry

- Evaluate only on a new `XAGUSD.DWX` D1 bar, using completed bars.
- Compute ATR(`strategy_atr_compress_period`) on D1 (default 10).
- Compute the min and max of that ATR series over the trailing
  `strategy_compress_window_d1` bars (default 120).
- Compression is true when
  `ATR <= ATR_min + (ATR_max - ATR_min) * strategy_compress_pct / 100`
  (default 33.3 = bottom tercile of the trailing ATR range).
- Entry Long: compression is true AND the D1 close is above the
  Donchian(`strategy_donchian_entry`) high of the prior bars (default 20).
- Entry Short: compression is true AND the D1 close is below the
  Donchian(`strategy_donchian_entry`) low of the prior bars (default 20).
- One position at a time: no entry while a position is open for this magic.
- No entry if `XAGUSD.DWX` spread exceeds `strategy_max_spread_points`.

### Exit & Stops

- Hard stop: fixed SL at ATR(`strategy_atr_period`, default 14) times
  `strategy_atr_sl_mult` (default 2.5) from entry price.
- Channel trail: long exits on a D1 close below the
  Donchian(`strategy_donchian_trail`) low (default 10); short exits on a D1
  close above the Donchian(`strategy_donchian_trail`) high (mirrored).
- Time stop: close after `strategy_max_hold_bars` D1 bars (default 40).
- Friday close remains enabled by the V5 framework.

## Risk & Filters

- Only trade `XAGUSD.DWX` on D1 with `qm_magic_slot_offset=0`.
- Skip entries when D1 history, ATR series, Donchian levels, or spread data
  are unavailable.
- Skip entries when spread exceeds the configured cap.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding, gridding, martingale, or partial close.
- The Donchian(10) trail is the only position management; no stop tightening
  beyond the channel trail.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_atr_compress_period
  default: 10
  sweep_range: [7, 10, 14]
- name: strategy_compress_window_d1
  default: 120
  sweep_range: [80, 120, 160]
- name: strategy_compress_pct
  default: 33.3
  sweep_range: [25.0, 33.3, 40.0]
- name: strategy_donchian_entry
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_donchian_trail
  default: 10
  sweep_range: [8, 10, 15]
- name: strategy_atr_period
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_max_hold_bars
  default: 40
  sweep_range: [30, 40, 55]
- name: strategy_max_spread_points
  default: 200
  sweep_range: [120, 200, 300]

## Expected Behavior

- Long flat stretches while silver is either non-compressed or compressed
  without a channel break; activity clusters at regime transitions.
- Winners are expansion bursts held via the Donchian(10) trail; losers are
  failed breakouts cut at the ATR hard stop.
- expected_pf 1.15, expected_dd_pct 18, approximately 10 trades/year — the
  compression filter trades breadth for follow-through quality. Q02 must
  confirm the filter earns its frequency cost against the Q02 trade floor.

## Author Claims

The sources establish structural lineage for commodity volatility cycles and
episodic returns only. This card imports no source performance number. Q02
and later phases must validate or reject the mechanical `XAGUSD.DWX`
realization on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.15.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 8-14 entries/year.
- risk_class: medium — silver gaps and vol bursts are real but the ATR hard
  stop and time stop bound each trade.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Gorton/Rouwenhorst and Erb/Harvey Financial
  Analysts Journal commodity vol-cycle literature.
- [x] R2 mechanical: fixed ATR-tercile compression filter, Donchian(20)
  breakout entry, ATR hard stop, Donchian(10) trail, and time stop.
- [x] R3 testable: `XAGUSD.DWX` exists in the DWX symbol matrix with D1
  history 2017-2026.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: not XAU/XAG ratio, oil/silver or gas/silver basket,
  RSI pullback, calendar, or seasonal silver logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XAGUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the
portfolio gate.

## Framework Alignment

- no_trade: XAG/D1 host guard, magic-slot guard, parameter guard, spread cap,
  compression-filter guard, and valid data checks.
- trade_entry: compression-gated Donchian(20) D1 breakout, long and short.
- trade_management: Donchian(10) channel trail and max-hold tracking.
- trade_close: ATR hard stop, channel-trail exit, time stop, and framework
  Friday close.

## Kill Criteria

Kill or recycle the card if Q02 cannot produce the card-scaled minimum trade
count, if Q02 PF is below 1.0 after costs, or if the compression filter
degenerates (filter never true or always true) on Darwinex XAG history.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-06 | initial XAG vol-compression breakout card | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-06 | APPROVED | this card |
| Q01 Build Validation | 2026-07-06 | PENDING | `artifacts/qm5_13018_build_result.json` |
| Q02 Baseline Screening | 2026-07-06 | PENDING | enqueue after compile |
