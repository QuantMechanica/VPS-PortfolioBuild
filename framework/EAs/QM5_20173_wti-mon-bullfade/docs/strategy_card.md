---
card_schema_version: 2
ea_id: QM5_20173
slug: wti-mon-bullfade
strategy_id: QUAY-MOP-WTI-MONBULL-2026_S01
source_id: QUAY-MOP-WTI-MONBULL-2026
status: DRAFT
g0_status: APPROVED
execution_contract_status: DRAFT
canonical_card: strategy-seeds/cards/approved/QM5_20173_wti-mon-bullfade_card.md
created: 2026-07-25
---

# QM5_20173 WTI Monday Positive-Trend Counterfade Short

This is the build-time copy of the approved execution rules. The canonical
research and approval record is
`strategy-seeds/cards/approved/QM5_20173_wti-mon-bullfade_card.md`; if metadata
differs, the canonical card controls and the binary must be re-reviewed.

## Hypothesis

WTI's source-documented weak Monday return may be more mechanically coherent
when the instrument's completed 252-D1 return is strictly positive. The conjunction
is a new, falsifiable WTI CFD hypothesis; no profitability, decorrelation,
certification, or portfolio-admission claim is made.

## Source Traceability

- Quayyum, Khan, and Ali (2020), "Seasonality in crude oil returns",
  *Soft Computing* 24, DOI
  `https://doi.org/10.1007/s00500-019-04329-0`.
- Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum",
  *Journal of Financial Economics* 104, DOI
  `https://doi.org/10.1016/j.jfineco.2011.11.003`.
- Governed composite packet:
  `strategy-seeds/sources/QUAY-MOP-WTI-MONBULL-2026/source.md`.

The first source supplies the WTI Monday direction and the second supplies the
completed own-return sign. Neither tests their conjunction or the continuous
Darwinex CFD translation.

## Rules

Only the frozen baseline below is authorized.

## 4. Entry Rules

1. Run only on exact `XTIUSD.DWX`, D1, magic slot 0 and magic `201730000`.
2. The current D1 bar must be Monday and the immediately prior completed D1
   bar must be Friday.
3. The first observed tick must be no more than five minutes after the Monday
   D1 bar time.
4. Derive the Monday-anchored broker-week key and persist it as consumed before
   history, signal, spread, quote, news, stop, or order gates.
5. Reject an existing position or entry deal for the same magic and week.
6. Compute `ln(Close[1] / Close[253])` from completed D1 closes.
7. Permit one SELL only when the return is strictly positive.
8. Require spread at most 1,500 points, a valid SELL quote and completed
   `ATR(20)`.
9. Attach one frozen stop `3.0 * ATR(20)` above entry and no take-profit.
10. No retry, pending order, second entry, scale-in, or pyramid is authorized.

## 5. Exit Rules

1. Close on the first new D1 bar that is not Monday.
2. Close an unexpected long immediately.
3. Close after two elapsed calendar days as stale repair.
4. Framework Friday close at broker hour 21 remains enabled as a fail-safe.
5. Broker hard stop and framework kill switch remain authoritative.
6. No target, reversal exit, trail, break-even move, partial close, or
   discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed on wrong identity, unlocked input, invalid calendar boundary,
  late attachment, invalid week, missing history, non-positive price, invalid
  logarithm, non-positive trend, invalid ATR, bad spread/quote, or invalid
  normalized stop.
- News temporal and compliance axes are locked OFF.
- No external calendar, feed, futures curve, inventory, COT, volume, open
  interest, CSV, API, analyst forecast, or trained output.

## 7. Trade Management Rules

- One position and one consumed attempt per broker week.
- Preserve the original server-side stop.
- Recover consumed-week state from a terminal global plus deal/position
  history; clear a future-dated tester marker on initialization.
- Run lifecycle exits before entry-only gates.
- No grid, martingale, randomness, adaptive fit, or discretionary override.

## Parameters To Test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_momentum_lookback_d1` | 252 | [252] |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] |
| `strategy_entry_grace_minutes` | 5 | [5] |
| `strategy_atr_period` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.0 | [3.0] |
| `strategy_max_hold_days` | 2 | [2] |
| `strategy_max_spread_points` | 1500 | [1500] |

There is no parameter sweep. The Monday boundary and positive 252-D1 sign are
jointly load-bearing.

## Kill Criteria

Retire below five completed packages/year on average or on zero trades. Fail
on a long entry, wrong weekday boundary, entry without positive completed
trend, repeat attempt, hold beyond two days, missing next-D1 exit, missing
hard stop, risk mismatch, nondeterminism, or governed economic failure. Do not
rescue a failure by altering the frozen weekday, trend, direction, entry
clock, stop, hold, spread, retry, or risk rules.

## Risk

Backtests use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. WTI weekend gaps, short squeezes, continuous-CFD
roll/basis, financing, source decay, and conditional density are first-order
kill risks.

## Framework Alignment

- no_trade: identity, locked input, genuine Monday, grace, history, trend,
  spread, quote, stop, consumed-week, and owned-position guards.
- trade_entry: one positive-trend Monday SELL with frozen ATR stop.
- trade_management: first non-Monday, wrong-side, and two-day stale closes.
- trade_close: position close, Friday fail-safe, broker stop, and kill switch.

## Safety Boundary

Approval covers this card, registries, one EA build, strict compile, one
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does not authorize
a manual backtest, live setfile, AutoTrading, `T_Live`, deploy manifest,
portfolio admission, portfolio-gate change, KPI claim, or correlation waiver.

