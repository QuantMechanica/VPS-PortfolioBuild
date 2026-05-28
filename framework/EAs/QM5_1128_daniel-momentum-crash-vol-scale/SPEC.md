# QM5_1128 Daniel-Moskowitz Momentum-Crash Volatility-Scaled

## Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1128_daniel-momentum-crash-vol-scale.md`
- Status: APPROVED
- Framework: QuantMechanica V5

## Mechanics

- Timeframe: D1
- Rebalance: first trading day of each month, detected from the closed D1 bar crossing into a new month.
- Signal: 12-month time-series momentum, `Close[1] / Close[253] - 1`.
- Direction: long if return is above `strategy_min_abs_return`, short if below `-strategy_min_abs_return`, otherwise flat.
- Volatility estimate: 63 closed D1 log returns, annualized by `sqrt(252)`.
- Vol scale: `k = min(1.0, strategy_target_vol_annual / sigma_est)`, scale-down only.
- Risk implementation: before entry, the EA reconfigures V5 risk sizing to `RISK_FIXED * k` or `RISK_PERCENT * k`; the framework still owns lot sizing and order submission.
- Stop: ATR(D1,14) * 3 hard stop by default.
- Exit: monthly rebalance closes flat/opposite signals. Optional P3 intra-month vol-shock exit is present but disabled by default.

## Universe

| Slot | Symbol |
|---:|---|
| 0 | NDX.DWX |
| 1 | GDAXI.DWX |
| 2 | WS30.DWX |
| 3 | UK100.DWX |
| 4 | EURUSD.DWX |
| 5 | XAUUSD.DWX |

## Framework Alignment

- No-Trade: D1-only, registered-symbol-only, tradable-symbol, optional spread cap.
- Entry: monthly 12M TSMOM direction plus realized-vol risk scalar.
- Management: no trailing, break-even, partial close, or pyramiding beyond V5 hard stop.
- Close: monthly rebalance closes flat/opposite signals; optional disabled vol-shock close.
- Risk: V5 `QM_RiskSizerConfigure` and `QM_TM_OpenPosition`; no hand-rolled lot sizing.
- Magic: `QM_Magic(qm_ea_id, Strategy_SlotForCurrentSymbol())`.

## Build Boundary

No backtests or pipeline phases are part of this build.
