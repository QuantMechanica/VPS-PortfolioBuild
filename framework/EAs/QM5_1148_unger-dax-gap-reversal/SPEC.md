# QM5_1148 Unger DAX Gap Reversal

## Scope

- `ea_id`: 1148
- `slug`: `unger-dax-gap-reversal`
- Primary symbol: `GDAXI.DWX`
- Timeframe: `M30`
- Build phase only: no backtests or pipeline phases executed.

## Strategy Mapping

- No-trade: V5 framework kill-switch, news, Friday close, symbol/timeframe guard, session parameter validation.
- Entry: after the first completed DAX reference-session M30 bar, fade gaps where the session open is above the previous session high or below the previous session low.
- Management: one pending order per day, one filled trade per day, cancel any unfilled order after the first three M30 bars.
- Exit: ATR stop, ATR take-profit, or session/pre-close flatten.

## Defaults

- Session: 08:00-22:00 broker time as Europe/Berlin-aligned DAX reference session.
- Gap threshold: `0.25 * ATR(14,D1)`.
- Stop loss: `1.0 * ATR(14,M30)`.
- Take profit: `1.0 * ATR(14,M30)`.
- Risk: backtest `RISK_FIXED=1000`; live `RISK_PERCENT=0.25`.

## Registry

- Magic slot `0`: `GDAXI.DWX`, magic `11480000`.

## Notes

- The card references an older DAX session structure; this first build keeps the stable 08:00-22:00 configurable session.
- Live routability depends on the deploy workflow's broker-symbol mapping. Build artifacts keep `.DWX` naming.
