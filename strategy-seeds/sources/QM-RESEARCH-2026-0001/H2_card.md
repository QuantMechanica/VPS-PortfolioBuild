# Strategy Card (mechanized) — H2: Trade density, not per-trade edge, is the binding FTMO constraint

## Research provenance
This candidate was discovered by offline research (directive §41 permits ML/statistical
instruments such as clustering, regression, feature importance and regime identification
in research only). No model, inference API, or online learning is used at runtime; the
rules below are executable from this specification alone (directive §42/§51).

## Structural cause
Across the scored population, low activity (trades/yr, active-days) predicts FTMO failure more strongly than low median gain: the book fails the min-trading-day + target-progression requirement before it fails on expectancy. The economic rationale is a session/liquidity effect (mean reversion inside a
bounded trading window), not an artefact of parameter search.

## Price signature
Price stretches away from a short intraday reference and reverts before the session ends;
the entry fires on a bounded stretch, the exit on reversion or session close.

## Persistence
The effect is expected to persist because it rests on recurring intraday inventory and
session-transition behaviour rather than a one-off regime.

## Long entry
Enter long when the intraday z-score of price versus its lookback mean falls below the
negative entry threshold within the trading session.

## Short entry
Enter short when the intraday z-score of price versus its lookback mean rises above the
positive entry threshold within the trading session.

## No-trade conditions
Do not trade outside the configured session window and do not open a new position when a
scheduled high-impact news event (live news filter) is within the blackout window.

## Exit
Exit when the z-score reverts through the exit threshold or at session close, whichever
comes first (no overnight hold).

## Stop loss
Fixed stop at atr_stop_mult times the ATR at entry.

## Take profit
Reversion to the mean (exit threshold) is the profit target; no fixed distant target.

## Trailing logic
Optional break-even move once price has travelled one ATR in favour; bounded, finite.

## Position sizing
Risk a fixed fraction of equity per trade (RISK_FIXED in backtest, RISK_PERCENT live);
lot size derived deterministically from stop distance.

## Session rules
Trade only between session_start_hour and session_end_hour (broker time); flat by session
end.

## Filters
Volatility-regime filter: trade only when ATR is within a bounded band; a bounded no-trade
filter may exclude a losing session/regime cluster.

## Indicators and required data
Native MT5 price series, a moving average, an ATR, and the live MT5 news calendar. No
external feed.

## Timeframe
M15

## Symbols
EURUSD, XAUUSD, GBPUSD, USDJPY (symbols are inputs, never code literals).

## Parameter ranges
- trades_per_year_floor: 5 .. 40
- active_days_floor: 10 .. 120
- news_blackout_minutes: 0 .. 120

## Expected frequency
Expected trade frequency is intraday: on the order of several trades per week per symbol,
well above the Q02 >=5 trades/yr floor.

## Invalidation conditions
Refuted if activity adds no incremental explanatory power over median gain for the observed FTMO pass/fail outcomes.

## Falsification / kill criteria
The candidate is killed if out-of-sample worst-day loss or wdd_p90 does not improve versus
the swing baseline, or if the edge depends on a single symbol or single period.

## Q08/Q11 crisis and news risk
Session-flat exposure limits crisis-gap risk; the live news filter fails closed. Q08 stress
and Q11 full-history confirmation remain the judges.

## FTMO fit
Short holding, no overnight swap, bounded daily loss and higher trade density target the
FTMO Challenge completion probability rather than standalone profit factor.
