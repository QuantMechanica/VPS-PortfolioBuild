---
ea_id: QM5_12851
slug: williams18-xti
type: strategy
strategy_id: SRC03_S12_XTI_20260701
source_id: SRC03
source_citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. Local SRC03 source packet."
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "SRC03 raw/probe_pp15-30.txt, PDF p.17, 18-Bar Two-Bar MA Entry."
    quality_tier: A
    role: primary
sources:
  - "[[sources/SRC03]]"
concepts:
  - "[[concepts/commodity-trend-continuation]]"
  - "[[concepts/stop-entry-after-two-bar-trend-confirmation]]"
indicators:
  - "[[indicators/simple-moving-average]]"
  - "[[indicators/atr]]"
strategy_type_flags: [n-period-max-continuation, trend-filter-ma, stop-entry, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 two-bar Williams 18-MA continuation stop entry; estimate 8-18 completed packages/year after inside-day, spread, pending-expiry, ATR-stop, and max-hold filters."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "R1 PASS Tier-A Williams source packet with mechanical 18-day two-bar MA rule and source-published multi-commodity positive table including HOIL; R2 PASS deterministic D1 SMA-side, non-inside-bar, stop-entry, ATR-stop, pending-expiry, and time-stop rules; R3 PASS XTIUSD.DWX OHLC is available in DWX; R4 PASS no ML, grid, martingale, external runtime data, RSI, or banned indicator."
---

# Williams 18-Bar Two-Bar MA WTI

## 1. Source

- Source: [[sources/SRC03]]
- Primary citation: Williams, Larry R. *Long-Term Secrets to Short-Term Trading*.
  Wiley Trading, 1999.
- Local evidence: `strategy-seeds/sources/SRC03/source.md` slot S12 and
  `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` around the
  "18 DAY AVERAGE" section.

## 2. Concept

This card applies Williams' 18-bar two-bar moving-average entry to daily WTI
CFD proxy `XTIUSD.DWX`. The structure is a low-frequency commodity trend
continuation sleeve: require two completed daily bars on the same side of the
18-day close SMA, reject inside days, then enter on a stop through the two-bar
extreme.

The source reports a broad 10-year, multi-commodity positive result table for
the rule family, including heating oil. This card does not import those returns
into QM; it uses them only as reputable-source track-record support before Q02
tests the Darwinex WTI proxy directly.

This is deliberately different from:

- `QM5_12842_williams-vol-bo-xti`: prior-day range volatility breakout from
  the open; this card waits for two closed bars above/below an 18-day SMA and
  enters at the two-bar extreme.
- `QM5_12850_xti-xng-vcb`: XTI/XNG ratio volatility-contraction basket; this
  card is single-symbol WTI continuation.
- `QM5_12782_katz-seas-xti`, `QM5_12813_eia-energy-switch`, and other WTI
  seasonality/switch cards: this card has no calendar direction, event feed,
  inventory assumption, roll curve, or season window.
- `QM5_12567_cum-rsi2-commodity`: no RSI, cumulative RSI, or short-horizon
  oscillator pullback logic.
- Existing index, XAU/XAG, XTI/XNG, WTI/Brent, oil/gold, oil/silver,
  gas/gold, and gas/silver sleeves: this is an outright structural WTI
  continuation rule from a distinct Williams source slot.

## 3. Markets And Timeframe

- Host symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: about 8-18 packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, SMA, ATR, spread, broker clock, and V5
  framework state only. No futures curve, EIA feed, volume, open interest,
  external CSV/API, analyst forecast, alternative data, or ML model.

## 4. Entry Rules

- Evaluate only on a new D1 bar of `XTIUSD.DWX`.
- Compute the 18-period simple moving average of completed daily closes at
  shifts 1 and 2.
- A long setup exists when both completed bars have lows above their respective
  18-day SMA values and neither bar is an inside day.
- A short setup exists when both completed bars have highs below their
  respective 18-day SMA values and neither bar is an inside day.
- Long entry: place a buy stop at the higher high of the two signal bars plus
  `strategy_entry_buffer_points`.
- Short entry: place a sell stop at the lower low of the two signal bars minus
  `strategy_entry_buffer_points`.
- Do not enter when this EA already has an open position or pending order on
  the same magic and symbol.
- Do not enter when modeled spread exceeds `strategy_max_spread_points`.

## 5. Exit Rules

- Every entry has a hard ATR stop sized by
  `strategy_atr_sl_mult * ATR(strategy_atr_period)`.
- If `strategy_take_rr` is greater than zero, attach a fixed-R take-profit.
- Pending stop orders expire after `strategy_order_expiry_bars` D1 bars.
- Open positions close after `strategy_max_hold_days` calendar days.
- Framework Friday close remains enabled.

## 6. Filters

- Only run from `XTIUSD.DWX` on D1.
- Require positive SMA, ATR, OHLC, point value, and valid stop geometry.
- Treat zero modeled spread as tradeable in DWX backtests; only block crossed
  quotes or genuinely wide spread.
- Framework kill-switch, magic resolver, news axes, and Friday-close controls
  remain active.

## 7. Trade Management Rules

- Single-symbol, symmetric long/short continuation.
- One position or pending order per EA magic.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.

## 8. Parameters To Test

- name: strategy_ma_period
  default: 18
  sweep_range: [18, 20, 24]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_take_rr
  default: 2.0
  sweep_range: [0.0, 1.5, 2.0, 3.0]
- name: strategy_entry_buffer_points
  default: 2
  sweep_range: [0, 2, 5]
- name: strategy_order_expiry_bars
  default: 3
  sweep_range: [1, 3, 5]
- name: strategy_max_hold_days
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [500, 1000, 1500]

## 9. Author Claims

Williams defines the entry mechanically as two completed non-inside bars on the
same side of the 18-day average, then a stop through the two-bar extreme. The
local source packet also records a 10-year positive table across 14 markets,
including heating oil. QM treats that as source lineage only; all deployment
decisions must come from DWX Q02+ evidence.

## 10. Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 8-18 packages/year.
- risk_class: medium-high for WTI gap and trend-whipsaw risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## 11. Strategy Allowability Check

- [x] R1 reputable source: Tier-A Williams source packet with a named,
  mechanical commodity rule and source-published broad market table.
- [x] R2 mechanical: fixed D1 SMA-side checks, fixed non-inside-bar filter,
  fixed stop-entry reference, fixed ATR hard stop, fixed pending expiry, and
  fixed max-hold exit.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol universe and requires
  OHLC only.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  no pyramiding, and no banned/oscillator indicator.
- [x] Non-duplicate: WTI 18-SMA two-bar continuation, not Williams prior-range
  volatility breakout, XTI/XNG ratio, XNG RSI, energy seasonal switch,
  WTI/Brent spread, or a metal/index sleeve.

## 12. Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## 13. Framework Alignment

- no_trade: host/timeframe guard, spread cap, data sufficiency, duplicate
  exposure guard, and valid stop geometry.
- trade_entry: Williams D1 two-bar 18-SMA continuation stop entry.
- trade_management: max-hold time stop and framework Friday close.
- trade_close: hard ATR stop plus optional fixed-R take-profit.

## 14. Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-01 | initial Williams 18-bar WTI sleeve build | Q02 | ENQUEUED |

## 15. Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PENDING | `artifacts/qm5_12851_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | PENDING | queued after Q01 record-build |
