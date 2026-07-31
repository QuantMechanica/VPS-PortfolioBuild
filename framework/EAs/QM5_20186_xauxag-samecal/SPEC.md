# QM5_20186_xauxag-samecal — Strategy Spec

**EA ID:** QM5_20186

**Slug:** `xauxag-samecal`

**Strategy ID:** `KELOHARJU-FMR-XAUXAG-SAMECAL-2026_S01`

**Source:** `KELOHARJU-FMR-XAUXAG-SAMECAL-2026`

**Author:** Codex

**Last revised:** 2026-07-31

## 1. Strategy Logic

On the first tradable `XAUUSD.DWX` D1 bar of each broker month, reconstruct
gold's and silver's completed return for that calendar month in exactly the
ten prior years. Retain only samples whose current and preceding month-end
timestamps match across both legs, requiring at least five paired samples.

Buy XAU and sell XAG when XAU's average same-calendar return is higher; sell
XAU and buy XAG when XAG's is higher. Exact-zero or invalid state remains flat.
The package closes and reranks at the next month boundary.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_history_years` | 10 | Prior same-calendar years inspected |
| `strategy_min_history_years` | 5 | Minimum synchronized paired samples |
| `strategy_history_bars` | 3000 | Bounded D1 reconstruction buffer |
| `strategy_atr_period_d1` | 20 | Completed per-leg ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_xau_max_spread_pts` | 1500 | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 3000 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | Basket order deviation |

All baseline values are locked; no parameter sweep is authorized.

## 3. Symbol Universe

- Logical basket: `QM5_20186_XAU_XAG_SAMECAL_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, magic `201860000`.
- Companion/traded slot 1: `XAGUSD.DWX`, magic `201860001`.
- No third symbol or external runtime dependency.

## 4. Timeframe

- Host and both signal inputs: D1.
- Decision/reset: first genuine D1 bar of each broker-calendar month.
- History work runs only after the new-bar and month-boundary gates.

## 5. Expected Behaviour

- Approximately 12 two-leg packages/year after the five-year warm-up; Q02
  retires below five completed packages/year.
- Direction: always one long metal leg and one short metal leg.
- Risk: one `RISK_FIXED=1000` package budget split equally by stop risk.
- Hold: one broker month, capped by 40 days, orphan repair, or per-leg stop.
- Friday close and both news axes are disabled for the monthly native-price
  Q02 baseline.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
Journal of Finance* 71(4), 1557-1590, supplies the same-calendar commodity
rank. Fuertes, Miffre, and Rallis (2010), "Tactical Allocation in Commodity
Futures Markets," *Journal of Banking & Finance* 34(10), 2530-2548, supplies
the governed XAU/XAG cross-sectional carrier.

The complete composite evidence boundary is
`strategy-seeds/sources/KELOHARJU-FMR-XAUXAG-SAMECAL-2026/source.md`; the
approved card is
`strategy-seeds/cards/approved/QM5_20186_xauxag-samecal_card.md`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg receives half the package stop-risk budget and
a frozen `3.5 * ATR(20)` hard stop. If either leg cannot be prepared or the
second leg fails, the package stands down or is flattened immediately.

No live setfile, live authorization, deploy manifest, `T_Live` change,
portfolio admission, correlation waiver, or portfolio-gate change exists.

## 8. Framework Alignment

- No-Trade: exact host/slot/input, history, synchronization, spread, quote,
  stop, lot, package, and consumed-month guards.
- Entry: prior-year same-calendar relative rank, opposite legs, shared fixed
  risk, and frozen stops.
- Management: old-month, 40-day stale, orphan, direction, magic, and stop
  repair before entry-only gates.
- Close: framework basket close, per-leg broker stops, and kill switch.

## 9. Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-31 | Initial build from approved G0 card | Q01 PASS |
| v1-q02 | 2026-07-31 | Canonical build record | Q02 work item `d6305296-8823-42f6-8604-37725d037617` queued |
