---
strategy_id: LI-WTI-DOW-2022_S02
source_id: LI-WTI-DOW-2022
ea_id: QM5_20047
slug: wti-mon-loss-bnc
status: APPROVED
created: 2026-07-22
created_by: Research+Development
last_updated: 2026-07-22
g0_status: APPROVED
source_citations:
  - type: academic_paper
    citation: "Li, W., Zhu, Q., Wen, F. and Mohd Nor, N. (2022). The evolution of day-of-the-week and the implications in crude oil market. Energy Economics 106, 105817."
    location: "Abstract and trading-implication discussion; DOI 10.1016/j.eneco.2022.105817"
    quality_tier: A
    role: primary
strategy_type_flags: [calendar-seasonality, conditional-reversal, low-frequency, atr-hard-stop, time-stop]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
expected_trades_per_year_per_symbol: 8
pipeline_phase: Q02
review_focus: "Adds a loss-conditioned WTI weekend-reversal driver, distinct from outright index/metal/XNG sleeves and unconditional WTI weekday cards."
r1_track_record: TIER_A
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
g0_approval_reasoning: "OWNER commodity-sleeve mission authorizes one new card/build; peer-reviewed Energy Economics source; deterministic Monday entry conditioned on a completed Friday loss; registered XTIUSD.DWX D1; no ML/grid/martingale/external runtime feed."
---

# WTI Monday Loss Bounce

## Hypothesis and source boundary

Li et al. document time-varying WTI weekday effects and connect Monday behaviour to the market's reaction to prior sentiment. This card tests a deliberately narrow CFD translation: buy only on Monday after a materially negative completed Friday return, then flatten at the next D1 boundary. The pipeline must falsify the threshold, CFD basis, gaps and costs; the paper is lineage, not a profitability guarantee.

## Rules

- Host `XTIUSD.DWX`, D1, slot 0 only.
- On a new broker-calendar Monday D1 bar, require the immediately prior completed bar to be Friday.
- Require Friday close-to-close return `<= -1.5%`; BUY once for that Monday.
- Freeze a completed-bar `ATR(20) * 2.25` broker hard stop at entry.
- Close on the first non-Monday D1 bar or after two calendar days.
- Reject spread above 1000 points. Backtest uses `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- No oscillator, ML, external feed, grid, martingale, pyramiding, or live preset.

## Non-duplicate decision

`QM5_12596` shorts every Monday; `QM5_12750/12779` trade Monday opening gaps; `QM5_20029` rotates unconditional Monday/Friday exposure. QM5_20047 is long-only and requires a completed Friday close-to-close loss, so neither weekday alone nor the weekend opening gap can trigger it. It is also unrelated to QM5_12567 commodity RSI logic.

## Frequency and kill criteria

Expected 5-15 trades/year. Retire below five completed packages/year, on zero trades, wrong weekday/bar-contiguity, repeat Monday entries, nondeterminism, risk mismatch, or governed net-economics failure. Do not optimize the weekday, return threshold, or direction after seeing Q02.

## Framework alignment

- no_trade: exact symbol/D1/slot, parameter, spread, weekday-contiguity and one-entry-per-day guards.
- trade_entry: Monday BUY after Friday return at or below the locked threshold, with frozen ATR stop.
- trade_management: first non-Monday D1 close and two-day stale guard.
- trade_close: framework strategy close or broker hard stop.

## Safety boundary

Card, build, compile and Q02 enqueue only. No T_Live, AutoTrading, live setfile, deploy manifest, portfolio manifest or portfolio-gate modification.
