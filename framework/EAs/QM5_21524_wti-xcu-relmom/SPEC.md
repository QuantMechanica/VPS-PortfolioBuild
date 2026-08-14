# QM5_21524_wti-xcu-relmom — Strategy Spec

**EA ID:** QM5_21524

**Slug:** `wti-xcu-relmom`

**Strategy ID:** `FMR-EIA-USGS-WTI-XCU-RELMOM-2026_S01`

**Source:** `FMR-EIA-USGS-WTI-XCU-RELMOM-2026`

**Author:** Codex

**Last revised:** 2026-08-14

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar after each genuine broker-month
transition, consume one attempt and reconstruct exactly thirteen consecutive
common completed broker-month endpoints for WTI and copper. Require exact
timestamp agreement. Calculate twelve simple monthly returns for each leg and
rank their arithmetic means.

Buy WTI and sell copper when WTI's mean is strictly higher by more than
`1e-10`. Sell WTI and buy copper when copper's mean is strictly higher by more
than `1e-10`. A tie, stale endpoint, timestamp mismatch, missing month, or
invalid state consumes the month flat. Close and recompute at the next month.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_return_window_months` | 12 | Exact simple monthly return count |
| `strategy_history_bars_d1` | 800 | Bounded completed-D1 buffer per leg |
| `strategy_max_endpoint_gap_days` | 10 | Newest endpoint freshness ceiling |
| `strategy_rank_deadband` | 1e-10 | Strict average-return rank band |
| `strategy_atr_period_d1` | 20 | Completed per-leg ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen per-leg stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_wti_max_spread_pts` | 1500 | WTI entry spread cap |
| `strategy_xcu_max_spread_pts` | 1200 | Copper entry spread cap |
| `strategy_deviation_points` | 20 | Basket order deviation |

All baseline values are locked; no parameter sweep is authorized.

## 3. Symbol Universe

- Logical basket: `QM5_21524_WTI_XCU_RELMOM_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, magic `215240000`.
- Companion/traded slot 1: `XCUUSD.DWX`, magic `215240001`.
- Both legs are ordered. There is no external or read-only state symbol.

## 4. Timeframe

- Host and signal inputs: D1.
- Decision/reset: first genuine D1 bar of each broker-calendar month.
- Formation uses exactly synchronized completed month-end D1 observations.
- Hold: until the next broker month, capped at forty calendar days.

## 5. Expected Behaviour

- Approximately twelve two-leg packages/year after warm-up; Q02 retires below
  five completed packages per full post-warm-up year.
- Direction: always one long physical-commodity carrier and one short.
- Risk: one `RISK_FIXED=1000` package budget split equally by stop risk.
- Stops: frozen `3.5*ATR(20,D1)` per leg; no take-profit.
- Repair: flatten partial, orphaned, duplicate, same-direction, wrong-magic,
  wrong-symbol, or missing-stop package state.
- Friday close and all news modes are disabled for the monthly native-price
  Q02 baseline.

## 6. Source Citation

Fuertes, Miffre, and Rallis (2010), *Journal of Banking & Finance* 34(10),
2530-2548, supplies the twelve-month cross-sectional commodity-momentum rank
and one-month hold. Governed EIA, CME, and USGS references establish the
distinct WTI energy and copper industrial/base-metal carriers.

The evidence boundary is
`strategy-seeds/sources/FMR-EIA-USGS-WTI-XCU-RELMOM-2026/source.md`; the
approved execution card is
`strategy-seeds/cards/approved/QM5_21524_wti-xcu-relmom_card.md`. No source
performance or neutrality result transfers to this two-CFD basket.

## 7. Risk Model

Backtests use aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg receives half the package stop-risk budget and
one frozen hard stop. Any partial-open or final-package failure flattens all
owned exposure and consumes the month.

Opposite legs do not prove dollar, beta, volatility, factor, market, or
portfolio neutrality. There is no live setfile, deploy artifact, correlation
waiver, or portfolio-gate change.

## 8. Exact Arithmetic Contract

Let the common endpoint arrays be newest-to-oldest and end in the immediately
completed broker month:

```text
r_wti[i] = wti_close[i] / wti_close[i+1] - 1, i=0..11
r_xcu[i] = xcu_close[i] / xcu_close[i+1] - 1, i=0..11
avg_wti  = sum(r_wti) / 12
avg_xcu  = sum(r_xcu) / 12
diff     = avg_wti - avg_xcu
```

`diff > 1e-10` maps to long WTI/short copper. `diff < -1e-10` maps to short
WTI/long copper. Every other state is flat. Log returns, cumulative endpoint
returns, daily windows, ratios, z-scores, regression betas, and alternate
horizons are outside contract.

## 9. Non-Duplicate Boundary

`QM5_13094` follows a daily WTI/copper price-level channel; `QM5_13090` fades
a short-horizon WTI/copper return-spread z-score; `QM5_12733` ranks WTI versus
natural gas using cumulative D1 returns; and `QM5_20050` is the precious-metal
XAU/XAG carrier. This EA uniquely combines exact synchronized WTI/copper month
ends, twelve simple-return arithmetic means, strict rank continuation, equal
opposite-leg risk, and one consumed monthly attempt.

## 10. Framework Alignment

- No-Trade: exact host/slot/input, fixed-risk/news/Friday contract, magic,
  spread, quote, stop, lot, package, and consumed-month guards.
- Entry: synchronized completed-month reconstruction, twelve simple-return
  means, strict rank, equal risk, two registered orders, and final atomic
  validation.
- Management: old-month, forty-day stale, orphan, direction, magic, and
  missing-stop repair before entry-only gates.
- Close: framework basket close, per-leg broker stops, and kill switch.

## 11. Kill And Safety Boundary

Retire below five completed packages/year, on nonpositive governed economics,
or at later portfolio-correlation rejection. Fail on wrong month mapping,
timestamp mismatch, wrong return arithmetic, wrong rank direction, repeated
attempt, malformed package, aggregate-risk breach, missing stop, risk mismatch,
or nondeterminism. No rescue parameter is authorized.

Research, build, strict Q01, one fixed-risk backtest set, and one paced Q02
enqueue only. No manual backtest, live/demo/shadow/stress/optimization set,
`T_Live` access, AutoTrading change, deploy manifest, portfolio-gate edit,
portfolio admission, or correlation waiver is authorized.

## 12. Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-14 | Initial build from approved G0 card | Q01 pending |
| v2 | 2026-08-14 | Validate synchronized monthly basket implementation | Q01 PASS |

## 13. Q01 Status

PASS. The two registered slots reconstruct exact synchronized completed
broker-month endpoints, calculate twelve simple-return arithmetic means, map
the strict relative rank to opposite WTI/copper directions, consume the month
before every fallible gate, and enforce one equal stop-risk package with
atomic repair.

Strict MetaEditor compilation passed with zero errors and warnings. The
targeted strict build check passed with zero failures and warnings; nine
independent calendar, timestamp, arithmetic, direction, and risk-split tests
passed; and P1 found the compiled `.ex5`. The canonical backtest set is locked
to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, with source
build hash `ec10b03c7a8835877843ca1dc25fd114d985cf120a04fc6bcab2b79b8c7b1043`.
No Strategy Tester run was launched during Q01.
