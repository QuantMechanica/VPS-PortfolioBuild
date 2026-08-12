# QM5_20028 wti-dom1-long

**EA ID:** QM5_20028

## 1. Strategy Logic

At the opening of an actual `XTIUSD.DWX` D1 bar dated calendar day 1, BUY
once. Never shift a missing first-of-month session or retry a consumed month.
Close at the first following D1 boundary, with rejected-close retries, a
one-day stale guard and framework Friday close.

## 2. Parameters

- `strategy_entry_day=1` (locked)
- `strategy_atr_period=20` (locked)
- `strategy_atr_sl_mult=2.75` (locked)
- `strategy_max_hold_days=1` (locked)
- `strategy_max_spread_points=2500` (locked)

## 3. Symbol Universe

Single registered symbol and magic slot: `XTIUSD.DWX`, slot 0, magic
`200280000`. No foreign symbol or basket leg is authorized.

## 4. Timeframe

Host, signal and management timeframe: D1. Entries are evaluated only on a
genuine new D1 bar.

## 5. Expected Behaviour

Expected cadence is approximately 8-10 completed packages/year because a
non-trading first of month is skipped. Q02 retires below five/year. The edge is
a sparse calendar carrier, not trend, inventory, RSI or price reversion.

## 6. Source Citation

Borowski, K. (2016), "Analysis of Selected Seasonality Effects in Markets of
Future Contracts...", *Journal of Management and Financial Sciences*, issue
26, 27-44, section 4.3. WTI day 1 has the highest numbered-day mean
(`+0.0338%`) but is not reported significant; this adverse fact is binding.

## 7. Risk Model

Q02 only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. A frozen
prior-bar ATR(20) x 2.75 broker hard stop is attached with no TP, trailing,
scale, grid or martingale. No live setfile, T_Live action, deploy manifest or
portfolio-gate change is authorized.
