# QM5_20058 XCU Three-Month Time-Series Momentum

Single-symbol D1 copper trend sleeve built from the approved
`MOP-TSMOM-2012_XCU_S05` card. It rebalances monthly from the sign of the prior
63 completed D1 bars, uses a frozen 3.5 ATR hard stop, and runs Q02 with
`RISK_FIXED=1000` and `RISK_PERCENT=0`.

The strategy card is canonical at `docs/strategy_card.md`. Q02 must falsify the
CFD/futures translation, frequency, execution costs, and realized correlation.
