# QM5_41349 — WTI ADF/Sample-Entropy Agreement Trend

## Contract

At the first executable `XTIUSD.DWX` D1 bar of a genuine broker month,
reconstruct exactly 61 consecutive completed month-end closes. Run the locked
lag-one intercept-only ADF regression on the newest 60 log levels and exact
sample entropy on all 60 adjacent log returns. Trade the newest twelve-month
WTI return sign only when `adf_t >= -2.594` and `SampEn <= 2.5`.

The card of record is `docs/strategy_card.md`; the approved repository card is
`strategy-seeds/cards/approved/QM5_41349_wti-adf-sampen-agree-tr_card.md`.

## Locked Q02 baseline

- Host/order symbol: `XTIUSD.DWX`, D1, slot 0, magic `413490000`.
- ADF: newest 60 log levels, lag one, intercept/no time trend, 58 rows,
  residual dof 55, inclusive boundary `-2.594`.
- Sample entropy: 60 returns, sample-sd radius `0.2`, `m=2`, lag one, strict
  Chebyshev match, no self matches, `ln(B/A)`, inclusive ceiling `2.5`.
- Direction: strict newest twelve-month log-return sign; disagreement is flat.
- Attempt: consume the broker month before every fallible entry gate; no retry.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Stop: frozen `3.5 * ATR(20,D1)`; no target.
- Exit: first later-month bar or 40 elapsed days; malformed state closes.
- Spread ceiling: 1,500 points. News, Friday close, and stress are off.

## Framework alignment

- No-trade: exact identity/risk/news/Friday/stress and locked-input guards.
- Entry: persisted month, endpoints, ADF, sample entropy, conjunction, WTI
  side, spread/quote/ATR/stop, and one fixed-risk order.
- Management: wrong-state repair, signal-side reconstruction, next-month and
  stale exits.
- Close: framework close helper, broker stop, and kill switch.

## Safety and acceptance

The source build authorizes strict Q01 and one paced Q02 handoff only. No
manual backtest, optimization, live preset, portfolio admission/gate change,
deployment, `T_Live`, or AutoTrading action is authorized. Q02 retires below
five completed positions in any full post-warm-up year or on nonpositive
governed economics; unchanged Q09 alone may establish useful decorrelation.
