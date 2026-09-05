# QM5_41341 — XAU/XAG Monthly Redescending-Bisquare Reversion

## Contract

At the first synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 bar of a genuine
broker month, reconstruct exactly thirteen consecutive synchronized completed
month-end gold-minus-silver log ratios. Form twelve adjacent chronological
ratio returns, compute their exact 32-step Tukey-bisquare robust location, and
fade its sign with an opposed, equal-target-notional pair.

The source card of record is `docs/strategy_card.md`; the approved repository
card is
`strategy-seeds/cards/approved/QM5_41341_xauxag-mbisquare-rv_card.md`.

## Locked Q02 baseline

- Logical basket: `QM5_41341_XAU_XAG_BISQ_RV_D1`.
- Host: `XAUUSD.DWX`, D1, slot 0, magic `413410000`.
- Second traded leg: `XAGUSD.DWX`, slot 1, magic `413410001`.
- Signal: even median/MAD, `1.4826` normalization, frozen `4.685` cutoff,
  strict compact-support squared weights, exactly 32 updates, and strict
  `1e-12` final-location epsilon.
- Direction: positive robust location sells XAU/buys XAG; negative robust
  location buys XAU/sells XAG.
- Risk: one aggregate `RISK_FIXED=1000` budget, equal target notionals within
  20%, and frozen `3.5*ATR(20,D1)` hard stops on both legs.
- Entry grace: 180 minutes; endpoint staleness: 10 days; bounded history:
  1,200 D1 bars.
- Exit: next broker month or forty elapsed calendar days. News, Friday close,
  and stress are off.

## Framework alignment

- No-trade: exact identity/risk/news/Friday/stress/parameter guards and one
  consumed month.
- Entry: synchronized month-end reconstruction, robust statistic, contrarian
  side, aggregate sizing, and atomic two-leg open.
- Management: wrong-state repair, notional integrity, next-month liquidation,
  and stale exit.
- Close: basket close helper, broker hard stops, and kill switch.

## Safety and acceptance

The build authorizes non-live Q01 and one paced Q02 handoff only. Q02 retires
below five completed logical packages in any full post-warm-up year or on
nonpositive governed economics. Q09 alone may establish realized portfolio
correlation. No manual backtest, optimization, portfolio gate/admission,
deploy/live manifest, `T_Live`, AutoTrading, or live operation is authorized.
