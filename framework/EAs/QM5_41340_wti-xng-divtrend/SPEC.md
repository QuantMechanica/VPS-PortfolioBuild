# QM5_41340 — WTI/XNG Twelve-Month Sign-Divergence Trend

## Contract

At the first `XTIUSD.DWX` D1 bar of a genuine broker month, intersect bounded
completed XTI/XNG D1 histories and reconstruct exactly thirteen consecutive
synchronized month ends through the immediately prior month. Trade WTI in the
sign of its exact twelve-month log return only when XNG's exact twelve-month
sign is strictly opposite. XNG is read-only.

The source card of record is `docs/strategy_card.md`; the approved repository
card is `strategy-seeds/cards/approved/QM5_41340_wti-xng-divtrend_card.md`.

## Locked Q02 baseline

- Host/order symbol: `XTIUSD.DWX`, D1, slot 0, magic `413400000`.
- Read-only state: `XNGUSD.DWX`; no magic and no order path.
- Signal: strict WTI/XNG sign disagreement outside `1e-12`; WTI sign selects
  BUY/SELL. Ties and agreeing signs consume the month flat.
- Entry grace: 180 minutes from the first current-month D1 bar.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Stop: frozen `3.5 * ATR(20,D1)`; no target.
- Exit: first later-month bar or forty elapsed calendar days; malformed owned
  exposure is repaired immediately.
- Spread ceiling: 1,500 points. News, Friday close, and stress are off.

## Framework alignment

- No-trade: exact identity/risk/news/Friday/stress/parameter guards.
- Entry: persisted month, synchronized month ends, two annual signs, one WTI
  order with a fixed-risk frozen stop.
- Management: wrong-state repair, next-month liquidation, stale exit.
- Close: framework close helper, broker stop, and kill switch.

## Safety and acceptance

This build authorizes non-live Q01 and one paced Q02 handoff only. No manual
backtest, optimization, live preset, portfolio admission, gate change,
deployment, `T_Live`, or AutoTrading operation is authorized. Q02 retires the
candidate below five completed positions in any full post-warm-up year or on
nonpositive governed economics; Q09 alone may establish useful correlation.
