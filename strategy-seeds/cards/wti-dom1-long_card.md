---
ea_id: QM5_20028
slug: wti-dom1-long
strategy_id: BOROWSKI-WTI-DOM1-2016_S01
source_id: BOROWSKI-WTI-DOM1-2016
source_citation: "Borowski (2016), Journal of Management and Financial Sciences 26, 27-44."
status: APPROVED
created: 2026-07-21
created_by: Research+Development
last_updated: 2026-07-21
g0_status: APPROVED
g0_approval_reasoning: "OWNER commodity-sleeve mission: R1 tier-B complete peer-reviewed source; R2 exact day-1 long/next-D1-flat; R3 XTI D1 registered; R4 calendar/ATR only, source non-significance disclosed."
source_citations:
  - type: academic_paper
    citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts with the Following Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber. Journal of Management and Financial Sciences, issue 26, 27-44."
    location: "Section 4.3, pp. 36-37: WTI day 1 highest numbered-day mean +0.0338%; day 1 absent from the reported significant-day list; conclusion; complete author-uploaded paper."
    quality_tier: B
    role: primary
strategy_type_flags: [calendar-seasonality, day-of-month, long-only, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
expected_trades_per_year_per_symbol: 8
expected_pf: 1.0
expected_dd_pct: 35.0
ml_required: false
r1_track_record: TIER_B
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: QUEUED
q02_work_item_id: 0df72a37-5069-4014-9b29-cc76176b57fc
review_focus: "Strictly falsify the non-significant WTI day-1 maximum-mean observation after costs and CFD/session basis; no neighboring-date or parameter rescue."
---

# WTI Calendar-Day-1 One-Session Long

## Hypothesis and evidence boundary

Source: Borowski (2016), *Journal of Management and Financial Sciences*, issue
26, pages 27-44; complete author copy at https://www.researchgate.net/publication/303285422.

Borowski reports calendar day 1 as the highest crude-oil numbered-day mean in
the 1983-2016 NYMEX sample (`+0.0338%`). The paper does not list day 1 among
the statistically significant crude-oil dates; only days 8 and 26 are listed.
This is therefore a weak, predeclared structural calendar hypothesis, not a
performance claim. Multiple testing, post-2016 decay and futures/CFD basis are
load-bearing falsification risks.

## Rules and non-duplicate boundary

- On `XTIUSD.DWX` D1, BUY only at the opening of an actual broker bar dated 1.
- Never shift a missing first-of-month bar and never retry a consumed month.
- Close at the first following D1 bar; retain a one-calendar-day stale guard.
- Use a frozen prior-bar `ATR(20) * 2.75` hard stop, no take-profit, and a
  2500-point spread cap. Friday close remains enabled at broker hour 21.
- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1.
- No price filter, sweep, trailing, scale, grid, martingale, ML, banned
  indicator, external runtime data, live setfile or portfolio-gate exception.

This is not `QM5_20020` day-17 short, `QM5_20027` day-26 short,
`QM5_20021` half-month short, a weekday/inventory sleeve, trend system, or
energy/metal basket. Realized decorrelation remains a downstream measurement.

## Exit

Close at the first D1 boundary after entry, retry a rejected close throughout
that bar, and enforce the one-calendar-day stale guard plus Friday close.

## Kill criteria and framework alignment

Retire below five completed packages/year, on wrong-date/duplicate entries,
nondeterminism, invalid risk mode, or governed PF/DD failure. No post-result
change of day, direction, stop, hold or price filter is authorized.

- no_trade: exact XTI/D1/slot and locked inputs.
- trade_entry: restart-safe exact-date attempt, BUY, frozen ATR stop.
- trade_management: next-D1 and stale closure before entry/news gates.
- trade_close: framework close API, Friday close and broker hard stop.

## Safety boundary

Backtest/Q02 only. No T_Live access, AutoTrading, live/deploy manifest,
portfolio admission or portfolio-gate change is authorized.

## Pipeline history

| version | date | phase | verdict |
|---|---|---|---|
| v1 | 2026-07-21 | Q01 | strict compile PASS, 0 errors/0 warnings |
| v1 | 2026-07-21 | Q02 | QUEUED `0df72a37-5069-4014-9b29-cc76176b57fc` |
