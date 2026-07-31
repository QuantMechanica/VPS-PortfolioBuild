# QM5_20190_oilbench-cal - Strategy Spec

**EA ID:** QM5_20190
**Slug:** `oilbench-cal`
**Strategy ID:** `KELOHARJU-GK-OILBENCH-CAL-2026_S01`
**Source:** `KELOHARJU-GK-OILBENCH-CAL-2026`
**Author:** Codex
**Last revised:** 2026-08-01

## 1. Strategy Logic

This EA implements a monthly market-neutral WTI/Brent same-calendar relative
seasonality rank. On the first tradable XTI D1 bar of each month, it
reconstructs that decision calendar month's completed WTI and Brent returns
in the ten prior years, requires at least five synchronized paired samples,
averages WTI-minus-Brent returns, buys the higher seasonal benchmark, and
shorts the lower benchmark.

This is not WTI/Brent spread-level z-score reversion, a channel breakout, a
short-horizon return-shock fade, a fixed month map, recent momentum, or the
XTI/XNG same-calendar basket. The recurring historical WTI-versus-Brent
calendar rank is required for every package.

## 2. Parameters

| Parameter | Default | Card values | Meaning |
|---|---:|---|---|
| `strategy_history_years` | 10 | locked | Prior same-calendar years sampled |
| `strategy_min_history_years` | 5 | locked | Minimum synchronized pairs |
| `strategy_history_bars` | 3000 | locked | Bounded D1 reconstruction buffer |
| `strategy_atr_period_d1` | 20 | locked | Per-leg ATR stop period |
| `strategy_atr_sl_mult` | 3.5 | locked | Per-leg frozen ATR stop multiple |
| `strategy_max_hold_days` | 40 | locked | Stale package close |
| `strategy_xti_max_spread_pts` | 1000 | locked | WTI entry spread cap |
| `strategy_xbr_max_spread_pts` | 1500 | locked | Brent entry spread cap |
| `strategy_deviation_points` | 20 | locked | Basket order deviation |

## 3. Symbol Universe

- Logical basket: `QM5_20190_WTI_BRENT_CAL_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, magic `201900000`.
- Companion/traded slot 1: `XBRUSD.DWX`, magic `201900001`.
- No other symbol port is authorized by this card.

## 4. Timeframe

- Host and both signal inputs: D1.
- Entry/reset: first D1 bar of each broker-calendar month.
- Expected completed packages: about 12/year after five-year warm-up.
- Friday close is disabled to preserve the monthly holding horizon.
- Raw history work is bounded behind the D1 new-bar and month-transition gate.

## 5. Expected Behaviour

- Q02 uses one `RISK_FIXED=1000` package budget, split equally by per-leg stop
  risk; `RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`.
- Each leg receives a frozen `3.5 * ATR(20,D1)` hard stop.
- The EA consumes and persists one attempt per month before fallible entry
  gates, preventing restart or post-stop retries.
- An orphan, duplicate, same-direction, wrong-symbol, wrong-magic, or
  missing-stop package is flattened immediately.
- The package closes at the next broker-month boundary or after 40 calendar
  days.

## 6. Source Citation

Primary method: Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016),
"Return Seasonalities", *The Journal of Finance* 71(4), 1557-1590,
DOI `10.1111/jofi.12398`.

Target-market evidence: Gorska, A., and Krawiec, M. (2015), "Calendar Effects
in the Market of Crude Oil", *Problems of World Agriculture* 15(4), 62-70,
DOI `10.22630/PRS.2015.15.4.54`.

CME, ICE, and EIA references in the governed source packet establish the
Brent/WTI spread as a standard crude-benchmark structure. They do not prove
this CFD strategy or its economics.

## 7. Risk Model

Q02 uses one `RISK_FIXED=1000` package budget, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The budget is split equally between the two legs after
independent sizing against frozen `3.5 * ATR(20,D1)` hard stops. There is no
take-profit, trailing stop, scale-in, grid, martingale, or pyramiding.

The opposite legs are a directional-neutral construction intent only. Q02
must establish package economics and later unchanged gates must establish
realized portfolio correlation; neither neutrality nor diversification is
assumed by this build.

## 8. Framework Alignment

- No-Trade: exact host/slot, locked inputs, synchronized history, spread,
  ATR, symbol, magic, package, and attempt guards.
- Entry: monthly same-calendar WTI/Brent relative rank and one equal-risk
  opposite two-leg package.
- Management: month reset, 40-day stale exit, composition validation, and
  orphan cleanup.
- Close: basket flatten through framework helpers; broker hard stops and the
  kill switch remain authoritative.

## 9. Safety Boundary

This build contains one logical `RISK_FIXED` backtest setfile only. It does not
create a live setfile, deploy manifest, T_Live manifest, portfolio-gate
change, `T_Live` mutation, or AutoTrading action.

## 10. Pipeline History

| version | date | reason | next phase |
|---|---|---|---|
| v1 | 2026-08-01 | initial WTI/Brent same-calendar relative basket | Q02 work item `ec5fd9b7-8923-498f-a9fd-0a29d8a31d4c` queued |
