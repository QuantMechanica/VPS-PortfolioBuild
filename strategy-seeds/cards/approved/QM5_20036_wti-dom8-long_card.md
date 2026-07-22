---
ea_id: QM5_20036
slug: wti-dom8-long
strategy_id: BOROWSKI-WTI-DOM8-2016_S01
source_id: BOROWSKI-WTI-DOM8-2016
status: APPROVED
created: 2026-07-22
created_by: Research+Development
last_updated: 2026-07-22
strategy_type_flags: [calendar-seasonality, day-of-month, long-only, atr-hard-stop, time-stop, low-frequency]
source_citations:
  - type: academic_paper
    citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts with the Following Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber. Journal of Management and Financial Sciences, issue 26, 27-44."
    location: "Section 4.3, pp. 36-37: crude-oil day 8 reported significant at p=0.0430; conclusion; complete author-uploaded paper."
    quality_tier: B
    role: primary
markets: [commodities, energy, crude_oil]
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
timeframes: [D1]
ml_required: false
g0_status: APPROVED
r1_track_record: TIER_B
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 9
expected_trade_frequency: "About 8-10 exact-date packages per year"
expected_pf: 1.01
expected_dd_pct: 40.0
risk_class: high
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [friday_close, risk_mode_dual, low_frequency, cfd_source_basis, multiple_comparisons, portfolio_correlation]
q01_status: PENDING
pipeline_phase: Q02
q02_status: PENDING
review_focus: "Adds solo WTI calendar exposure to the XAU/SP500/NDX/XNG book; strictly falsify exact day 8 after costs and CFD/session basis, and measure correlation only at Q09."
g0_approval_reasoning: "OWNER commodity-sleeve mission: tier-B complete academic source; deterministic significant WTI day-8 long/next-D1-flat rule; registered XTIUSD D1 route; calendar/ATR only; exact-mechanic repository search CLEAN."
---

# WTI Calendar-Day-8 One-Session Long

## Hypothesis and evidence boundary

Borowski (2016), *Journal of Management and Financial Sciences* issue 26,
reports crude-oil calendar day 8 as statistically different (`p=0.0430`) in
NYMEX futures from 1983-03-30 through 2016-03-31. This card fixes a one-session
long from the table's positive day-8 mean and lets Q02 falsify transfer to the
Darwinex CFD after costs. The source does not establish live profitability.

Primary tier-B source: https://econjournals.sgh.waw.pl/JMFS/Archives_2015_2016.
Complete author copy: https://www.researchgate.net/publication/303285422.

Multiple comparisons, no reported correction, an old endpoint, futures/CFD
basis and exact broker-calendar mapping are load-bearing risks.

## Locked rules

- On a genuine new `XTIUSD.DWX` D1 bar dated exactly the 8th, consume the
  broker-month attempt before gates and submit one BUY.
- Never shift an absent 8th and never retry within the month.
- Close at the first following D1 boundary or after one stale calendar day.
- Use completed-bar ATR(20), a frozen 2.75 ATR hard stop, 2500-point spread
  cap, framework news gate, Friday close at broker hour 21, and no TP.
- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1. No sweep.
- No ML, banned indicator, external feed, grid, martingale, scale or pyramid.

## Non-duplicate boundary

Repository-wide card/EA search found no WTI day-8 carrier. `QM5_20028` trades
day 1, `QM5_20020` day 17, and `QM5_20027` day 26; weekday, month-window,
inventory, trend, ratio and XNG sleeves use different triggers. Different
logic does not prove low correlation; the downstream portfolio gate remains
unchanged.

## Kill criteria and framework alignment

Retire below five completed packages/year, on wrong-date/duplicate entries,
nondeterminism, risk mismatch, or governed PF/DD failure. No post-result change
of date, direction, stop, hold, or filter is authorized.

- no_trade: exact XTI/D1/slot, locked constants, spread and restart guards.
- trade_entry: exact day 8, monthly persistence/history guard, BUY, ATR stop.
- trade_management: next-D1 and stale-day close before entry-news gating.
- trade_close: framework close path, Friday close, and broker hard stop.

No live setfile, AutoTrading, T_Live, deploy manifest, portfolio admission, or
portfolio-gate change is authorized.

## Pipeline history

| version | date | phase | verdict |
|---|---|---|---|
| v1 | 2026-07-22 | Q01 | PENDING |
| v1 | 2026-07-22 | Q02 | PENDING |
