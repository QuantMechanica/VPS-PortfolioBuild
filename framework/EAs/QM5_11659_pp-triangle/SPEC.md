# QM5_11659_pp-triangle - Strategy Spec

**EA ID:** QM5_11659

**Slug:** pp-triangle

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab

**Last revised:** 2026-08-06

## 1. Strategy Logic

On the first tick of each new bar, the EA evaluates the cited PatternPy
three-bar rolling mask using completed H4 bars only. The signal row is shift 1;
the rolling window covers shifts 1 through 3; and the source's prior row is
shift 2.

- Ascending label: rolling high is at or above high[2], rolling low is at or
  below low[2], and close[1] is above close[2].
- Descending label: rolling high is at or below high[2], rolling low is at or
  above low[2], and close[1] is below close[2].
- An Ascending label opens long and a Descending label opens short at the next
  bar open, provided the magic has no open position.
- A long closes on a Descending label, a completed close below the actual entry
  bar low, or the time stop. A short uses the symmetric rules.
- No trendline reconstruction, breakout buffer, take-profit, trailing stop,
  break-even, partial close, grid, martingale, or ML is present.

The rolling comparisons deliberately retain the source's asymmetry: because
the prior bar belongs to the rolling window, the first two Ascending
comparisons are inclusive bounds, while both Descending bounds require the
prior bar to be the rolling high and rolling low. This is source fidelity, not
an inferred pattern improvement.

## 2. Parameters

| Parameter | Default | Authorized P3 range | Meaning |
|---|---:|---:|---|
| strategy_window | 3 | 3 to 20 | rolling high/low window |
| strategy_atr_period | 14 | 14 to 30 | emergency-stop ATR period |
| strategy_sl_atr_mult | 2.0 | 1.0 to 3.0 | emergency-stop ATR multiple |
| strategy_max_hold_bars | 12 | 6 to 30 | maximum completed H4 bars held |

The Q01 baseline uses only the defaults. The listed ranges reproduce the
approved card's P3 search boundary; they do not authorize a parameter search
during this build.

## 3. Symbol Universe

The approved portable basket and deterministic magic slots are:

| Card symbol | Broker symbol | Slot |
|---|---|---:|
| EURUSD | EURUSD.DWX | 0 |
| GBPUSD | GBPUSD.DWX | 1 |
| XAUUSD | XAUUSD.DWX | 2 |
| GER40 | GDAXI.DWX | 3 |
| NDX | NDX.DWX | 4 |

The EA fails closed for any other symbol or a mismatched slot.

## 4. Timeframe

The build baseline is H4. Signals, structural exits, entry-bar reconstruction,
and the time stop consume completed H4 bars only. The card permits H1, H4, and
D1 investigation later, but this portable Q01 build and its setfiles are H4
and fail closed on other chart periods.

## 5. Expected Behaviour

The approved prior is approximately 40 trades per year per symbol. That figure
is a hypothesis, not performance evidence. Q02 should reject zero-trade setup
failures and measure actual activity separately on each portable symbol. The
strategy is directional, one-position, structural OHLC logic and is expected
to behave differently across FX, metal, and index volatility regimes.

## 6. Source Citation

Keith Orange / keithorange, PatternPy,
tradingpatterns/tradingpatterns.py, function detect_triangle_pattern:
https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py

The implementation translates that function's rolling comparisons literally.
The source provides no stop or portfolio evidence; the approved V5 card adds
only the emergency stop and explicit lifecycle exits documented above.

## 7. Risk Model

Backtest setfiles use RISK_PERCENT=0 and RISK_FIXED=1000 with
PORTFOLIO_WEIGHT=1. Each entry receives a broker hard stop at 2.0 times the
completed-bar ATR(14), and no take-profit. The framework sizes from that fixed
risk budget. Management never widens or mutates the stop.

No live setfile, T_Live action, AutoTrading action, deploy manifest,
portfolio-gate edit, or live-use authorization is part of this build.

## Build History

| Version | Date | Event |
|---|---|---|
| 5.1 | 2026-08-06 | Rebuilt from the approved card's literal PatternPy mask; removed the prior card-deviant trendline model and unauthorized TP |
