# QM5_41063_xng-week-nr7-brk - Strategy Spec

EA ID: `QM5_41063`

Slug: `xng-week-nr7-brk`

Strategy ID: `CRABEL-XNG-WEEKNR7-2026_S01`

Source: `CRABEL-XNG-WEEKNR7-2026`

Author: Codex

Last revised: 2026-08-20

## 1. Strategy Logic

On each new `XNGUSD.DWX` D1 bar, normalize the energy session label with one
uniform zero-day or `+1`-day convention. The immediately prior normalized
broker week must contain exactly one completed bar for every Monday through
Friday and its full D1 high-low range must be strictly smaller than the ranges
of the six next-most-recent valid complete weeks.

During the immediately following week, buy on the first completed D1 close
strictly above the compressed-week high or sell on the first completed close
strictly below its low. One restart-safe attempt is consumed per broker week.
The position carries a frozen `3.5 * ATR(20,D1)` hard stop, no target, and is
flat by broker Friday 21.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_week_lookback` | 7 | exact complete-week NR sample |
| `strategy_history_bars` | 90 | bounded D1 retrieval buffer |
| `strategy_entry_min_dow` | 2 | broker Tuesday first entry day |
| `strategy_entry_max_dow` | 5 | broker Friday last entry day |
| `strategy_entry_grace_minutes` | 180 | new-D1 execution window |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 8 | stale-position repair |
| `strategy_max_spread_points` | 1500 | XNG entry cost guard |
| `qm_friday_close_enabled` | true | preserve Friday-flat identity |
| `qm_friday_close_hour_broker` | 21 | explicit broker close hour |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XNGUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `410630000`.
- No companion, read-only symbol, alias, ratio, or external market series.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: seven valid complete normalized broker weeks.
- Trigger: first next-week completed-close escape from prior-week extrema.
- Hold: through broker Friday 21 at the latest, with later-week and eight-day
  repair paths.

## 5. Expected Behaviour

- Approximately five to ten completed positions per full post-warm-up year.
- Symmetric direct-XNG volatility-compression/expansion continuation.
- One fixed-risk position and one consumed attempt per broker week.
- Q02 retires below five completed positions per full year.

## 6. Source Citation

Crabel, Toby. *Day Trading with Short-Term Price Patterns and Opening Range
Breakout*. Traders Press, 1990.

Canonical bounded source packet:
`strategy-seeds/sources/CRABEL-XNG-WEEKNR7-2026/source.md`.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses a frozen completed-bar ATR stop through the V5 risk
helper. Both news axes are OFF. Framework Friday close is enabled and the EA
also runs explicit later-week and stale repairs.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, decorrelation claim,
correlation waiver, portfolio-gate change, external feed, retry, scale-in,
grid, martingale, pyramid, target, trail, break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-20 | approved build-directory identity | source approval `467ec1cdd`; deterministic registry allocation |
