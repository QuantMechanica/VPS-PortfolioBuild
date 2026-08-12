# QM5_20189_xauxag-calmom1 — Strategy Spec

**EA ID:** QM5_20189

**Slug:** `xauxag-calmom1`

**Strategy ID:** `KELOHARJU-FMR-XAUXAG-CALMOM1-2026_S01`

**Source:** `KELOHARJU-FMR-XAUXAG-CALMOM1-2026`

**Author:** Codex

**Last revised:** 2026-07-31

## 1. Strategy Logic

On the first tradable `XAUUSD.DWX` D1 bar of each broker month, reconstruct
gold-minus-silver returns for the decision calendar month over the prior ten
years. Retain only synchronized paired samples and require at least five.

Independently reconstruct the exact immediately completed broker-month
gold-minus-silver return. Trade only when both relative-return states have the
same sign: positive agreement buys XAU and sells XAG; negative agreement sells
XAU and buys XAG. Disagreement, deadband, or invalid state consumes the month
and remains flat. The package closes and reranks at the next month boundary.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_history_years` | 10 | Prior same-calendar years inspected |
| `strategy_min_history_years` | 5 | Minimum synchronized paired samples |
| `strategy_history_bars` | 4000 | Bounded D1 reconstruction buffer |
| `strategy_momentum_months` | 1 | Exact completed relative month |
| `strategy_signal_epsilon` | 1e-10 | Deterministic tie deadband |
| `strategy_atr_period_d1` | 20 | Completed per-leg ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_xau_max_spread_pts` | 1500 | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 3000 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | Basket order deviation |

All baseline values are locked; no parameter sweep is authorized.

## 3. Symbol Universe

- Logical basket: `QM5_20189_XAU_XAG_CALMOM1_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, magic `201890000`.
- Companion/traded slot 1: `XAGUSD.DWX`, magic `201890001`.
- No third symbol or external runtime dependency.

## 4. Timeframe

- Host and both signal inputs: D1.
- Decision/reset: first genuine D1 bar of each broker-calendar month.
- History work runs only after the new-bar, month-boundary, and consumed-attempt
  gates.

## 5. Expected Behaviour

- Approximately 5-8 two-leg packages/year after the warm-up; Q02 retires below
  five completed packages/year.
- Direction: always one long metal leg and one short metal leg.
- Risk: one `RISK_FIXED=1000` package budget split equally by stop risk.
- Hold: one broker month, capped by 40 days, orphan repair, or per-leg stop.
- Friday close and both news axes are disabled for the monthly native-price
  Q02 baseline.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
Journal of Finance* 71(4), 1557-1590, supplies the same-calendar commodity
state. Fuertes, Miffre, and Rallis (2010), "Tactical Allocation in Commodity
Futures Markets," *Journal of Banking & Finance* 34(10), 2530-2548, supplies
the one-month cross-sectional momentum state.

The complete composite evidence boundary is
`strategy-seeds/sources/KELOHARJU-FMR-XAUXAG-CALMOM1-2026/source.md`; the
approved card is
`strategy-seeds/cards/approved/QM5_20189_xauxag-calmom1_card.md`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg receives half the package stop-risk budget and
a frozen `3.5 * ATR(20)` hard stop. If either leg cannot be prepared or the
second order fails, the package stands down or is flattened immediately.

No live setfile, live authorization, deploy manifest, `T_Live` change,
portfolio admission, correlation waiver, or portfolio-gate change exists.

## 8. Framework Alignment

- No-Trade: exact host/slot/input, history, synchronization, spread, quote,
  stop, lot, package, and consumed-month guards.
- Entry: same-calendar plus exact one-month relative sign agreement, opposite
  legs, shared fixed risk, and frozen stops.
- Management: old-month, 40-day stale, orphan, direction, magic, and stop
  repair before entry-only gates.
- Close: framework basket close, per-leg broker stops, and kill switch.

## 9. Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-31 | Initial build from approved G0 card | Q01 PASS; Q02 work item `2897ad06-5996-4c5a-8a4b-1de95c867c52` QUEUED |
