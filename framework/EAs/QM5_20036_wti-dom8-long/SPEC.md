# QM5_20036 wti-dom8-long

**EA ID:** QM5_20036

## Strategy Logic

At the opening of an actual `XTIUSD.DWX` D1 bar dated calendar day 8, BUY
once. Never shift a missing eighth-day session or retry a consumed month.
Close at the first following D1 boundary, with rejected-close retries, a
one-day stale guard and framework Friday close.

## Locked Parameters

- `strategy_entry_day=8`
- `strategy_atr_period=20`
- `strategy_atr_sl_mult=2.75`
- `strategy_max_hold_days=1`
- `strategy_max_spread_points=2500`

Single registered symbol and magic slot: `XTIUSD.DWX`, D1, slot 0, magic
`200360000`. Expected cadence is 8-10 packages/year; Q02 retires below five.

## Source and Risk

Borowski (2016), *Journal of Management and Financial Sciences* 26, 27-44,
section 4.3 reports WTI day 8 as statistically distinct (`p=0.0430`) in its
1983-2016 NYMEX sample. The card fixes the direction long from the table's
positive day-8 mean. Multiple testing, post-publication decay, CFD/futures
basis and gaps remain explicit falsification risks.

Q02 only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1, frozen prior-bar
ATR(20) x 2.75 broker hard stop. No TP, trailing, scale, grid, martingale,
live setfile, T_Live action, deploy manifest, or portfolio-gate change.
