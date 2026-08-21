# QM5_41087 WTI Weekly WR4 Close Momentum

## Identity

- EA: `QM5_41087_wti-wr4-close-mom`
- strategy: `CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026_S01`
- exact carrier: `XTIUSD.DWX`
- exact period: `D1`
- slot: 0
- magic: `410870000`

## Entry contract

On the first tradable D1 bar of a new normalized Monday-anchored broker week,
consume one durable attempt and aggregate the four immediately preceding
completed weeks. Each week must have three to five D1 sessions and exact
consecutive anchors. The newest completed week must have a full high-low range
strictly greater than each of the three older ranges.

Let `body=ln(newest_close/newest_open)` and
`clv=(newest_close-newest_low)/(newest_high-newest_low)`. Buy only on strict
`body>0 && clv>0.75`; sell only on strict `body<0 && clv<0.25`. Equality,
ties, invalid history, mixed labels, or any other state is flat.

## Risk and lifecycle

- fixed backtest risk: `RISK_FIXED=1000`; `RISK_PERCENT=0`; weight 1;
- frozen stop: `3.5 * ATR(20,D1)`; no take profit;
- maximum spread: 1,500 points;
- one position and one attempt per broker week;
- close on the first tick of a later broker week;
- ten-calendar-day stale repair;
- news OFF and Friday close OFF.

No current-week price enters the signal. No retry, optimization surface,
scale-in, grid, martingale, pyramid, hedge, trail, break-even move, partial
close, external runtime feed, banned signal, or trained logic is authorized.

## Validation

Reference tests must cover four exact weekly packages, session bounds,
earliest-open/final-close aggregation, range ties, older-wider states, both
valid sides, body/CLV disagreement and equality, label normalization, and
next-week lifecycle. Strict compile, resolver validation, canonical fixed-risk
setfile validation, framework build check, and static P1 must pass before Q02.
