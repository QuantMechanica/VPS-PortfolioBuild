# QM5_20184_xauxag-xmom3 — Strategy Spec

**EA ID:** QM5_20184
**Slug:** `xauxag-xmom3`
**Strategy ID:** `FMR-MOMTS-2010_XAU_XAG_S04`
**Source:** Fuertes, Miffre, and Rallis (2010), *Journal of Banking & Finance*

## 1. Strategy Logic

Run one logical basket from `XAUUSD.DWX` D1. At each broker-month transition,
consume the month before fallible gates, reconstruct four synchronized
completed month-end closes for XAU and XAG, calculate exactly three simple
monthly returns and their arithmetic average, buy the higher-return leg, and
short the lower-return leg. Close at the next month transition or after 40
days. Split one `RISK_FIXED` budget equally, use frozen ATR hard stops, and
flatten partial, duplicate, same-direction, or missing-stop packages.

This intermediate source horizon is load-bearing. One- and twelve-month
XAU/XAG cross-sectional momentum EAs already exist, while the paper declares
one, three, and twelve months before this candidate's results are observed.

## 2. Parameters

| Parameter | Baseline | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_return_window_months` | 3 | locked | Completed monthly-return horizon |
| `strategy_history_bars` | 500 | 400, 500, 600 | Bounded D1 reconstruction buffer |
| `strategy_atr_period_d1` | 20 | 14, 20, 30 | Completed-bar stop volatility |
| `strategy_atr_sl_mult` | 3.5 | 2.5, 3.5, 5.0 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | locked | Stale-package guard |
| `strategy_xau_max_spread_pts` | 1500 | locked | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | locked | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | locked | Basket order deviation |

The Q02 setfile freezes the baseline only. There is no parameter sweep in this
build.

## 3. Symbol Universe

- Host and slot 0: `XAUUSD.DWX`, magic `201840000`.
- Companion and slot 1: `XAGUSD.DWX`, magic `201840001`.
- Logical symbol: `QM5_20184_XAU_XAG_XMOM3_D1`.

Both legs must be present, opposite, correctly registered, and protected by a
hard stop. Other symbols and single-leg operation are unauthorized.

## 4. Timeframe

The host and both history streams use native Darwinex D1 bars. Decisions occur
only on the first tradable XAU D1 bar of a new broker month. Formation uses
completed D1 data and exact matching month-end timestamps; it never uses the
forming bar or intrabar direction.

## 5. Expected Behaviour

| Property | Expected baseline |
|---|---|
| Package frequency | Approximately 12 per year before filters |
| Minimum viable density | Five completed packages per year after warm-up |
| Holding period | One broker month, capped at 40 calendar days |
| Direction | Long stronger three-month metal, short weaker metal |
| Common-factor intent | Opposite legs reduce common metal/USD direction; neutrality is unproven |
| Primary risks | CFD/futures basis, narrow two-asset rank, XAG industrial beta, gaps, costs |

Q02 must establish trade density and economics. Later unchanged correlation
and portfolio gates alone can test whether the realized return stream is
genuinely different from the index/metal book.

## 6. Source Citation

Fuertes, A.-M., Miffre, J., and Rallis, G. (2010), “Tactical Allocation in
Commodity Futures Markets: Combining Momentum and Term Structure Signals,”
*Journal of Banking & Finance* 34(10), 2530–2548,
https://doi.org/10.1016/j.jbankfin.2010.04.009.

The governed source packet at
`strategy-seeds/sources/FMR-MOMTS-2010/source.md` records a complete read of
the 47-page accepted manuscript. Pages 6–7 and 17–18 define and test the
source-declared one-, three-, and twelve-month momentum ranks with a one-month
hold. The two-CFD carrier, XAU/XAG-only cross-section, ATR stops, risk split,
and execution rules are disclosed QM hypotheses rather than imported
performance claims.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The sizing helper computes each leg against its frozen
`3.5 * ATR(20,D1)` stop and then assigns half of the one package budget to
each leg. News axes are OFF, Friday close is disabled, and there is no
take-profit, trailing stop, scale-in, grid, martingale, or pyramiding.

The canonical rules, source boundary, parameters, kill criteria, and framework
alignment are in
`strategy-seeds/cards/QM5_20184_xauxag-xmom3_card.md`. This is the
source-declared three-month formation horizon, not the existing one- or
twelve-month strategy. The build creates no live setfile and grants no deploy,
certification, portfolio, or trading authorization.
