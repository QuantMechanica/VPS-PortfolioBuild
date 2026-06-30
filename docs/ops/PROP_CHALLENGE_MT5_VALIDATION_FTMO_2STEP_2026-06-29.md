# Prop Challenge MT5 Validation - FTMO 2-Step - 2026-06-29

Scope: validate the best FTMO sprint candidate with real MT5 Strategy Tester
backtests on free factory terminals. `T_Live` was not touched.

## Candidate Tested

Candidate from the first sprint optimizer screen:

- `12567:XNGUSD.DWX`
- `12567:XAUUSD.DWX`
- `11132:SP500.DWX`

The optimizer score was originally strong, but the first implementation counted
active trade days only. During MT5 validation this was corrected: prop challenge
simulation now fills missing calendar days with zero PnL.

## MT5 Setup

Terminals used:

- `T8`: `12567:XNGUSD.DWX`
- `T9`: `12567:XAUUSD.DWX`
- `T10`: `11132:SP500.DWX`

New research-only setfiles:

- `framework/EAs/QM5_12567_cum-rsi2-commodity/sets/QM5_12567_cum-rsi2-commodity_XNGUSD.DWX_D1_prop_ftmo_scale8_equiv_backtest.set`
- `framework/EAs/QM5_12567_cum-rsi2-commodity/sets/QM5_12567_cum-rsi2-commodity_XAUUSD.DWX_D1_prop_ftmo_scale8_equiv_backtest.set`
- `framework/EAs/QM5_11132_tm-cum-rsi2/sets/QM5_11132_tm-cum-rsi2_SP500.DWX_D1_prop_ftmo_scale8_equiv_backtest.set`

These use the Q12/live strategy parameters, not the older blank backtest
setfiles. They set:

- `RISK_FIXED=2666.6667`
- `RISK_PERCENT=0`
- `PORTFOLIO_WEIGHT=1.0`

Tester deposit was overridden to `1,000,000` so the framework's hard 1% per-trade
risk cap would not silently reduce `RISK_FIXED=2666.6667`. Results were then
evaluated against a `100,000` FTMO account.

## Backtest Evidence

| sleeve | terminal | trades | PF | net | max equity DD | summary |
|---|---|---:|---:|---:|---:|---|
| `12567:XNGUSD.DWX` | `T8` | 54 | `1.33` | `4930.28` report / `4931.14` extracted | `6184.49` | `D:\QM\reports\prop_ftmo_mt5_20260629\scale8_equiv_xng\QM5_12567\20260629_101240\summary.json` |
| `12567:XAUUSD.DWX` | `T9` | 73 | `1.63` | `13061.40` | `6449.65` | `D:\QM\reports\prop_ftmo_mt5_20260629\scale8_equiv\QM5_12567\20260629_094945\summary.json` |
| `11132:SP500.DWX` | `T10` | 75 | `1.43` | `20949.98` report / `21006.40` extracted | `13134.74` | `D:\QM\reports\prop_ftmo_mt5_20260629\scale8_equiv\QM5_11132\20260629_094945\summary.json` |

MT5 validation artifact:

`D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_2step_mt5_scale8_equiv_20260629.json`

## Corrected FTMO Simulation

Method:

- parse closing deals from MT5 HTML reports;
- aggregate daily PnL across the three sleeves;
- fill all calendar days from first to last trade with zero PnL;
- evaluate FTMO 2-step with 60 calendar days per phase.

Combined MT5 extracted result:

- calendar days: `2673`
- extracted net: `38998.94`
- best day: `3433.06`
- worst closed day: `-3487.15` (`3.487%` of 100k)
- profit days: `113`
- loss days: `75`

FTMO 2-step, 60-calendar-day phase horizon, 2000 simulations:

| method | pass | phase-1 pass | daily-loss breach | max-loss breach | target-not-reached |
|---|---:|---:|---:|---:|---:|
| block bootstrap | `0.0%` | `0.25%` | `0.0%` | `0.0%` | `100.0%` |
| day-order shuffle | `0.0%` | `0.15%` | `0.0%` | `0.05%` | `99.95%` |

Conclusion: this candidate is not a viable 60-calendar-day FTMO sprint. It is
not too dangerous in closed-PnL terms; it is too slow once zero-PnL calendar days
are counted.

## Corrective Code Change

`prop_challenge_sim.py` and `prop_challenge_optimizer.py` now use full calendar
daily series for prop-challenge timing. The prior active-trade-day ranking is
methodically invalid for low-frequency D1 sleeves.

Regression:

```powershell
python -m pytest tools\strategy_farm\tests\test_prop_challenge_optimizer.py `
  tools\strategy_farm\tests\test_prop_challenge_sim.py `
  tools\strategy_farm\tests\test_portfolio_montecarlo.py `
  tools\strategy_farm\tests\test_portfolio_q08_contribution.py `
  tools\strategy_farm\tests\test_portfolio_admission.py -q
```

Result: `34 passed`.

## Follow-Up

For a 60-calendar-day prop sprint we need higher trade frequency or a different
phase horizon assumption. The corrected small Q12-ready calendar screen found
faster candidates only by accepting high max-loss breach risk, so the current
Q12-ready book is not yet a clean FTMO sprint book.
