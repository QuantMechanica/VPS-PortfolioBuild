# QM5_13117_eurgbp-audjpy - Strategy Spec

**EA ID:** QM5_13117  
**Slug:** eurgbp-audjpy  
**Source:** SRC02_S09  
**Author:** Codex  
**Last revised:** 2026-07-10

## 1. Strategy Logic

The EA trades the fixed EURGBP.DWX/AUDJPY.DWX D1 log spread
`ln(EURGBP) - beta * ln(AUDJPY)` with beta `-0.12202869296345396`. A 60-bar
rolling z-score opens a short-spread package above `+2.0`, opens a long-spread
package below `-2.0`, and closes both legs inside `abs(z) < 0.5`.

Because beta is negative, a long spread buys both legs and a short spread
sells both. Fixed risk is divided in `1:abs(beta)` weight. Every leg has a hard
`2.0 * ATR(20, D1)` stop; failed partial entry or an orphaned leg triggers
package cleanup. There is no adaptive beta, grid, martingale, averaging,
pyramiding, partial exit, or trailing stop.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| strategy_z_lookback_d1 | 60 | rolling spread mean and standard-deviation window |
| strategy_beta | -0.12202869296345396 | fixed DEV regression hedge |
| strategy_entry_z | 2.0 | absolute entry threshold |
| strategy_exit_z | 0.5 | mean-reversion exit band |
| strategy_atr_period_d1 | 20 | per-leg hard-stop ATR period |
| strategy_atr_sl_mult | 2.0 | per-leg hard-stop multiplier |
| strategy_deviation_points | 20 | basket market-order deviation |

## 3. Symbol Universe

- EURGBP.DWX: logical host and traded spread numerator, magic slot 0.
- AUDJPY.DWX: traded beta-weighted leg, magic slot 1.
- GBPUSD.DWX: USD tester conversion/history dependency only; never traded.
- USDJPY.DWX: USD tester conversion/history dependency only; never traded.
- All other symbols are out of strategy scope.

## 4. Timeframe

- D1 base timeframe, evaluated once per new closed host D1 period.
- Both traded histories must provide the same aligned D1 timestamps across the
  full 60-bar state window before the EA may enter.

## 5. Expected Behaviour

- Expected approximately five logical packages per year, based on 20 OOS
  state changes over the two-year screen.
- Expected holding period is several weeks; the measured half-life is 36.84
  D1 bars and framework Friday close remains enabled.
- The scan measured DEV net Sharpe `0.4168`, OOS net Sharpe `0.8919`, OOS
  return `4.4752%`, and 20 OOS state changes under approximate costs.
- Expected drawdown is high because the hedge is small and both negative-beta
  legs point in the same direction; real-tick cost, swap, and conversion are
  delegated to Q02 onward.

## 6. Source Citation

Strategy `SRC02_S09` uses the OWNER-requested 66-pair FX scan documented in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` and its sign-aware
reproduction in `docs/research/FX_COINTEGRATION_EURGBP_AUDJPY_REVIEW_2026-07-10.md`.
The reputable method supplement is Ernest P. Chan, *Quantitative Trading*
(Wiley, 2009), Example 3.6 and Chapter 7, locally extracted at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. All R1-R4
checks pass per
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_13117_eurgbp-audjpy.md`.

## 7. Risk Model

| Environment | Active mode | Required values |
|---|---|---|
| Q02-Q10 backtest | RISK_FIXED | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| Live | not authorized | no live setfile or deploy manifest |

`PORTFOLIO_WEIGHT=1` is fixed for structural backtests. The logical basket
manifest pins tester currency to USD and deposit to 100,000. Risk is allocated
once across the two legs in normalized `1:abs(beta)` weight, with a server-side
ATR hard stop on each leg.

## Revision History

| Version | Date | Reason | Build task |
|---|---|---|---|
| v1 | 2026-07-10 | Initial build from approved card | 5bd33354-c9f1-4221-8e51-e78767867913 |
