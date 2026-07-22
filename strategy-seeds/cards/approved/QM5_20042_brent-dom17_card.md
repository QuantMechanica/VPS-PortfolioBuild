---
ea_id: QM5_20042
slug: brent-dom17
strategy_id: BOROWSKI-XBR-DOM17-2016_S01
source_id: BOROWSKI-XBR-DOM17-2016
status: APPROVED
created: 2026-07-22
created_by: Research+Development
last_updated: 2026-07-22
strategy_type_flags: [calendar-seasonality, day-of-month, short-only, atr-hard-stop, time-stop, low-frequency]
source_citations:
  - type: academic_paper
    citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts. Journal of Management and Financial Sciences, issue 26, 27-44."
    location: "Section 4.3, pp. 36-37: Brent day 17 minimum mean -0.6962%; day 17 not among rejected mean-equality tests."
    quality_tier: B
    role: primary
markets: [commodities, energy, brent_crude]
primary_target_symbols: [XBRUSD.DWX]
target_symbols: [XBRUSD.DWX]
timeframes: [D1]
ml_required: false
g0_status: APPROVED
g0_approval_reasoning: "OWNER commodity-sleeve mission: tier-B complete academic source; deterministic Brent day-17 short/next-D1-flat falsification rule; registered XBRUSD D1 route; calendar/ATR only; exact-mechanic repository search CLEAN."
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
hard_rules_at_risk: [friday_close, risk_mode_dual, low_frequency, futures_cfd_basis, multiple_comparisons, portfolio_correlation]
q01_status: PASS
pipeline_phase: Q02
q02_status: PENDING
---

# Brent Calendar-Day-17 One-Session Short

## Hypothesis and evidence boundary

Borowski (2016), *Journal of Management and Financial Sciences* issue 26,
reports day 17 as the minimum Brent numbered-day mean (`-0.6962%`) in futures
from 1983-03-30 through 2016-03-31. Mechanize that weak negative extreme as one
exact-date short package and let Q02 falsify transfer to the Darwinex CFD after
costs. The paper does **not** report day 17 as statistically significant; its
rejected Brent dates are days 8 and 26.

Primary tier-B source: Borowski (2016), pp. 27-44, Section 4.3. Official SGH
archive: https://econjournals.sgh.waw.pl/JMFS/Archives_2015_2016. Complete
author copy: https://www.researchgate.net/publication/303285422.

Multiple comparisons, no reported correction, an old endpoint, futures/CFD
basis, and exact broker-calendar mapping are binding risks. The source
statistic is not an expected-performance claim.

## Locked rules

- On a genuine new `XBRUSD.DWX` D1 bar dated exactly the 17th, consume the
  broker-month attempt before gates and submit one SELL.
- Never shift an absent 17th and never retry within the month.
- Close at the first following D1 boundary or after one stale calendar day.
- Use completed-bar ATR(20), a frozen 2.75 ATR hard stop, 2500-point spread
  cap, framework news gate, Friday close at broker hour 21, and no TP.
- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1. No sweep.
- No ML, banned indicator, external feed, grid, martingale, scale, or pyramid.

## Non-duplicate boundary

Repository-wide card/EA/registry search found no Brent day-17 carrier. Brent
weekday/month sleeves, 52-week anchor, TSMOM, six-month reversal, WTI/Brent
spreads, and Brent/metal ratios use different triggers and holds. This is also
not `QM5_12567` cumulative-RSI2 logic. Different logic and energy exposure do
not prove low correlation; the governed downstream portfolio test is intact.

## Kill criteria and framework alignment

Retire below five completed packages/year, on wrong-date/duplicate entries,
nondeterminism, risk mismatch, or governed PF/DD failure. No post-result change
of date, direction, stop, hold, or filter is authorized.

- no_trade: exact XBR/D1/slot, locked constants, spread and restart guards.
- trade_entry: exact day 17, monthly persistence/history guard, SELL, ATR stop.
- trade_management: next-D1 and stale-day close before entry-news gating.
- trade_close: framework close path, Friday close, and broker hard stop.

No live setfile, AutoTrading, T_Live, deploy manifest, portfolio admission, or
portfolio-gate change is authorized.

## Pipeline history

| version | date | phase | verdict |
|---|---|---|---|
| v1 | 2026-07-22 | Q01 | strict compile PASS, 0 errors/0 warnings |
| v1 | 2026-07-22 | Q02 | PENDING |
