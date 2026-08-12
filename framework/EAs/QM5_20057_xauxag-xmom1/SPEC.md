# QM5_20057_xauxag-xmom1 - Strategy Spec

**EA ID:** QM5_20057

**Slug:** `xauxag-xmom1`

**Strategy ID:** `FMR-MOMTS-2010_XAU_XAG_S03`

**Approved card:** `docs/strategy_card.md`

## 1. Strategy Logic

On the first tradable D1 bar of each broker month, reconstruct the last close
from each of the two completed broker months for gold and silver. Calculate one
simple monthly return per leg. Buy the higher-return metal and sell the
lower-return metal; a tie or invalid observation remains flat. Hold one paired
package until the next broker-month transition, with a 40-calendar-day stale
guard. A malformed or orphaned package is flattened.

There is no ratio, mean-reversion transform, breakout, adaptive fit, banned
indicator, external data feed, pyramiding, martingale, grid, or ML component.

## 2. Parameters

| Parameter | Baseline | Purpose |
|---|---:|---|
| `strategy_return_window_months` | 1 | Locked completed-month formation window |
| `strategy_history_bars` | 500 | Bounded D1 month-close reconstruction buffer |
| `strategy_atr_period_d1` | 20 | Frozen hard-stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | ATR hard-stop multiple |
| `strategy_max_hold_days` | 40 | Stale-package time stop |
| `strategy_xti_max_spread_pts` | 1500 | XAU spread cap; legacy input name |
| `strategy_xng_max_spread_pts` | 3000 | XAG spread cap; legacy input name |
| `strategy_deviation_points` | 20 | Order deviation allowance |

## 3. Symbol Universe

The logical basket is `QM5_20057_XAU_XAG_XMOM1_D1`:

- Slot 0 and host chart: `XAUUSD.DWX`.
- Slot 1: `XAGUSD.DWX`.

Exactly one position per leg is permitted. The legs must be opposite and use
their registered per-symbol magic numbers.

## 4. Timeframe

The host and both signal histories use native `D1` data. Signal evaluation is
monthly, on the first available D1 bar after a broker-month transition. Trade
management and framework risk controls remain active on every tick.

## 5. Expected Behaviour

The baseline expects approximately 12 two-leg packages per year before Q02
falsification. Each valid monthly observation opens the prior-month winner long
and the loser short, unless a package was already attempted for that month.
Both legs close at the next monthly transition or after 40 calendar days.
Missing history, invalid prices, invalid ATR, excessive spread, invalid magic,
or sizing failure must fail closed. If the second leg cannot open, the first is
closed immediately.

## 6. Source Citation

Fuertes, Ana-Maria, Joelle Miffre, and Georgios Rallis (2010), “Tactical
Allocation in Commodity Futures Markets: Combining Momentum and Term Structure
Signals,” *Journal of Banking & Finance* 34(10), 2530-2548,
doi:10.1016/j.jbankfin.2010.04.009. The approved card narrows the paper’s broad
commodity-futures cross section to two broker CFDs as a carrier falsification;
it does not import the paper’s performance claims.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1.0`. Package risk is split equally between the two legs.
Each leg receives a frozen `ATR(20) * 3.5` hard stop; there is no take-profit,
trail, partial close, or scale-in. The framework kill switch remains
authoritative. Friday close is disabled to preserve the monthly hold.
