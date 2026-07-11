# QM5_13119_usdjpy-euraud - Strategy Spec

**EA ID:** QM5_13119  
**Slug:** usdjpy-euraud  
**Source:** SRC02_S10  
**Author:** Codex  
**Last revised:** 2026-07-10

## 1. Strategy Logic

The EA trades the fixed USDJPY.DWX/EURAUD.DWX D1 log spread
`ln(USDJPY) - beta * ln(EURAUD)` with beta `-1.4182482311707278`. A 60-bar
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
| strategy_beta | -1.4182482311707278 | fixed DEV regression hedge |
| strategy_entry_z | 2.0 | absolute entry threshold |
| strategy_exit_z | 0.5 | mean-reversion exit band |
| strategy_atr_period_d1 | 20 | per-leg hard-stop ATR period |
| strategy_atr_sl_mult | 2.0 | per-leg hard-stop multiplier |
| strategy_deviation_points | 20 | basket market-order deviation |

## 3. Symbol Universe

- USDJPY.DWX: logical host and traded spread numerator, magic slot 0.
- EURAUD.DWX: traded beta-weighted leg, magic slot 1.
- AUDUSD.DWX: USD tester conversion/history dependency only; never traded.
- All other symbols are out of strategy scope.

## 4. Timeframe

- D1 base timeframe, evaluated once per new closed host D1 period.
- Both traded histories must provide the same aligned D1 timestamps for the
  newest closed observation and the full 60-bar calibration window before the
  EA may enter.
- The newest closed spread is scored against the strictly preceding 60 closed
  spreads; it is not included in its own mean or standard-deviation estimate.
- The EA selects and warms the manifest-declared AUDUSD.DWX conversion history
  with the traded legs before the first package entry.

## 5. Expected Behaviour

- Expected approximately six logical packages per year, based on 23 OOS
  state changes over the two-year screen.
- Expected holding period is several weeks; the measured half-life is 77.46
  D1 bars and framework Friday close remains enabled.
- The scan measured DEV net Sharpe `0.5059`, OOS net Sharpe `0.8837`, OOS
  return `16.0148%`, and 23 OOS state changes under approximate costs.
- Expected drawdown is high because the negative-beta legs point in the same
  direction and the 77-day half-life makes adverse holds persistent; real-tick cost, swap, and conversion are
  delegated to Q02 onward.

## 6. Source Citation

Strategy `SRC02_S10` uses the OWNER-requested 66-pair FX scan documented in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` and its sign-aware
reproduction in `docs/research/FX_COINTEGRATION_USDJPY_EURAUD_REVIEW_2026-07-10.md`.
The reputable method supplement is Ernest P. Chan, *Quantitative Trading*
(Wiley, 2009), Example 3.6 and Chapter 7, locally extracted at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. All R1-R4
checks pass per
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_13119_usdjpy-euraud.md`.

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
| v1 | 2026-07-10 | Initial build from approved card | 537f2dc1-b542-42d2-95a3-b6d72ddcd65d |
| v2 | 2026-07-10 | Warm manifest-declared USD conversion history before Q02 | existing Q02 row preserved |
| v3 | 2026-07-11 | Exclude the scored spread from its prior 60-bar z-score calibration window | existing Q02 row preserved |
