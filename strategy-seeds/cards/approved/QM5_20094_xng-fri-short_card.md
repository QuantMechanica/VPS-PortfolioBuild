---
ea_id: QM5_20094
slug: xng-fri-short
strategy_id: BOROWSKI-COMM-DOW-2016_S02
source_id: BOROWSKI-COMM-DOW-2016
status: APPROVED
g0_status: APPROVED
created: 2026-07-24
created_by: Research+Development
last_updated: 2026-07-24
source_citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts. Journal of Management and Financial Sciences 26, 27-44."
source_citations:
  - type: academic_paper
    citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts. Journal of Management and Financial Sciences 26, 27-44."
    location: "Section 4.1 natural-gas weekday table; Friday mean -0.1274%."
    quality_tier: B
    role: primary
strategy_type_flags: [calendar-seasonality, weekday, short-only, atr-hard-stop, low-frequency]
markets: [commodities, energy, natural_gas]
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
timeframes: [D1]
expected_trades_per_year_per_symbol: 48
expected_trade_frequency: "About 45-52 one-session XNG packages/year; Q02 must prove at least five/year."
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: TIER_B
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q02_status: PENDING
review_focus: "Falsify the weak XNG Friday short after costs and futures/CFD calendar-basis risk; Q09 alone measures realized book correlation."
g0_approval_reasoning: "OWNER commodity-sleeve mission: one fully reviewed peer-reviewed source; deterministic XNG Friday short/next-D1-flat rule; registered XNG D1 carrier; calendar and ATR only; exact-mechanic repository search CLEAN."
---

# XNG Friday One-Session Short

## Hypothesis and source boundary

Borowski reports a `-0.1274%` Friday mean for NYMEX natural-gas futures over
1990-2016. The paper does not report Friday as statistically significant, so
this is a deliberately weak falsification candidate, not a profitability
claim. Q02 tests whether the exact weekday effect transfers to the Darwinex
continuous CFD after costs.

The sole evidence lineage is the complete Borowski paper recorded at
`strategy-seeds/sources/BOROWSKI-COMM-DOW-2016/source.md`. Multiple
comparisons, the pre-2017 endpoint, NYMEX/Darwinex session mapping, continuous
contract construction, gaps and costs are binding risks.

## Non-duplicate decision

Repository-wide searches found no unconditional `XNGUSD.DWX` Friday
short/next-D1-flat carrier. `QM5_12567` is a cumulative-RSI2 price pullback.
`QM5_12806` is price-conditioned weekend reversal logic, `QM5_12818` buys
Tuesday, `QM5_12819` sells Thursday, and storage EAs require event/price state.
Different logic does not guarantee decorrelation; the portfolio gate is
unchanged.

## Markets, timeframe and cadence

- `XNGUSD.DWX`, D1, magic slot 0.
- Evaluate once on each genuine new D1 bar.
- Expect 45-52 completed packages/year before governed validation.
- Use MT5 broker calendar, D1 OHLC/ATR, spread, history and position state only.
- Backtest risk is `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1.

## Entry rules

- On a genuine D1 bar with broker `day_of_week == 5`, consume the daily
  attempt before news, spread, ATR, price or order checks.
- Never shift a blocked Friday and never retry within that broker day.
- Require no same-magic open position or prior same-day entry deal.
- Require nonnegative spread no greater than 2500 points.
- SELL at market with a frozen `2.75 * ATR(20)` hard stop and no take-profit.

## Exit and management rules

- Close at the first following D1 boundary before entry-news gating.
- Close after one calendar day as a stale safety override.
- Keep framework Friday close enabled at broker hour 21.
- One position per magic; no scale-in, partial close, trail, break-even,
  grid, martingale, pyramid, external runtime feed, adaptive fit or ML.

## Parameters to test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_entry_dow` | 5 | [5] |
| `strategy_atr_period` | 20 | [20] |
| `strategy_atr_sl_mult` | 2.75 | [2.75] |
| `strategy_max_hold_days` | 1 | [1] |
| `strategy_max_spread_points` | 2500 | [2500] |

All Q02 values and the short direction are locked. A different weekday,
direction, stop, hold or filter is a new card.

## Kill criteria

- Retire below five completed packages/year.
- Fail on non-Friday entry, duplicate same-day attempts, nondeterminism,
  risk mismatch or governed PF/DD failure.
- Do not rescue failure by changing weekday, direction, stop or filter.

## Strategy allowability check

- [x] R1: exactly one peer-reviewed source lineage.
- [x] R2: deterministic entry, exit, stop and no-retry rules.
- [x] R3: registered `XNGUSD.DWX` D1 route.
- [x] R4: deterministic; no banned indicator, external feed or ML.
- [x] Exact mechanic dedup search is clean.

## Framework alignment

- no_trade: exact symbol/D1/slot and locked constants.
- trade_entry: broker Friday, persisted attempt/history guard, short ATR stop.
- trade_management: next-D1 and stale-day closure before news gating.
- trade_close: framework close, Friday close and broker hard stop.

## Risk and safety boundary

This authorization covers the card, build, strict compile, one RISK_FIXED
backtest setfile and Q02 enqueue only. It does not authorize a live setfile,
AutoTrading, T_Live, a deploy manifest, portfolio admission or portfolio-gate
change.

## Falsification

Q02 kills insufficient frequency, bad economics, invalid timing, or a risk
contract breach. Q09 correlation remains authoritative.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-24 | initial source-backed XNG Friday short | Q02 | PENDING |
