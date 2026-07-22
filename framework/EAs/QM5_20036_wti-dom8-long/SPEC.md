# QM5_20036 wti-dom8-long

**EA ID:** QM5_20036

## 1. Strategy Logic

At the opening of an actual `XTIUSD.DWX` D1 bar dated calendar day 8, BUY
once. Never shift a missing eighth-day session or retry a consumed month.
Close at the first following D1 boundary, with rejected-close retries, a
one-day stale guard and framework Friday close.

## 2. Parameters

- `strategy_entry_day=8` (locked)
- `strategy_atr_period=20` (locked)
- `strategy_atr_sl_mult=2.75` (locked)
- `strategy_max_hold_days=1` (locked)
- `strategy_max_spread_points=2500` (locked)

## 3. Symbol Universe

Single registered symbol and magic slot: `XTIUSD.DWX`, slot 0, magic
`200360000`. No basket or foreign symbol is authorized.

## 4. Timeframe

Host, signal, and management timeframe: D1. Entry evaluation occurs only on a
genuine new D1 bar.

## 5. Expected Behaviour

Expected cadence is 8-10 packages/year; Q02 retires below five. This is a
sparse exact-date calendar carrier, not trend, inventory, RSI, or reversion.

## 6. Source Citation

Borowski (2016), *Journal of Management and Financial Sciences* 26, 27-44,
section 4.3 reports WTI day 8 as statistically distinct (`p=0.0430`) in its
1983-2016 NYMEX sample. The card fixes the direction long from the table's
positive day-8 mean. Multiple testing, post-publication decay, CFD/futures
basis, and gaps remain explicit falsification risks.

## 7. Risk Model

Q02 only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1, frozen prior-bar
ATR(20) x 2.75 broker hard stop. No TP, trailing, scale, grid, martingale,
live setfile, T_Live action, deploy manifest, or portfolio-gate change.
